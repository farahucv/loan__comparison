-- =====================================================================
-- RUSHD — Security fixes for the CURRENT schema (before the financing journey)
-- Run once in Supabase → SQL Editor. Everything is in one transaction:
-- if any line fails, nothing is changed.
-- Checked against the app code: it only changes the columns allowed below.
-- =====================================================================
begin;

-- ---------------------------------------------------------------------
-- 1) PROFILES: users cannot change their own role / bank, and new lender
--    accounts must be verified by the platform admin before publishing offers.
--    Problem fixed: "Users can update own profile" let any borrower run
--    update profiles set role = 'lender'.
-- ---------------------------------------------------------------------
alter table public.profiles
  add column if not exists lender_verified boolean not null default false;

-- Keep your existing lender test accounts working.
update public.profiles set lender_verified = true where role = 'lender';

create or replace function public.guard_profile_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  -- auth.uid() is null in the SQL Editor / dashboard = admin. Allow.
  if auth.uid() is null then
    return new;
  end if;

  if new.id is distinct from old.id
     or new.role is distinct from old.role
     or new.bank_name is distinct from old.bank_name
     or new.lender_verified is distinct from old.lender_verified then
    raise exception 'Role, bank and verification status can only be changed by the platform administrator';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_guard_profile_update on public.profiles;
create trigger trg_guard_profile_update
  before update on public.profiles
  for each row execute function public.guard_profile_update();

-- ---------------------------------------------------------------------
-- 2) LOAN OFFERS: only VERIFIED lenders can publish, and the bank name
--    always comes from the lender's profile (a lender cannot post an
--    offer under another bank's name).
-- ---------------------------------------------------------------------
drop policy if exists "Lenders can create own offers" on public.loan_offers;
create policy "Lenders can create own offers"
  on public.loan_offers for insert to authenticated
  with check (
    lender_id = auth.uid()
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'lender' and p.lender_verified
    )
  );

create or replace function public.guard_loan_offer()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_bank text;
begin
  if auth.uid() is null then
    return new;
  end if;

  if tg_op = 'UPDATE' and new.lender_id is distinct from old.lender_id then
    raise exception 'An offer cannot be moved to another lender';
  end if;

  select p.bank_name into v_bank from public.profiles p where p.id = new.lender_id;
  if v_bank is not null then
    new.bank_name := v_bank;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_guard_loan_offer on public.loan_offers;
create trigger trg_guard_loan_offer
  before insert or update on public.loan_offers
  for each row execute function public.guard_loan_offer();

-- ---------------------------------------------------------------------
-- 3) LOAN REQUESTS
--  a) Problem fixed: the INSERT policy did not check status, so a borrower
--     could insert a request that was ALREADY 'approved' and skip the lender.
--  b) Problem fixed: the tautology  o.lender_id = o.lender_id.
--  c) Problem fixed: a lender could edit the amount, borrower, eligibility
--     score etc. Now only status / rejection_reason / updated_at, and only
--     pending -> approved | rejected.
-- ---------------------------------------------------------------------
drop policy if exists "Borrowers can submit requests" on public.loan_requests;
create policy "Borrowers can submit requests"
  on public.loan_requests for insert to authenticated
  with check (
    borrower_id = auth.uid()
    and status = 'pending'
    and rejection_reason is null
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'borrower'
    )
    and exists (
      select 1 from public.loan_offers o
      where o.id = loan_requests.offer_id
        and o.lender_id = loan_requests.lender_id
        and o.is_active = true
    )
  );

create or replace function public.guard_loan_request_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if auth.uid() is null then
    return new;
  end if;

  if auth.uid() is distinct from old.lender_id then
    raise exception 'Only the assigned lender can update this request';
  end if;

  if (new.id, new.borrower_id, new.offer_id, new.lender_id, new.loan_type,
      new.requested_amount, new.eligibility_score, new.monthly_installment,
      new.installment_ratio, new.dti_ratio, new.eligibility_classification,
      new.created_at)
     is distinct from
     (old.id, old.borrower_id, old.offer_id, old.lender_id, old.loan_type,
      old.requested_amount, old.eligibility_score, old.monthly_installment,
      old.installment_ratio, old.dti_ratio, old.eligibility_classification,
      old.created_at) then
    raise exception 'Only the decision and rejection reason can be changed';
  end if;

  if old.status <> 'pending' then
    raise exception 'This request has already been decided';
  end if;

  if new.status not in ('approved', 'rejected') then
    raise exception 'Invalid decision';
  end if;

  if new.status = 'approved' then
    new.rejection_reason := null;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_guard_loan_request_update on public.loan_requests;
create trigger trg_guard_loan_request_update
  before update on public.loan_requests
  for each row execute function public.guard_loan_request_update();

-- ---------------------------------------------------------------------
-- 4) LOAN APPLICATIONS
--  Problem fixed: the lender UPDATE policy allowed changing ANY column
--  (name, national ID, IBAN, documents) and any status at any time.
--  Problem fixed: a borrower re-submitting could change lender_id and send
--  their application (and document access) to a different lender.
-- ---------------------------------------------------------------------
drop policy if exists applications_borrower_insert on public.loan_applications;
create policy applications_borrower_insert
  on public.loan_applications for insert to authenticated
  with check (
    borrower_id = auth.uid()
    and status = 'submitted'
    and lender_message is null
    and exists (
      select 1 from public.loan_requests r
      where r.id = loan_applications.request_id
        and r.borrower_id = auth.uid()
        and r.lender_id = loan_applications.lender_id
        and r.status = 'approved'
    )
  );

create or replace function public.guard_loan_application_update()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    return new;
  end if;

  if (new.id, new.request_id, new.borrower_id, new.lender_id, new.created_at)
     is distinct from
     (old.id, old.request_id, old.borrower_id, old.lender_id, old.created_at) then
    raise exception 'Application ownership fields cannot be changed';
  end if;

  if v_uid = old.lender_id then
    if (new.full_name, new.national_id, new.city, new.address, new.employer,
        new.job_title, new.years_at_job, new.iban, new.notes, new.documents)
       is distinct from
       (old.full_name, old.national_id, old.city, old.address, old.employer,
        old.job_title, old.years_at_job, old.iban, old.notes, old.documents) then
      raise exception 'Lenders cannot edit the applicant''s details';
    end if;

    if old.status <> 'submitted' then
      raise exception 'This application has already been decided';
    end if;

    if new.status not in ('more_info_required', 'approved', 'rejected') then
      raise exception 'Invalid decision';
    end if;

  elsif v_uid = old.borrower_id then
    -- The RLS policy already limits the borrower to more_info_required -> submitted.
    -- The borrower may clear the lender's message, but not write one.
    if new.lender_message is not null
       and new.lender_message is distinct from old.lender_message then
      raise exception 'Only the lender can write the lender message';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_guard_loan_application_update on public.loan_applications;
create trigger trg_guard_loan_application_update
  before update on public.loan_applications
  for each row execute function public.guard_loan_application_update();

-- ---------------------------------------------------------------------
-- 5) DOCUMENT STORAGE
--  Problem fixed: a lender with ONE application from a borrower could read
--  ALL of that borrower's files (including files sent to other lenders).
--  Now the lender can read only files under  borrowerId/requestId/  of an
--  application assigned to them. Uploads must go into a request the
--  borrower owns. Files are limited to 5 MB at the bucket level.
-- ---------------------------------------------------------------------
drop policy if exists loan_documents_read on storage.objects;
create policy loan_documents_read
  on storage.objects for select to authenticated
  using (
    bucket_id = 'loan-documents'
    and (
      (storage.foldername(objects.name))[1] = auth.uid()::text
      or exists (
        select 1 from public.loan_applications la
        where la.lender_id = auth.uid()
          and la.borrower_id::text = (storage.foldername(objects.name))[1]
          and la.request_id::text  = (storage.foldername(objects.name))[2]
      )
    )
  );

drop policy if exists loan_documents_borrower_upload on storage.objects;
create policy loan_documents_borrower_upload
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'loan-documents'
    and (storage.foldername(objects.name))[1] = auth.uid()::text
    and exists (
      select 1 from public.loan_requests r
      where r.id::text = (storage.foldername(objects.name))[2]
        and r.borrower_id = auth.uid()
    )
  );

update storage.buckets
set file_size_limit = 5242880   -- 5 MB, same as the app
where id = 'loan-documents';

-- File-type limit: turn on ONLY after Claude Code makes the app send a
-- contentType on upload (otherwise uploads may be rejected):
-- update storage.buckets
-- set allowed_mime_types = array['application/pdf','image/jpeg','image/png']
-- where id = 'loan-documents';

-- ---------------------------------------------------------------------
-- 6) Old unused function (credit-score version, not called by the app).
-- ---------------------------------------------------------------------
drop function if exists public.calculate_eligibility_score(numeric, numeric, numeric, numeric);

commit;
