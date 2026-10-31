-- =====================================================================
-- RUSHD — Extra fields for the redesigned loan application (4-step form)
--
-- Adds date_of_birth, employment_sector and consents to loan_applications,
-- and adds them to the lender guard so a lender still cannot edit any of
-- the applicant's details (same rules as 20261031000000_security_fixes).
--
-- Run once in Supabase -> SQL Editor. One transaction: all or nothing.
-- The app's new application form needs this migration.
-- =====================================================================
begin;

alter table public.loan_applications
  add column if not exists date_of_birth date,
  add column if not exists employment_sector text,
  -- credit_bureau_check, info_accurate, simulation_ack (all true),
  -- identity_verified_simulated, accepted_at
  add column if not exists consents jsonb not null default '{}'::jsonb;

alter table public.loan_applications
  drop constraint if exists loan_applications_employment_sector_check;

alter table public.loan_applications
  add constraint loan_applications_employment_sector_check
  check (
    employment_sector is null
    or employment_sector in ('government', 'private', 'military', 'retired')
  );

-- Same function as in 20261031000000_security_fixes.sql, with the three
-- new columns added to the list the lender may not change.
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
        new.job_title, new.years_at_job, new.iban, new.notes, new.documents,
        new.date_of_birth, new.employment_sector, new.consents)
       is distinct from
       (old.full_name, old.national_id, old.city, old.address, old.employer,
        old.job_title, old.years_at_job, old.iban, old.notes, old.documents,
        old.date_of_birth, old.employment_sector, old.consents) then
      raise exception 'Lenders cannot edit the applicant''s details';
    end if;

    if old.status <> 'submitted' then
      raise exception 'This application has already been decided';
    end if;

    if new.status not in ('more_info_required', 'approved', 'rejected') then
      raise exception 'Invalid decision';
    end if;

  elsif v_uid = old.borrower_id then
    if new.lender_message is not null
       and new.lender_message is distinct from old.lender_message then
      raise exception 'Only the lender can write the lender message';
    end if;
  end if;

  return new;
end;
$$;

commit;


-- =====================================================================
-- ROLLBACK (commented out)
-- =====================================================================
-- begin;
-- alter table public.loan_applications
--   drop constraint if exists loan_applications_employment_sector_check,
--   drop column if exists date_of_birth,
--   drop column if exists employment_sector,
--   drop column if exists consents;
-- -- then re-run section 4 of 20261031000000_security_fixes.sql to restore
-- -- the previous guard_loan_application_update().
-- commit;
