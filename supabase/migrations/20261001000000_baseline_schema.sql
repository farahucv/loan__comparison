-- =====================================================================
-- RUSHD — Baseline snapshot of the live database before 2026-10-31
--
-- Recreated from supabase/docs/schema_export_2026-10-31.csv (an export of
-- the live schema taken BEFORE 20261031000000_security_fixes). It records
-- the state the live database was in, so the migration history is complete.
--
-- The live database already has all of this. Do NOT run it there; mark it
-- as applied instead:  supabase migration repair --status applied 20261001000000
--
-- Written to be safe to re-run (if not exists / or replace / drop if exists).
-- Skipped on purpose: public.calculate_eligibility_score (old, unused, and
-- dropped by the security fixes).
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1) TABLES
-- ---------------------------------------------------------------------

create table if not exists public.profiles (
  id uuid not null,
  role text not null,
  full_name text not null,
  phone text,
  bank_name text,
  created_at timestamp with time zone not null default now(),

  constraint profiles_pkey primary key (id),
  constraint profiles_id_fkey foreign key (id)
    references auth.users(id) on delete cascade,
  constraint profiles_role_check
    check ((role = any (array['borrower'::text, 'lender'::text])))
);

create table if not exists public.borrower_profiles (
  user_id uuid not null,
  preferred_loan_type text not null default 'Personal Loan'::text,
  monthly_income numeric not null default 0,
  existing_debts numeric not null default 0,
  monthly_expenses numeric not null default 0,
  desired_amount numeric not null default 0,
  updated_at timestamp with time zone not null default now(),

  constraint borrower_profiles_pkey primary key (user_id),
  constraint borrower_profiles_user_id_fkey foreign key (user_id)
    references public.profiles(id) on delete cascade
);

create table if not exists public.loan_offers (
  id uuid not null default gen_random_uuid(),
  lender_id uuid not null,
  bank_name text not null,
  offer_name text not null,
  loan_type text not null,
  interest_rate numeric not null,
  max_term_months integer not null,
  max_amount numeric not null,
  contact_email text not null,
  is_active boolean not null default true,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),

  constraint loan_offers_pkey primary key (id),
  constraint loan_offers_lender_id_fkey foreign key (lender_id)
    references public.profiles(id) on delete cascade,
  constraint loan_offers_interest_rate_check
    check ((interest_rate >= (0)::numeric)),
  constraint loan_offers_loan_type_check
    check ((loan_type = any (array['Personal Loan'::text, 'Business Loan'::text, 'Investment Loan'::text]))),
  constraint loan_offers_max_amount_check
    check ((max_amount > (0)::numeric)),
  constraint loan_offers_max_term_months_check
    check ((max_term_months > 0))
);

create table if not exists public.loan_requests (
  id uuid not null default gen_random_uuid(),
  borrower_id uuid not null,
  offer_id uuid not null,
  lender_id uuid not null,
  loan_type text not null,
  requested_amount numeric not null,
  eligibility_score numeric,
  status text not null default 'pending'::text,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  rejection_reason text,
  monthly_installment numeric,
  installment_ratio numeric,
  dti_ratio numeric,
  eligibility_classification text,

  constraint loan_requests_pkey primary key (id),
  constraint loan_requests_borrower_id_fkey foreign key (borrower_id)
    references public.profiles(id) on delete cascade,
  constraint loan_requests_lender_id_fkey foreign key (lender_id)
    references public.profiles(id),
  constraint loan_requests_offer_id_fkey foreign key (offer_id)
    references public.loan_offers(id),
  constraint loan_requests_status_check
    check ((status = any (array['pending'::text, 'approved'::text, 'rejected'::text]))),
  constraint loan_requests_eligibility_score_check
    check (((eligibility_score >= (0)::numeric) and (eligibility_score <= (100)::numeric))),
  constraint loan_requests_monthly_installment_check
    check (((monthly_installment is null) or (monthly_installment >= (0)::numeric))),
  constraint loan_requests_installment_ratio_check
    check (((installment_ratio is null) or (installment_ratio >= (0)::numeric))),
  constraint loan_requests_dti_ratio_check
    check (((dti_ratio is null) or (dti_ratio >= (0)::numeric))),
  constraint loan_requests_eligibility_classification_check
    check (((eligibility_classification is null) or (eligibility_classification = any (array['Highly Suitable'::text, 'Suitable'::text, 'Moderately Suitable'::text, 'Not Suitable'::text]))))
);

create table if not exists public.loan_applications (
  id uuid not null default gen_random_uuid(),
  request_id uuid not null,
  borrower_id uuid not null,
  lender_id uuid not null,
  full_name text not null,
  national_id text not null,
  city text not null,
  address text,
  employer text not null,
  job_title text,
  years_at_job numeric,
  iban text,
  notes text,
  documents jsonb not null default '[]'::jsonb,
  status text not null default 'submitted'::text,
  lender_message text,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),

  constraint loan_applications_pkey primary key (id),
  constraint loan_applications_request_id_key unique (request_id),
  constraint loan_applications_request_id_fkey foreign key (request_id)
    references public.loan_requests(id) on delete cascade,
  constraint loan_applications_borrower_id_fkey foreign key (borrower_id)
    references auth.users(id) on delete cascade,
  constraint loan_applications_lender_id_fkey foreign key (lender_id)
    references auth.users(id) on delete cascade,
  constraint loan_applications_status_check
    check ((status = any (array['submitted'::text, 'more_info_required'::text, 'approved'::text, 'rejected'::text])))
);


-- ---------------------------------------------------------------------
-- 2) FUNCTIONS
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.calculate_rushd_eligibility(p_monthly_income numeric, p_current_monthly_obligations numeric, p_loan_amount numeric, p_annual_interest_rate numeric, p_term_months integer)
 RETURNS TABLE(monthly_installment numeric, installment_ratio numeric, dti_ratio numeric, eligibility_score numeric, eligibility_classification text)
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_monthly_rate numeric;
  v_installment numeric;

  v_dti_score numeric;
  v_interest_score numeric;
  v_term_score numeric;
  v_installment_score numeric;

  v_final_score numeric;
  v_installment_ratio numeric;
  v_dti numeric;
  v_classification text;
begin
  if p_monthly_income <= 0 then
    raise exception 'Monthly income must be greater than zero';
  end if;

  if p_current_monthly_obligations < 0 then
    raise exception 'Monthly obligations cannot be negative';
  end if;

  if p_loan_amount <= 0 then
    raise exception 'Loan amount must be greater than zero';
  end if;

  if p_annual_interest_rate < 0 then
    raise exception 'Interest rate cannot be negative';
  end if;

  if p_term_months <= 0 then
    raise exception 'Loan term must be greater than zero';
  end if;

  v_monthly_rate :=
    p_annual_interest_rate / 100 / 12;

  if v_monthly_rate = 0 then
    v_installment :=
      p_loan_amount / p_term_months;
  else
    v_installment :=
      (
        p_loan_amount
        * v_monthly_rate
        * power(1 + v_monthly_rate, p_term_months)
      )
      /
      (
        power(1 + v_monthly_rate, p_term_months) - 1
      );
  end if;

  v_installment_ratio :=
    (v_installment / p_monthly_income) * 100;

  v_dti :=
    (
      (
        p_current_monthly_obligations
        + v_installment
      )
      / p_monthly_income
    ) * 100;

  if v_dti < 30 then
    v_dti_score := 100;
  elsif v_dti <= 50 then
    v_dti_score := 70;
  else
    v_dti_score := 40;
  end if;

  if p_annual_interest_rate < 4 then
    v_interest_score := 100;
  elsif p_annual_interest_rate <= 7 then
    v_interest_score := 70;
  else
    v_interest_score := 40;
  end if;

  if p_term_months < 60 then
    v_term_score := 100;
  elsif p_term_months <= 120 then
    v_term_score := 70;
  else
    v_term_score := 40;
  end if;

  if v_installment_ratio < 20 then
    v_installment_score := 100;
  elsif v_installment_ratio <= 35 then
    v_installment_score := 70;
  else
    v_installment_score := 40;
  end if;

  v_final_score :=
      (v_dti_score * 0.45)
    + (v_interest_score * 0.25)
    + (v_term_score * 0.15)
    + (v_installment_score * 0.15);

  if v_final_score >= 80 then
    v_classification := 'Highly Suitable';
  elsif v_final_score >= 60 then
    v_classification := 'Suitable';
  elsif v_final_score >= 40 then
    v_classification := 'Moderately Suitable';
  else
    v_classification := 'Not Suitable';
  end if;

  return query
  select
    round(v_installment, 2),
    round(v_installment_ratio, 2),
    round(v_dti, 2),
    round(v_final_score, 2),
    v_classification;
end;
$function$;

CREATE OR REPLACE FUNCTION public.set_loan_request_eligibility()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_monthly_income numeric;
  v_monthly_obligations numeric;

  v_interest_rate numeric;
  v_term_months integer;

  v_offer_lender_id uuid;
  v_offer_loan_type text;
  v_offer_max_amount numeric;
  v_offer_is_active boolean;

  v_monthly_installment numeric;
  v_installment_ratio numeric;
  v_dti_ratio numeric;
  v_eligibility_score numeric;
  v_classification text;
begin
  select
    bp.monthly_income,
    bp.existing_debts
  into
    v_monthly_income,
    v_monthly_obligations
  from public.borrower_profiles bp
  where bp.user_id = new.borrower_id;

  if v_monthly_income is null then
    raise exception 'Borrower financial profile was not found';
  end if;

  select
    lo.interest_rate,
    lo.max_term_months,
    lo.lender_id,
    lo.loan_type,
    lo.max_amount,
    lo.is_active
  into
    v_interest_rate,
    v_term_months,
    v_offer_lender_id,
    v_offer_loan_type,
    v_offer_max_amount,
    v_offer_is_active
  from public.loan_offers lo
  where lo.id = new.offer_id;

  if v_interest_rate is null then
    raise exception 'Loan offer was not found';
  end if;

  if v_offer_is_active is not true then
    raise exception 'Loan offer is not active';
  end if;

  if new.lender_id <> v_offer_lender_id then
    raise exception 'Lender does not match the selected offer';
  end if;

  if new.loan_type <> v_offer_loan_type then
    raise exception 'Loan type does not match the selected offer';
  end if;

  if new.requested_amount > v_offer_max_amount then
    raise exception 'Requested amount exceeds the offer maximum amount';
  end if;

  select
    c.monthly_installment,
    c.installment_ratio,
    c.dti_ratio,
    c.eligibility_score,
    c.eligibility_classification
  into
    v_monthly_installment,
    v_installment_ratio,
    v_dti_ratio,
    v_eligibility_score,
    v_classification
  from public.calculate_rushd_eligibility(
    v_monthly_income,
    v_monthly_obligations,
    new.requested_amount,
    v_interest_rate,
    v_term_months
  ) c;

  new.monthly_installment :=
    v_monthly_installment;

  new.installment_ratio :=
    v_installment_ratio;

  new.dti_ratio :=
    v_dti_ratio;

  new.eligibility_score :=
    v_eligibility_score;

  new.eligibility_classification :=
    v_classification;

  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_bank_contact(p_request_id uuid)
 RETURNS TABLE(bank_name text, lender_name text, lender_phone text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select lo.bank_name, p.full_name, p.phone
  from public.loan_requests r
  join public.loan_offers lo on lo.id = r.offer_id
  left join public.profiles p on p.id = r.lender_id
  where r.id = p_request_id
    and r.borrower_id = auth.uid();
$function$;

CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin

  insert into public.profiles (
    id,
    role,
    full_name,
    phone,
    bank_name
  )
  values (
    new.id,

    case
      when new.raw_user_meta_data ->> 'role'
        in ('borrower', 'lender')
      then new.raw_user_meta_data ->> 'role'
      else 'borrower'
    end,

    coalesce(
      new.raw_user_meta_data ->> 'full_name',
      ''
    ),

    new.raw_user_meta_data ->> 'phone',

    nullif(
      new.raw_user_meta_data ->> 'bank_name',
      ''
    )
  );


  if
    coalesce(
      new.raw_user_meta_data ->> 'role',
      'borrower'
    ) = 'borrower'
  then

    insert into public.borrower_profiles (
      user_id
    )
    values (
      new.id
    );

  end if;


  return new;

end;
$function$;


-- ---------------------------------------------------------------------
-- 3) TRIGGERS
-- ---------------------------------------------------------------------

drop trigger if exists trg_set_loan_request_eligibility on public.loan_requests;
create trigger trg_set_loan_request_eligibility
  before insert on public.loan_requests
  for each row execute function public.set_loan_request_eligibility();

-- Sign-up trigger on auth.users. NOT in the CSV export (the export only
-- listed public-schema triggers), but sign-up needs it to create profiles.
-- The name is the Supabase default and is assumed. Check the live name with:
--   select tgname from pg_trigger
--   where tgrelid = 'auth.users'::regclass and not tgisinternal;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();


-- ---------------------------------------------------------------------
-- 4) ROW LEVEL SECURITY
-- ---------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.borrower_profiles enable row level security;
alter table public.loan_offers enable row level security;
alter table public.loan_requests enable row level security;
alter table public.loan_applications enable row level security;

-- profiles
drop policy if exists "Users can view own profile" on public.profiles;
create policy "Users can view own profile"
  on public.profiles for select to authenticated
  using ((id = auth.uid()));

drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile"
  on public.profiles for update to authenticated
  using ((id = auth.uid()))
  with check ((id = auth.uid()));

drop policy if exists "Lender can view borrower profile for received requests" on public.profiles;
create policy "Lender can view borrower profile for received requests"
  on public.profiles for select to authenticated
  using (((id = auth.uid()) or (exists ( select 1
     from public.loan_requests
    where ((loan_requests.borrower_id = profiles.id) and (loan_requests.lender_id = auth.uid()))))));

-- borrower_profiles
drop policy if exists "Borrowers can view own financial profile" on public.borrower_profiles;
create policy "Borrowers can view own financial profile"
  on public.borrower_profiles for select to authenticated
  using ((user_id = auth.uid()));

drop policy if exists "Borrowers can insert own financial profile" on public.borrower_profiles;
create policy "Borrowers can insert own financial profile"
  on public.borrower_profiles for insert to authenticated
  with check ((user_id = auth.uid()));

drop policy if exists "Borrowers can update own financial profile" on public.borrower_profiles;
create policy "Borrowers can update own financial profile"
  on public.borrower_profiles for update to authenticated
  using ((user_id = auth.uid()))
  with check ((user_id = auth.uid()));

drop policy if exists "Lender can view borrower financial data for received requests" on public.borrower_profiles;
create policy "Lender can view borrower financial data for received requests"
  on public.borrower_profiles for select to authenticated
  using (((user_id = auth.uid()) or (exists ( select 1
     from public.loan_requests
    where ((loan_requests.borrower_id = borrower_profiles.user_id) and (loan_requests.lender_id = auth.uid()))))));

-- loan_offers
drop policy if exists "Authenticated users can view offers" on public.loan_offers;
create policy "Authenticated users can view offers"
  on public.loan_offers for select to authenticated
  using (true);

drop policy if exists "Lenders can create own offers" on public.loan_offers;
create policy "Lenders can create own offers"
  on public.loan_offers for insert to authenticated
  with check (((lender_id = auth.uid()) and (exists ( select 1
     from public.profiles p
    where ((p.id = auth.uid()) and (p.role = 'lender'::text))))));

drop policy if exists "Lenders can update own offers" on public.loan_offers;
create policy "Lenders can update own offers"
  on public.loan_offers for update to authenticated
  using ((lender_id = auth.uid()))
  with check ((lender_id = auth.uid()));

drop policy if exists "Lenders can delete own offers" on public.loan_offers;
create policy "Lenders can delete own offers"
  on public.loan_offers for delete to authenticated
  using ((lender_id = auth.uid()));

-- loan_requests
drop policy if exists "Borrowers and lenders can view related requests" on public.loan_requests;
create policy "Borrowers and lenders can view related requests"
  on public.loan_requests for select to authenticated
  using (((borrower_id = auth.uid()) or (lender_id = auth.uid())));

-- Recorded as it was live, including the o.lender_id = o.lender_id
-- tautology (fixed in 20261031000000_security_fixes).
drop policy if exists "Borrowers can submit requests" on public.loan_requests;
create policy "Borrowers can submit requests"
  on public.loan_requests for insert to authenticated
  with check (((borrower_id = auth.uid()) and (exists ( select 1
     from public.profiles p
    where ((p.id = auth.uid()) and (p.role = 'borrower'::text)))) and (exists ( select 1
     from public.loan_offers o
    where ((o.id = loan_requests.offer_id) and (o.lender_id = o.lender_id) and (o.is_active = true))))));

drop policy if exists "Lenders can update received requests" on public.loan_requests;
create policy "Lenders can update received requests"
  on public.loan_requests for update to authenticated
  using ((lender_id = auth.uid()))
  with check ((lender_id = auth.uid()));

-- loan_applications
drop policy if exists applications_select on public.loan_applications;
create policy applications_select
  on public.loan_applications for select to authenticated
  using (((borrower_id = auth.uid()) or (lender_id = auth.uid())));

drop policy if exists applications_borrower_insert on public.loan_applications;
create policy applications_borrower_insert
  on public.loan_applications for insert to authenticated
  with check (((borrower_id = auth.uid()) and (status = 'submitted'::text) and (exists ( select 1
     from public.loan_requests r
    where ((r.id = loan_applications.request_id) and (r.borrower_id = auth.uid()) and (r.lender_id = loan_applications.lender_id) and (r.status = 'approved'::text))))));

drop policy if exists applications_borrower_update on public.loan_applications;
create policy applications_borrower_update
  on public.loan_applications for update to authenticated
  using (((borrower_id = auth.uid()) and (status = 'more_info_required'::text)))
  with check (((borrower_id = auth.uid()) and (status = 'submitted'::text)));

drop policy if exists applications_lender_update on public.loan_applications;
create policy applications_lender_update
  on public.loan_applications for update to authenticated
  using ((lender_id = auth.uid()))
  with check ((lender_id = auth.uid()));


-- ---------------------------------------------------------------------
-- 5) STORAGE: bucket + policies
-- ---------------------------------------------------------------------

insert into storage.buckets (id, name, public)
values ('loan-documents', 'loan-documents', false)
on conflict (id) do nothing;

drop policy if exists loan_documents_borrower_upload on storage.objects;
create policy loan_documents_borrower_upload
  on storage.objects for insert to authenticated
  with check (((bucket_id = 'loan-documents'::text) and ((storage.foldername(name))[1] = (auth.uid())::text)));

drop policy if exists loan_documents_read on storage.objects;
create policy loan_documents_read
  on storage.objects for select to authenticated
  using (((bucket_id = 'loan-documents'::text) and (((storage.foldername(name))[1] = (auth.uid())::text) or (exists ( select 1
     from public.loan_applications la
    where ((la.lender_id = auth.uid()) and ((la.borrower_id)::text = (storage.foldername(objects.name))[1])))))));
