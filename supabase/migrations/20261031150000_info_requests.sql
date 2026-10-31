-- =====================================================================
-- RUSHD — Structured "request more information"
--
-- The lender asks for specific items (documents to upload, fields to
-- correct, other), the borrower answers with a response, and each
-- resubmission starts a new review round.
--
--   info_requests    jsonb  list of {id, type, category | field, note}
--                           type: document | field | other
--   borrower_response text  the borrower's reply to the bank
--   review_round     int    1 for the first submission, +1 per resubmission
--
-- Requires 20261031140000_application_fields.sql.
-- Run once in Supabase -> SQL Editor. One transaction: all or nothing.
-- =====================================================================
begin;

-- ---------------------------------------------------------------------
-- 1) Columns
-- ---------------------------------------------------------------------
alter table public.loan_applications
  add column if not exists info_requests jsonb not null default '[]'::jsonb,
  add column if not exists borrower_response text,
  add column if not exists review_round integer not null default 1;

alter table public.loan_applications
  drop constraint if exists loan_applications_info_requests_check,
  drop constraint if exists loan_applications_review_round_check;

alter table public.loan_applications
  add constraint loan_applications_info_requests_check
    check (jsonb_typeof(info_requests) = 'array'),
  add constraint loan_applications_review_round_check
    check (review_round >= 1);

-- ---------------------------------------------------------------------
-- 2) Guard trigger
--    Every rule from 20261031140000_application_fields.sql is kept
--    exactly; the new rules are marked NEW.
-- ---------------------------------------------------------------------
create or replace function public.guard_loan_application_update()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_item jsonb;
begin
  if v_uid is null then
    return new;
  end if;

  if (new.id, new.request_id, new.borrower_id, new.lender_id, new.created_at)
     is distinct from
     (old.id, old.request_id, old.borrower_id, old.lender_id, old.created_at) then
    raise exception 'Application ownership fields cannot be changed';
  end if;

  -- NEW: nobody sets the review round by hand; it is set below.
  if new.review_round is distinct from old.review_round then
    raise exception 'The review round is set automatically';
  end if;

  if v_uid = old.lender_id then
    -- NEW: borrower_response and review_round added to the list.
    if (new.full_name, new.national_id, new.city, new.address, new.employer,
        new.job_title, new.years_at_job, new.iban, new.notes, new.documents,
        new.date_of_birth, new.employment_sector, new.consents,
        new.borrower_response)
       is distinct from
       (old.full_name, old.national_id, old.city, old.address, old.employer,
        old.job_title, old.years_at_job, old.iban, old.notes, old.documents,
        old.date_of_birth, old.employment_sector, old.consents,
        old.borrower_response) then
      raise exception 'Lenders cannot edit the applicant''s details';
    end if;

    if old.status <> 'submitted' then
      raise exception 'This application has already been decided';
    end if;

    if new.status not in ('more_info_required', 'approved', 'rejected') then
      raise exception 'Invalid decision';
    end if;

    -- NEW: info_requests may only be set together with
    -- more_info_required, and must then list at least one valid item.
    if new.status = 'more_info_required' then
      if jsonb_typeof(new.info_requests) <> 'array'
         or jsonb_array_length(new.info_requests) = 0 then
        raise exception 'Request at least one item from the borrower';
      end if;

      for v_item in select * from jsonb_array_elements(new.info_requests) loop
        if jsonb_typeof(v_item) <> 'object'
           or coalesce(v_item ->> 'id', '') = ''
           or coalesce(v_item ->> 'type', '') not in ('document', 'field', 'other')
           or (v_item ->> 'type' = 'document' and coalesce(v_item ->> 'category', '') = '')
           or (v_item ->> 'type' = 'field' and coalesce(v_item ->> 'field', '') = '') then
          raise exception 'Information requests must be a list of document, field or other items';
        end if;
      end loop;
    elsif new.info_requests is distinct from old.info_requests then
      raise exception 'Information requests can only be sent with a request for more information';
    end if;

  elsif v_uid = old.borrower_id then
    -- The RLS policy already limits the borrower to more_info_required -> submitted.
    -- The borrower may clear the lender's message, but not write one.
    if new.lender_message is not null
       and new.lender_message is distinct from old.lender_message then
      raise exception 'Only the lender can write the lender message';
    end if;

    -- NEW: the borrower cannot change what the bank asked for.
    if new.info_requests is distinct from old.info_requests then
      raise exception 'The borrower cannot change the information requests';
    end if;

    -- NEW: each resubmission starts a new review round.
    if old.status = 'more_info_required' and new.status = 'submitted' then
      new.review_round := old.review_round + 1;
    end if;
  end if;

  return new;
end;
$$;

-- ---------------------------------------------------------------------
-- 3) Borrower insert policy: same as 20261031000000_security_fixes.sql,
--    plus a new application must start clean (no requests, round 1).
-- ---------------------------------------------------------------------
drop policy if exists applications_borrower_insert on public.loan_applications;
create policy applications_borrower_insert
  on public.loan_applications for insert to authenticated
  with check (
    borrower_id = auth.uid()
    and status = 'submitted'
    and lender_message is null
    and info_requests = '[]'::jsonb
    and review_round = 1
    and exists (
      select 1 from public.loan_requests r
      where r.id = loan_applications.request_id
        and r.borrower_id = auth.uid()
        and r.lender_id = loan_applications.lender_id
        and r.status = 'approved'
    )
  );

commit;


-- =====================================================================
-- ROLLBACK (commented out)
-- =====================================================================
-- begin;
--
-- -- Restore the insert policy from 20261031000000_security_fixes.sql
-- drop policy if exists applications_borrower_insert on public.loan_applications;
-- create policy applications_borrower_insert
--   on public.loan_applications for insert to authenticated
--   with check (
--     borrower_id = auth.uid()
--     and status = 'submitted'
--     and lender_message is null
--     and exists (
--       select 1 from public.loan_requests r
--       where r.id = loan_applications.request_id
--         and r.borrower_id = auth.uid()
--         and r.lender_id = loan_applications.lender_id
--         and r.status = 'approved'
--     )
--   );
--
-- -- Then re-run the guard_loan_application_update() function from
-- -- 20261031140000_application_fields.sql (it does not mention the
-- -- new columns), and only after that drop them:
--
-- alter table public.loan_applications
--   drop constraint if exists loan_applications_info_requests_check,
--   drop constraint if exists loan_applications_review_round_check,
--   drop column if exists info_requests,
--   drop column if exists borrower_response,
--   drop column if exists review_round;
--
-- commit;
