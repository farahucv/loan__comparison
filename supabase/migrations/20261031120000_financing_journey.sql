-- =====================================================================
-- RUSHD — Financing journey (SIMULATION)
--
-- Rushd has no real bank partnerships. Everything after the application is
-- approved is a realistic DEMO that follows the spirit of SAMA's Responsible
-- Lending and Consumer Protection principles: a Key Facts Statement (KFS)
-- with APR, a Debt Burden Ratio check, explicit consents, simulated OTP
-- signing, a cooling-off period with the right to withdraw, and a full audit
-- trail. No money moves and no real contract is created.
--
-- Journey (starts when loan_applications.status = 'approved'):
--   offer:      offer_issued -> offer_accepted | offer_declined | offer_expired | cancelled
--   agreement:  offer_accepted -> cooling_off -> active
--                                       \-> withdrawn
--   ('contract_signed' and 'disbursed' are recorded as events and as the
--    signed_at / disbursed_at timestamps; the stored status moves straight
--    on to the next resting state in the same call.)
--
-- Every write goes through the rushd_* SECURITY DEFINER functions below.
-- Users can only SELECT their own rows; there is no direct INSERT/UPDATE/DELETE.
--
-- Requires 20261031000000_security_fixes.sql to have been run first
-- (checked in section 0).
-- Run once in Supabase -> SQL Editor. One transaction: all or nothing.
-- =====================================================================
begin;


-- =====================================================================
-- 0) EXISTING PROBLEMS — ALREADY FIXED, CHECKED HERE
--
-- These three were fixed in 20261031000000_security_fixes.sql (already
-- run on the live database). They are NOT re-created here, so there is
-- only one copy of each rule. These checks stop this migration if the
-- fixes are missing.
-- =====================================================================

-- 0a) loan_requests insert policy used  o.lender_id = o.lender_id
--     (always true). Fixed version joins o.lender_id = loan_requests.lender_id.
do $$
begin
  if exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'loan_requests'
      and with_check like '%o.lender_id = o.lender_id%'
  ) then
    raise exception 'loan_requests still has the o.lender_id = o.lender_id policy. Run 20261031000000_security_fixes.sql first.';
  end if;
end;
$$;

-- 0b) Lender updates on loan_applications may only change status,
--     lender_message and updated_at (trigger guard_loan_application_update).
do $$
begin
  if not exists (
    select 1 from pg_trigger
    where tgname = 'trg_guard_loan_application_update'
      and tgrelid = 'public.loan_applications'::regclass
  ) then
    raise exception 'Trigger trg_guard_loan_application_update is missing. Run 20261031000000_security_fixes.sql first.';
  end if;
end;
$$;

-- 0c) profiles.role cannot be changed by the user after sign-up
--     (trigger guard_profile_update; it also protects bank_name and
--     lender_verified).
do $$
begin
  if not exists (
    select 1 from pg_trigger
    where tgname = 'trg_guard_profile_update'
      and tgrelid = 'public.profiles'::regclass
  ) then
    raise exception 'Trigger trg_guard_profile_update is missing. Run 20261031000000_security_fixes.sql first.';
  end if;
end;
$$;


-- =====================================================================
-- 1) SETTINGS (one row). Change values with an UPDATE in the SQL editor.
-- =====================================================================

create table public.rushd_settings (
  id boolean primary key default true check (id),

  -- Admin fee cap: least(admin_fee_pct % of principal, admin_fee_max_sar).
  -- Used only through rushd_admin_fee_cap().
  admin_fee_pct numeric not null default 1,
  admin_fee_max_sar numeric not null default 5000,

  -- SAMA: consumer finance maximum 5 years.
  min_term_months integer not null default 6,
  max_term_months integer not null default 60,

  -- Debt Burden Ratio caps (percent of monthly income).
  -- The demo treats every borrower as salaried (the app does not store
  -- employment type) and existing_debts as monthly obligations.
  dbr_salary_deduction_cap_pct numeric not null default 33.33,
  dbr_total_cap_pct numeric not null default 45,
  dbr_income_limit_sar numeric not null default 25000,
  -- Cap for income above dbr_income_limit_sar. Not given in the brief:
  -- kept at 45 (conservative). Change it once you confirm the figure.
  dbr_total_cap_above_limit_pct numeric not null default 45,

  max_offer_valid_days integer not null default 30,

  -- Cooling-off: business days are Sunday–Thursday (Riyadh time).
  -- Public holidays are not taken into account.
  cooling_off_business_days integer not null default 10,

  -- DEMO: shorten cooling-off to a few minutes for presentations.
  demo_fast_cooling_off boolean not null default false,
  demo_fast_cooling_off_minutes integer not null default 2,

  -- DEMO: simulated OTP. The same code is returned by
  -- rushd_request_signing_code() (no SMS is sent).
  demo_signing_code text not null default '123456',
  signing_code_minutes integer not null default 5,
  signing_max_attempts integer not null default 3,

  updated_at timestamptz not null default now()
);

comment on table public.rushd_settings is
  'SIMULATION settings for the Rushd financing journey (fee cap, DBR caps, cooling-off, demo OTP).';

insert into public.rushd_settings (id) values (true);


-- =====================================================================
-- 2) TABLES
-- =====================================================================

create table public.financing_offers (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null
    references public.loan_applications(id) on delete cascade,
  borrower_id uuid not null references public.profiles(id) on delete cascade,
  lender_id uuid not null references public.profiles(id) on delete cascade,

  -- Entered by the lender (validated in rushd_issue_offer)
  principal numeric(12,2) not null check (principal > 0),
  annual_profit_rate numeric(6,3) not null check (annual_profit_rate >= 0),
  rate_type text not null check (rate_type in ('flat', 'reducing')),
  term_months integer not null check (term_months > 0),
  admin_fee numeric(12,2) not null default 0 check (admin_fee >= 0),

  -- CALCULATED BY THE DATABASE (rushd_calc_financing)
  monthly_installment numeric(12,2) not null,
  total_profit numeric(12,2) not null,
  total_repayable numeric(12,2) not null,   -- all installments + admin fee
  apr numeric(7,2) not null,                -- percent per year
  salary_dbr numeric(6,2) not null,         -- new installment / income, %
  total_dbr numeric(6,2) not null,          -- (existing + new) / income, %

  valid_until timestamptz not null,
  version integer not null default 1,
  status text not null default 'offer_issued' check (
    status in ('offer_issued', 'offer_accepted', 'offer_declined',
               'offer_expired', 'cancelled')
  ),
  created_at timestamptz not null default now(),

  unique (application_id, version)
);

-- Only one live offer per application.
create unique index financing_offers_one_live_per_application
  on public.financing_offers (application_id)
  where status in ('offer_issued', 'offer_accepted');

create index financing_offers_borrower_idx on public.financing_offers (borrower_id);
create index financing_offers_lender_idx on public.financing_offers (lender_id);

comment on table public.financing_offers is
  'SIMULATION: financing offer / Key Facts Statement. Financial columns are calculated by the database.';


create sequence public.rushd_agreement_ref_seq;

create table public.financing_agreements (
  id uuid primary key default gen_random_uuid(),
  offer_id uuid not null unique
    references public.financing_offers(id) on delete cascade,
  borrower_id uuid not null references public.profiles(id) on delete cascade,
  lender_id uuid not null references public.profiles(id) on delete cascade,

  reference_no text not null unique,          -- e.g. RSHD-2026-000123
  kfs_accepted_at timestamptz not null,
  -- credit_bureau_consent, terms_read, simulation_ack, data_sharing (all true),
  -- early_disbursement_waiver (optional), accepted_at
  consents jsonb not null default '{}'::jsonb,

  signed_at timestamptz,
  signature_method text check (signature_method is null or signature_method = 'simulated_otp'),
  cooling_off_ends_at timestamptz,
  withdrawn_at timestamptz,
  disbursed_at timestamptz,
  disbursement_iban_last4 text check (
    disbursement_iban_last4 is null or disbursement_iban_last4 ~ '^[0-9]{4}$'
  ),

  status text not null default 'offer_accepted' check (
    status in ('offer_accepted', 'contract_signed', 'cooling_off',
               'disbursed', 'active', 'withdrawn', 'cancelled')
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index financing_agreements_borrower_idx on public.financing_agreements (borrower_id);
create index financing_agreements_lender_idx on public.financing_agreements (lender_id);

comment on table public.financing_agreements is
  'SIMULATION: financing agreement. Signing is a simulated OTP; no real contract or payment exists.';


create table public.repayment_schedule (
  agreement_id uuid not null
    references public.financing_agreements(id) on delete cascade,
  installment_no integer not null,
  due_date date not null,
  principal_part numeric(12,2) not null,
  profit_part numeric(12,2) not null,
  installment numeric(12,2) not null,
  remaining_balance numeric(12,2) not null,

  primary key (agreement_id, installment_no)
);

comment on table public.repayment_schedule is
  'SIMULATION: repayment schedule. Built at signing, rebuilt from the disbursement date.';


-- Append-only audit log. No foreign keys on purpose, so the history is kept
-- even if test users / applications are deleted later.
create table public.financing_events (
  id bigint generated always as identity primary key,
  offer_id uuid not null,
  agreement_id uuid,
  borrower_id uuid not null,
  lender_id uuid not null,
  actor_id uuid,
  actor_role text not null check (actor_role in ('borrower', 'lender', 'system')),
  event_type text not null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index financing_events_offer_idx on public.financing_events (offer_id);
create index financing_events_agreement_idx on public.financing_events (agreement_id);

comment on table public.financing_events is
  'SIMULATION audit log of the financing journey. Append-only: no UPDATE / DELETE / TRUNCATE for anyone.';

create or replace function public.rushd_events_append_only()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  raise exception 'financing_events is append-only: rows cannot be changed or deleted';
end;
$$;

create trigger trg_financing_events_no_change
  before update or delete on public.financing_events
  for each row execute function public.rushd_events_append_only();

create trigger trg_financing_events_no_truncate
  before truncate on public.financing_events
  for each statement execute function public.rushd_events_append_only();


-- Simulated OTP codes (hash only). Not readable by any user.
create table public.financing_signing_codes (
  agreement_id uuid primary key
    references public.financing_agreements(id) on delete cascade,
  code_hash text not null,
  expires_at timestamptz not null,
  attempts integer not null default 0,
  created_at timestamptz not null default now()
);


-- =====================================================================
-- 3) CALCULATIONS (pure math, no data access except the fee cap)
-- =====================================================================

-- Admin fee cap: the ONE place the rule lives.
create or replace function public.rushd_admin_fee_cap(p_principal numeric)
returns numeric
language sql
stable
set search_path = public, pg_temp
as $$
  select round(least(p_principal * s.admin_fee_pct / 100, s.admin_fee_max_sar), 2)
  from public.rushd_settings s;
$$;

-- Installment-by-installment schedule. The last installment absorbs the
-- rounding so the balance ends at exactly 0.
create or replace function public.rushd_schedule_rows(
  p_principal numeric,
  p_annual_profit_rate numeric,
  p_rate_type text,
  p_term_months integer,
  p_start_date date
)
returns table (
  installment_no integer,
  due_date date,
  principal_part numeric,
  profit_part numeric,
  installment numeric,
  remaining_balance numeric
)
language plpgsql
immutable
set search_path = public, pg_temp
as $$
declare
  v_monthly_rate numeric := p_annual_profit_rate / 1200;
  v_installment numeric;
  v_flat_profit numeric;
  v_flat_profit_part numeric;
  v_balance numeric := p_principal;
  v_profit_so_far numeric := 0;
begin
  if p_principal is null or p_principal <= 0 then
    raise exception 'The amount must be greater than zero';
  end if;

  if p_annual_profit_rate is null or p_annual_profit_rate < 0 then
    raise exception 'The profit rate cannot be negative';
  end if;

  if p_term_months is null or p_term_months <= 0 then
    raise exception 'The term must be greater than zero';
  end if;

  if p_rate_type = 'flat' then
    -- Flat: profit on the full amount for the whole term.
    v_flat_profit := round(p_principal * p_annual_profit_rate / 100 * p_term_months / 12, 2);
    v_installment := round((p_principal + v_flat_profit) / p_term_months, 2);
    v_flat_profit_part := round(v_flat_profit / p_term_months, 2);
  elsif p_rate_type = 'reducing' then
    -- Reducing balance: standard annuity.
    if v_monthly_rate = 0 then
      v_installment := round(p_principal / p_term_months, 2);
    else
      v_installment := round(
        p_principal * v_monthly_rate / (1 - power(1 + v_monthly_rate, -p_term_months)),
        2
      );
    end if;
  else
    raise exception 'Rate type must be flat or reducing';
  end if;

  for k in 1..p_term_months loop
    installment_no := k;
    due_date := (p_start_date + make_interval(months => k))::date;

    if p_rate_type = 'flat' then
      profit_part := case
        when k = p_term_months then v_flat_profit - v_profit_so_far
        else v_flat_profit_part
      end;
    else
      profit_part := round(v_balance * v_monthly_rate, 2);
    end if;

    principal_part := case
      when k = p_term_months then v_balance
      else v_installment - profit_part
    end;

    installment := principal_part + profit_part;
    v_balance := v_balance - principal_part;
    v_profit_so_far := v_profit_so_far + profit_part;
    remaining_balance := v_balance;

    return next;
  end loop;
end;
$$;

-- APR = monthly IRR of the cash flows x 12.
-- Borrower receives (principal - admin_fee) today and pays the installment
-- every month for the term. Solved by bisection.
create or replace function public.rushd_calc_apr(
  p_net_amount numeric,
  p_installment numeric,
  p_term_months integer
)
returns numeric
language plpgsql
immutable
set search_path = public, pg_temp
as $$
declare
  v_net float8 := p_net_amount;
  v_installment float8 := p_installment;
  v_low float8 := 0;
  v_high float8 := 1;        -- 100% per month
  v_mid float8 := 0;
  v_present_value float8;
begin
  if p_net_amount <= 0 or p_installment <= 0 or p_term_months <= 0 then
    raise exception 'The APR cannot be calculated for these values';
  end if;

  if v_installment * p_term_months <= v_net then
    return 0;
  end if;

  for k in 1..100 loop
    v_mid := (v_low + v_high) / 2;
    v_present_value := v_installment * (1 - power(1 + v_mid, -p_term_months)) / v_mid;

    if v_present_value > v_net then
      v_low := v_mid;
    else
      v_high := v_mid;
    end if;
  end loop;

  return round((v_mid * 12 * 100)::numeric, 2);
end;
$$;

-- Everything the offer / KFS shows, calculated in one place.
create or replace function public.rushd_calc_financing(
  p_principal numeric,
  p_annual_profit_rate numeric,
  p_rate_type text,
  p_term_months integer,
  p_admin_fee numeric
)
returns table (
  monthly_installment numeric,
  total_profit numeric,
  total_repayable numeric,
  apr numeric
)
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  v_sum_installments numeric;
begin
  if p_admin_fee is null or p_admin_fee < 0 then
    raise exception 'The admin fee cannot be negative';
  end if;

  if p_admin_fee >= p_principal then
    raise exception 'The admin fee must be less than the amount';
  end if;

  select s.installment
  into monthly_installment
  from public.rushd_schedule_rows(
    p_principal, p_annual_profit_rate, p_rate_type, p_term_months, current_date
  ) s
  where s.installment_no = 1;

  select sum(s.profit_part), sum(s.installment)
  into total_profit, v_sum_installments
  from public.rushd_schedule_rows(
    p_principal, p_annual_profit_rate, p_rate_type, p_term_months, current_date
  ) s;

  total_repayable := v_sum_installments + p_admin_fee;
  apr := public.rushd_calc_apr(p_principal - p_admin_fee, monthly_installment, p_term_months);

  return next;
end;
$$;

-- Add Saudi business days (Sunday–Thursday), Riyadh time.
create or replace function public.rushd_add_business_days(
  p_from timestamptz,
  p_days integer
)
returns timestamptz
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  v_local timestamp := p_from at time zone 'Asia/Riyadh';
  v_added integer := 0;
begin
  while v_added < p_days loop
    v_local := v_local + interval '1 day';

    -- isodow: 5 = Friday, 6 = Saturday
    if extract(isodow from v_local) not in (5, 6) then
      v_added := v_added + 1;
    end if;
  end loop;

  return v_local at time zone 'Asia/Riyadh';
end;
$$;


-- =====================================================================
-- 4) INTERNAL HELPERS (not callable by users)
-- =====================================================================

-- Checks the caller is signed in and has the role. Lenders must also be
-- verified by Rushd. Returns auth.uid().
create or replace function public.rushd_require_role(p_role text)
returns uuid
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_profile public.profiles%rowtype;
begin
  if v_uid is null then
    raise exception 'You must sign in first.';
  end if;

  select * into v_profile from public.profiles where id = v_uid;

  if not found or v_profile.role <> p_role then
    raise exception 'Only a % can do this.', p_role;
  end if;

  if p_role = 'lender' and v_profile.lender_verified is not true then
    raise exception 'Your lender account is pending verification by Rushd.';
  end if;

  return v_uid;
end;
$$;

create or replace function public.rushd_log_event(
  p_offer_id uuid,
  p_agreement_id uuid,
  p_borrower_id uuid,
  p_lender_id uuid,
  p_actor_role text,
  p_event_type text,
  p_details jsonb default '{}'::jsonb
)
returns void
language sql
security definer
set search_path = public, pg_temp
as $$
  insert into public.financing_events (
    offer_id, agreement_id, borrower_id, lender_id,
    actor_id, actor_role, event_type, details
  )
  values (
    p_offer_id, p_agreement_id, p_borrower_id, p_lender_id,
    auth.uid(), p_actor_role, p_event_type,
    coalesce(p_details, '{}'::jsonb) || '{"simulated": true}'::jsonb
  );
$$;

-- Marks issued offers whose valid_until has passed as expired.
-- (The app should also show an 'offer_issued' offer past valid_until as
-- expired; this keeps the stored status tidy when a new offer is issued.)
create or replace function public.rushd_expire_stale_offers(p_application_id uuid)
returns void
language sql
security definer
set search_path = public, pg_temp
as $$
  with expired as (
    update public.financing_offers
    set status = 'offer_expired'
    where application_id = p_application_id
      and status = 'offer_issued'
      and valid_until <= now()
    returning id, borrower_id, lender_id, version, valid_until
  )
  insert into public.financing_events (
    offer_id, borrower_id, lender_id, actor_id, actor_role, event_type, details
  )
  select id, borrower_id, lender_id, auth.uid(), 'system', 'offer_expired',
         jsonb_build_object('version', version, 'valid_until', valid_until, 'simulated', true)
  from expired;
$$;

create or replace function public.rushd_hash_code(p_agreement_id uuid, p_code text)
returns text
language sql
immutable
set search_path = public, pg_temp
as $$
  select encode(sha256(convert_to(p_agreement_id::text || ':' || p_code, 'UTF8')), 'hex');
$$;


-- =====================================================================
-- 5) JOURNEY FUNCTIONS (the only way to write these tables)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 5a) Lender issues an offer for an approved application.
-- ---------------------------------------------------------------------
create or replace function public.rushd_issue_offer(
  p_application_id uuid,
  p_principal numeric,
  p_annual_profit_rate numeric,
  p_rate_type text,
  p_term_months integer,
  p_admin_fee numeric,
  p_valid_days integer default 7
)
returns public.financing_offers
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := public.rushd_require_role('lender');
  v_cfg public.rushd_settings%rowtype;
  v_app public.loan_applications%rowtype;
  v_requested numeric;
  v_offer_max numeric;
  v_fee_cap numeric;
  v_calc record;
  v_income numeric;
  v_existing numeric;
  v_salary_dbr numeric;
  v_total_dbr numeric;
  v_total_cap numeric;
  v_version integer;
  v_offer public.financing_offers%rowtype;
begin
  select * into v_cfg from public.rushd_settings limit 1;

  -- Lock the application so two offers cannot be issued at the same time.
  select * into v_app
  from public.loan_applications
  where id = p_application_id
  for update;

  if not found or v_app.lender_id <> v_uid then
    raise exception 'Application not found.';
  end if;

  if v_app.status <> 'approved' then
    raise exception 'An offer can only be issued for an approved application.';
  end if;

  perform public.rushd_expire_stale_offers(p_application_id);

  if exists (
    select 1 from public.financing_offers
    where application_id = p_application_id
      and status in ('offer_issued', 'offer_accepted')
  ) then
    raise exception 'This application already has a live financing offer.';
  end if;

  -- ---- validate the lender's inputs ----
  if p_rate_type is null or p_rate_type not in ('flat', 'reducing') then
    raise exception 'Rate type must be flat or reducing.';
  end if;

  if p_term_months is null
     or p_term_months < v_cfg.min_term_months
     or p_term_months > v_cfg.max_term_months then
    raise exception 'The term must be between % and % months (SAMA consumer finance limit).',
      v_cfg.min_term_months, v_cfg.max_term_months;
  end if;

  if p_principal is null or p_principal <= 0 then
    raise exception 'The amount must be greater than zero.';
  end if;

  if p_annual_profit_rate is null or p_annual_profit_rate < 0 or p_annual_profit_rate > 100 then
    raise exception 'The profit rate must be between 0 and 100 percent.';
  end if;

  if p_admin_fee is null or p_admin_fee < 0 then
    raise exception 'The admin fee cannot be negative.';
  end if;

  v_fee_cap := public.rushd_admin_fee_cap(p_principal);

  if p_admin_fee > v_fee_cap then
    raise exception 'The admin fee cannot be more than SAR % for this amount (% %% of the amount, up to SAR %).',
      v_fee_cap, v_cfg.admin_fee_pct, v_cfg.admin_fee_max_sar;
  end if;

  if p_valid_days is null or p_valid_days < 1 or p_valid_days > v_cfg.max_offer_valid_days then
    raise exception 'The offer must be valid for 1 to % days.', v_cfg.max_offer_valid_days;
  end if;

  select r.requested_amount, lo.max_amount
  into v_requested, v_offer_max
  from public.loan_requests r
  join public.loan_offers lo on lo.id = r.offer_id
  where r.id = v_app.request_id;

  if p_principal > v_requested then
    raise exception 'The amount cannot be more than the borrower requested (SAR %).', v_requested;
  end if;

  if p_principal > v_offer_max then
    raise exception 'The amount cannot be more than the maximum of your loan offer (SAR %).', v_offer_max;
  end if;

  -- ---- calculate (never trusted from the client) ----
  select c.* into v_calc
  from public.rushd_calc_financing(
    p_principal, p_annual_profit_rate, p_rate_type, p_term_months, p_admin_fee
  ) c;

  -- ---- Debt Burden Ratio ----
  select bp.monthly_income, coalesce(bp.existing_debts, 0)
  into v_income, v_existing
  from public.borrower_profiles bp
  where bp.user_id = v_app.borrower_id;

  if v_income is null or v_income <= 0 then
    raise exception 'The borrower''s monthly income is missing, so the Debt Burden Ratio cannot be checked.';
  end if;

  v_salary_dbr := round(v_calc.monthly_installment / v_income * 100, 2);
  v_total_dbr := round((v_existing + v_calc.monthly_installment) / v_income * 100, 2);

  v_total_cap := case
    when v_income <= v_cfg.dbr_income_limit_sar then v_cfg.dbr_total_cap_pct
    else v_cfg.dbr_total_cap_above_limit_pct
  end;

  if v_salary_dbr > v_cfg.dbr_salary_deduction_cap_pct then
    raise exception 'Debt Burden Ratio check failed: the new installment (SAR %) is % %% of the borrower''s income; the limit is % %%. Lower the amount or extend the term.',
      v_calc.monthly_installment, v_salary_dbr, v_cfg.dbr_salary_deduction_cap_pct;
  end if;

  if v_total_dbr > v_total_cap then
    raise exception 'Debt Burden Ratio check failed: existing obligations plus the new installment are % %% of the borrower''s income; the limit is % %%. Lower the amount or extend the term.',
      v_total_dbr, v_total_cap;
  end if;

  -- ---- save ----
  select coalesce(max(version), 0) + 1
  into v_version
  from public.financing_offers
  where application_id = p_application_id;

  insert into public.financing_offers (
    application_id, borrower_id, lender_id,
    principal, annual_profit_rate, rate_type, term_months, admin_fee,
    monthly_installment, total_profit, total_repayable, apr,
    salary_dbr, total_dbr,
    valid_until, version, status
  )
  values (
    p_application_id, v_app.borrower_id, v_uid,
    p_principal, p_annual_profit_rate, p_rate_type, p_term_months, p_admin_fee,
    v_calc.monthly_installment, v_calc.total_profit, v_calc.total_repayable, v_calc.apr,
    v_salary_dbr, v_total_dbr,
    now() + make_interval(days => p_valid_days), v_version, 'offer_issued'
  )
  returning * into v_offer;

  perform public.rushd_log_event(
    v_offer.id, null, v_offer.borrower_id, v_offer.lender_id,
    'lender', 'offer_issued',
    jsonb_build_object(
      'version', v_offer.version,
      'principal', v_offer.principal,
      'annual_profit_rate', v_offer.annual_profit_rate,
      'rate_type', v_offer.rate_type,
      'term_months', v_offer.term_months,
      'admin_fee', v_offer.admin_fee,
      'monthly_installment', v_offer.monthly_installment,
      'apr', v_offer.apr,
      'salary_dbr', v_offer.salary_dbr,
      'total_dbr', v_offer.total_dbr,
      'valid_until', v_offer.valid_until
    )
  );

  return v_offer;
end;
$$;

-- ---------------------------------------------------------------------
-- 5b) Borrower accepts the offer (Key Facts Statement + consents).
-- ---------------------------------------------------------------------
create or replace function public.rushd_accept_offer(
  p_offer_id uuid,
  p_consents jsonb
)
returns public.financing_agreements
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := public.rushd_require_role('borrower');
  v_offer public.financing_offers%rowtype;
  v_agreement public.financing_agreements%rowtype;
  v_key text;
  v_waiver boolean;
  v_reference text;
begin
  -- Row lock: a second accept waits here, then sees offer_accepted.
  select * into v_offer
  from public.financing_offers
  where id = p_offer_id
  for update;

  if not found or v_offer.borrower_id <> v_uid then
    raise exception 'Financing offer not found.';
  end if;

  if v_offer.status <> 'offer_issued' then
    raise exception 'This offer is no longer open.';
  end if;

  if v_offer.valid_until <= now() then
    raise exception 'This offer has expired. Ask the bank for a new offer.';
  end if;

  if p_consents is null or jsonb_typeof(p_consents) <> 'object' then
    raise exception 'Please accept all the required consents.';
  end if;

  foreach v_key in array array[
    'credit_bureau_consent', 'terms_read', 'simulation_ack', 'data_sharing'
  ] loop
    if coalesce(p_consents -> v_key, 'null'::jsonb) <> 'true'::jsonb then
      raise exception 'Please accept all the required consents (missing: %).', v_key;
    end if;
  end loop;

  -- early_disbursement_waiver: the borrower agrees that the lender may
  -- release the funds before the cooling-off period ends (some lenders
  -- allow this). In this demo, early disbursement ends the cooling-off,
  -- so the borrower can no longer withdraw after the funds are released.
  v_waiver := coalesce(p_consents -> 'early_disbursement_waiver', 'false'::jsonb) = 'true'::jsonb;

  v_reference := 'RSHD-'
    || to_char(now() at time zone 'Asia/Riyadh', 'YYYY')
    || '-'
    || lpad(nextval('public.rushd_agreement_ref_seq')::text, 6, '0');

  update public.financing_offers
  set status = 'offer_accepted'
  where id = p_offer_id;

  insert into public.financing_agreements (
    offer_id, borrower_id, lender_id, reference_no,
    kfs_accepted_at, consents, status
  )
  values (
    v_offer.id, v_offer.borrower_id, v_offer.lender_id, v_reference,
    now(),
    jsonb_build_object(
      'credit_bureau_consent', true,
      'terms_read', true,
      'simulation_ack', true,
      'data_sharing', true,
      'early_disbursement_waiver', v_waiver,
      'accepted_at', now()
    ),
    'offer_accepted'
  )
  returning * into v_agreement;

  perform public.rushd_log_event(
    v_offer.id, v_agreement.id, v_offer.borrower_id, v_offer.lender_id,
    'borrower', 'offer_accepted',
    jsonb_build_object(
      'reference_no', v_reference,
      'early_disbursement_waiver', v_waiver
    )
  );

  return v_agreement;
end;
$$;

-- ---------------------------------------------------------------------
-- 5c) Borrower declines the offer.
-- ---------------------------------------------------------------------
create or replace function public.rushd_decline_offer(
  p_offer_id uuid,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := public.rushd_require_role('borrower');
  v_offer public.financing_offers%rowtype;
begin
  select * into v_offer
  from public.financing_offers
  where id = p_offer_id
  for update;

  if not found or v_offer.borrower_id <> v_uid then
    raise exception 'Financing offer not found.';
  end if;

  if v_offer.status <> 'offer_issued' then
    raise exception 'This offer is no longer open.';
  end if;

  update public.financing_offers
  set status = 'offer_declined'
  where id = p_offer_id;

  perform public.rushd_log_event(
    v_offer.id, null, v_offer.borrower_id, v_offer.lender_id,
    'borrower', 'offer_declined',
    jsonb_build_object('reason', left(nullif(trim(p_reason), ''), 500))
  );
end;
$$;

-- ---------------------------------------------------------------------
-- 5d) Borrower asks for a (simulated) signing code.
--     Returns the demo code — no SMS is sent. Only a hash is stored.
-- ---------------------------------------------------------------------
create or replace function public.rushd_request_signing_code(p_agreement_id uuid)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := public.rushd_require_role('borrower');
  v_cfg public.rushd_settings%rowtype;
  v_agreement public.financing_agreements%rowtype;
  v_expires timestamptz;
begin
  select * into v_cfg from public.rushd_settings limit 1;

  select * into v_agreement
  from public.financing_agreements
  where id = p_agreement_id
  for update;

  if not found or v_agreement.borrower_id <> v_uid then
    raise exception 'Agreement not found.';
  end if;

  if v_agreement.status <> 'offer_accepted' then
    raise exception 'This agreement is not waiting for a signature.';
  end if;

  v_expires := now() + make_interval(mins => v_cfg.signing_code_minutes);

  insert into public.financing_signing_codes (agreement_id, code_hash, expires_at, attempts)
  values (
    p_agreement_id,
    public.rushd_hash_code(p_agreement_id, v_cfg.demo_signing_code),
    v_expires,
    0
  )
  on conflict (agreement_id) do update
  set code_hash = excluded.code_hash,
      expires_at = excluded.expires_at,
      attempts = 0,
      created_at = now();

  perform public.rushd_log_event(
    v_agreement.offer_id, v_agreement.id, v_agreement.borrower_id, v_agreement.lender_id,
    'borrower', 'signing_code_requested',
    jsonb_build_object('expires_at', v_expires)
  );

  return v_cfg.demo_signing_code;
end;
$$;

-- ---------------------------------------------------------------------
-- 5e) Borrower signs with the code (simulated OTP).
--     Returns jsonb instead of raising for a wrong code, so the attempt
--     counter is saved: {"ok": false, "error": ..., "attempts_left": n}
--     or {"ok": true, "reference_no": ..., "cooling_off_ends_at": ...}.
-- ---------------------------------------------------------------------
create or replace function public.rushd_sign_agreement(
  p_agreement_id uuid,
  p_otp_code text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := public.rushd_require_role('borrower');
  v_cfg public.rushd_settings%rowtype;
  v_agreement public.financing_agreements%rowtype;
  v_offer public.financing_offers%rowtype;
  v_code public.financing_signing_codes%rowtype;
  v_signed_at timestamptz := now();
  v_ends_at timestamptz;
begin
  select * into v_cfg from public.rushd_settings limit 1;

  select * into v_agreement
  from public.financing_agreements
  where id = p_agreement_id
  for update;

  if not found or v_agreement.borrower_id <> v_uid then
    raise exception 'Agreement not found.';
  end if;

  if v_agreement.status <> 'offer_accepted' then
    raise exception 'This agreement is not waiting for a signature.';
  end if;

  select * into v_code
  from public.financing_signing_codes
  where agreement_id = p_agreement_id
  for update;

  if not found then
    raise exception 'Please request a signing code first.';
  end if;

  if v_code.expires_at <= now() then
    raise exception 'The signing code has expired. Please request a new code.';
  end if;

  if v_code.attempts >= v_cfg.signing_max_attempts then
    raise exception 'Too many incorrect attempts. Please request a new code.';
  end if;

  if v_code.code_hash <> public.rushd_hash_code(p_agreement_id, trim(coalesce(p_otp_code, ''))) then
    update public.financing_signing_codes
    set attempts = attempts + 1
    where agreement_id = p_agreement_id;

    perform public.rushd_log_event(
      v_agreement.offer_id, v_agreement.id, v_agreement.borrower_id, v_agreement.lender_id,
      'borrower', 'signing_failed',
      jsonb_build_object('attempt', v_code.attempts + 1)
    );

    return jsonb_build_object(
      'ok', false,
      'error', 'Incorrect code.',
      'attempts_left', greatest(v_cfg.signing_max_attempts - v_code.attempts - 1, 0)
    );
  end if;

  delete from public.financing_signing_codes where agreement_id = p_agreement_id;

  v_ends_at := case
    when v_cfg.demo_fast_cooling_off
      then v_signed_at + make_interval(mins => v_cfg.demo_fast_cooling_off_minutes)
    else public.rushd_add_business_days(v_signed_at, v_cfg.cooling_off_business_days)
  end;

  update public.financing_agreements
  set signed_at = v_signed_at,
      signature_method = 'simulated_otp',
      cooling_off_ends_at = v_ends_at,
      status = 'cooling_off',
      updated_at = now()
  where id = p_agreement_id
  returning * into v_agreement;

  -- Provisional schedule from the signing date; rebuilt at disbursement.
  select * into v_offer from public.financing_offers where id = v_agreement.offer_id;

  insert into public.repayment_schedule (
    agreement_id, installment_no, due_date,
    principal_part, profit_part, installment, remaining_balance
  )
  select v_agreement.id, s.installment_no, s.due_date,
         s.principal_part, s.profit_part, s.installment, s.remaining_balance
  from public.rushd_schedule_rows(
    v_offer.principal, v_offer.annual_profit_rate, v_offer.rate_type,
    v_offer.term_months, (v_signed_at at time zone 'Asia/Riyadh')::date
  ) s;

  perform public.rushd_log_event(
    v_agreement.offer_id, v_agreement.id, v_agreement.borrower_id, v_agreement.lender_id,
    'borrower', 'contract_signed',
    jsonb_build_object('signature_method', 'simulated_otp', 'signed_at', v_signed_at)
  );

  perform public.rushd_log_event(
    v_agreement.offer_id, v_agreement.id, v_agreement.borrower_id, v_agreement.lender_id,
    'system', 'cooling_off_started',
    jsonb_build_object(
      'cooling_off_ends_at', v_ends_at,
      'demo_fast_cooling_off', v_cfg.demo_fast_cooling_off
    )
  );

  return jsonb_build_object(
    'ok', true,
    'reference_no', v_agreement.reference_no,
    'cooling_off_ends_at', v_ends_at
  );
end;
$$;

-- ---------------------------------------------------------------------
-- 5f) Borrower withdraws during the cooling-off period.
-- ---------------------------------------------------------------------
create or replace function public.rushd_withdraw(p_agreement_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := public.rushd_require_role('borrower');
  v_agreement public.financing_agreements%rowtype;
begin
  select * into v_agreement
  from public.financing_agreements
  where id = p_agreement_id
  for update;

  if not found or v_agreement.borrower_id <> v_uid then
    raise exception 'Agreement not found.';
  end if;

  if v_agreement.status <> 'cooling_off' then
    raise exception 'You can only withdraw during the cooling-off period.';
  end if;

  if now() >= v_agreement.cooling_off_ends_at then
    raise exception 'The cooling-off period ended on % (Riyadh time).',
      to_char(v_agreement.cooling_off_ends_at at time zone 'Asia/Riyadh', 'YYYY-MM-DD HH24:MI');
  end if;

  update public.financing_agreements
  set status = 'withdrawn',
      withdrawn_at = now(),
      updated_at = now()
  where id = p_agreement_id;

  -- Frees the application so the lender may issue a new offer later.
  update public.financing_offers
  set status = 'cancelled'
  where id = v_agreement.offer_id;

  perform public.rushd_log_event(
    v_agreement.offer_id, v_agreement.id, v_agreement.borrower_id, v_agreement.lender_id,
    'borrower', 'withdrawn',
    jsonb_build_object('cooling_off_ends_at', v_agreement.cooling_off_ends_at)
  );
end;
$$;

-- ---------------------------------------------------------------------
-- 5g) Lender releases the funds (simulated).
--     Allowed after the cooling-off ends, or earlier if the borrower gave
--     the early_disbursement_waiver. Only the last 4 IBAN digits are kept.
-- ---------------------------------------------------------------------
create or replace function public.rushd_disburse(p_agreement_id uuid)
returns public.financing_agreements
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := public.rushd_require_role('lender');
  v_agreement public.financing_agreements%rowtype;
  v_offer public.financing_offers%rowtype;
  v_iban text;
  v_waiver boolean;
  v_early boolean;
  v_disbursed_at timestamptz := now();
begin
  select * into v_agreement
  from public.financing_agreements
  where id = p_agreement_id
  for update;

  if not found or v_agreement.lender_id <> v_uid then
    raise exception 'Agreement not found.';
  end if;

  if v_agreement.status <> 'cooling_off' then
    raise exception 'Funds can only be released for a signed agreement in its cooling-off period.';
  end if;

  v_waiver := coalesce(v_agreement.consents -> 'early_disbursement_waiver', 'false'::jsonb) = 'true'::jsonb;
  v_early := v_disbursed_at < v_agreement.cooling_off_ends_at;

  if v_early and not v_waiver then
    raise exception 'Funds can be released after the cooling-off period ends on % (Riyadh time).',
      to_char(v_agreement.cooling_off_ends_at at time zone 'Asia/Riyadh', 'YYYY-MM-DD HH24:MI');
  end if;

  select * into v_offer from public.financing_offers where id = v_agreement.offer_id;

  select upper(regexp_replace(coalesce(la.iban, ''), '\s', '', 'g'))
  into v_iban
  from public.loan_applications la
  where la.id = v_offer.application_id;

  if v_iban is null or v_iban !~ '^SA[0-9]{22}$' then
    raise exception 'The borrower has not provided a valid Saudi IBAN (SA followed by 22 digits).';
  end if;

  update public.financing_agreements
  set disbursed_at = v_disbursed_at,
      disbursement_iban_last4 = right(v_iban, 4),
      status = 'active',
      updated_at = now()
  where id = p_agreement_id
  returning * into v_agreement;

  -- Rebuild the schedule so the first installment is due one month
  -- after the funds are released.
  delete from public.repayment_schedule where agreement_id = p_agreement_id;

  insert into public.repayment_schedule (
    agreement_id, installment_no, due_date,
    principal_part, profit_part, installment, remaining_balance
  )
  select v_agreement.id, s.installment_no, s.due_date,
         s.principal_part, s.profit_part, s.installment, s.remaining_balance
  from public.rushd_schedule_rows(
    v_offer.principal, v_offer.annual_profit_rate, v_offer.rate_type,
    v_offer.term_months, (v_disbursed_at at time zone 'Asia/Riyadh')::date
  ) s;

  perform public.rushd_log_event(
    v_agreement.offer_id, v_agreement.id, v_agreement.borrower_id, v_agreement.lender_id,
    'lender', 'disbursed',
    jsonb_build_object(
      'amount', v_offer.principal - v_offer.admin_fee,
      'iban_last4', right(v_iban, 4),
      'early_disbursement', v_early,
      'early_disbursement_waiver', v_waiver
    )
  );

  perform public.rushd_log_event(
    v_agreement.offer_id, v_agreement.id, v_agreement.borrower_id, v_agreement.lender_id,
    'system', 'activated',
    jsonb_build_object(
      'first_due_date', (
        select min(due_date) from public.repayment_schedule where agreement_id = v_agreement.id
      )
    )
  );

  return v_agreement;
end;
$$;


-- =====================================================================
-- 6) ROW LEVEL SECURITY — read your own rows only, no direct writes
-- =====================================================================

alter table public.rushd_settings enable row level security;
alter table public.financing_offers enable row level security;
alter table public.financing_agreements enable row level security;
alter table public.repayment_schedule enable row level security;
alter table public.financing_events enable row level security;
alter table public.financing_signing_codes enable row level security;

create policy rushd_settings_select
  on public.rushd_settings for select to authenticated
  using (true);

create policy financing_offers_select
  on public.financing_offers for select to authenticated
  using (borrower_id = auth.uid() or lender_id = auth.uid());

create policy financing_agreements_select
  on public.financing_agreements for select to authenticated
  using (borrower_id = auth.uid() or lender_id = auth.uid());

create policy repayment_schedule_select
  on public.repayment_schedule for select to authenticated
  using (
    exists (
      select 1 from public.financing_agreements a
      where a.id = repayment_schedule.agreement_id
        and (a.borrower_id = auth.uid() or a.lender_id = auth.uid())
    )
  );

create policy financing_events_select
  on public.financing_events for select to authenticated
  using (borrower_id = auth.uid() or lender_id = auth.uid());

-- financing_signing_codes: no policy = nobody can read or write it directly.

-- Table privileges (defence in depth on top of RLS).
revoke all on
  public.rushd_settings,
  public.financing_offers,
  public.financing_agreements,
  public.repayment_schedule,
  public.financing_events,
  public.financing_signing_codes
from anon, authenticated;

grant select on
  public.rushd_settings,
  public.financing_offers,
  public.financing_agreements,
  public.repayment_schedule,
  public.financing_events
to authenticated;

revoke all on sequence public.rushd_agreement_ref_seq from anon, authenticated;


-- =====================================================================
-- 7) FUNCTION PRIVILEGES
-- =====================================================================

-- Journey functions: signed-in users only.
revoke execute on function
  public.rushd_issue_offer(uuid, numeric, numeric, text, integer, numeric, integer),
  public.rushd_accept_offer(uuid, jsonb),
  public.rushd_decline_offer(uuid, text),
  public.rushd_request_signing_code(uuid),
  public.rushd_sign_agreement(uuid, text),
  public.rushd_withdraw(uuid),
  public.rushd_disburse(uuid)
from public, anon;

grant execute on function
  public.rushd_issue_offer(uuid, numeric, numeric, text, integer, numeric, integer),
  public.rushd_accept_offer(uuid, jsonb),
  public.rushd_decline_offer(uuid, text),
  public.rushd_request_signing_code(uuid),
  public.rushd_sign_agreement(uuid, text),
  public.rushd_withdraw(uuid),
  public.rushd_disburse(uuid)
to authenticated;

-- Pure calculations: signed-in users may call them to preview an offer.
revoke execute on function
  public.rushd_admin_fee_cap(numeric),
  public.rushd_schedule_rows(numeric, numeric, text, integer, date),
  public.rushd_calc_apr(numeric, numeric, integer),
  public.rushd_calc_financing(numeric, numeric, text, integer, numeric),
  public.rushd_add_business_days(timestamptz, integer)
from public, anon;

grant execute on function
  public.rushd_admin_fee_cap(numeric),
  public.rushd_schedule_rows(numeric, numeric, text, integer, date),
  public.rushd_calc_apr(numeric, numeric, integer),
  public.rushd_calc_financing(numeric, numeric, text, integer, numeric),
  public.rushd_add_business_days(timestamptz, integer)
to authenticated;

-- Internal helpers: only used inside the journey functions.
revoke execute on function
  public.rushd_require_role(text),
  public.rushd_log_event(uuid, uuid, uuid, uuid, text, text, jsonb),
  public.rushd_expire_stale_offers(uuid),
  public.rushd_hash_code(uuid, text),
  public.rushd_events_append_only()
from public, anon, authenticated;

commit;


-- =====================================================================
-- ROLLBACK (commented out). Removes everything this file created.
-- The tables from 20261031000000_security_fixes.sql are not touched.
-- =====================================================================
-- begin;
--
-- drop function if exists
--   public.rushd_issue_offer(uuid, numeric, numeric, text, integer, numeric, integer),
--   public.rushd_accept_offer(uuid, jsonb),
--   public.rushd_decline_offer(uuid, text),
--   public.rushd_request_signing_code(uuid),
--   public.rushd_sign_agreement(uuid, text),
--   public.rushd_withdraw(uuid),
--   public.rushd_disburse(uuid),
--   public.rushd_calc_financing(numeric, numeric, text, integer, numeric),
--   public.rushd_calc_apr(numeric, numeric, integer),
--   public.rushd_schedule_rows(numeric, numeric, text, integer, date),
--   public.rushd_admin_fee_cap(numeric),
--   public.rushd_add_business_days(timestamptz, integer),
--   public.rushd_require_role(text),
--   public.rushd_log_event(uuid, uuid, uuid, uuid, text, text, jsonb),
--   public.rushd_expire_stale_offers(uuid),
--   public.rushd_hash_code(uuid, text);
--
-- drop table if exists
--   public.financing_signing_codes,
--   public.financing_events,
--   public.repayment_schedule,
--   public.financing_agreements,
--   public.financing_offers,
--   public.rushd_settings;
--
-- drop function if exists public.rushd_events_append_only();
-- drop sequence if exists public.rushd_agreement_ref_seq;
--
-- commit;
