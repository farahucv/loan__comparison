-- =====================================================================
-- RUSHD — Rushd financings count as debt (simulated credit bureau)
--
-- In reality the first bank reports a loan to the credit bureau (SIMAH)
-- and every later debt-burden check includes it. This migration simulates
-- that: the monthly installments of a borrower's Rushd agreements that are
-- accepted, in cooling-off or active are added to their declared debts in
-- every check.
--
--   1) rushd_borrower_obligations(): declared debts + Rushd installments
--   2) set_loan_request_eligibility(): eligibility at request time
--   3) rushd_issue_offer(): DBR check when the bank issues the offer
--   4) rushd_accept_offer(): DBR re-check with the CURRENT obligations
--
-- borrower_profiles.existing_debts is NOT changed: it stays the debt the
-- borrower declared (outside Rushd).
--
-- Each function below is a copy of its current definition with only the
-- marked CHANGED lines different.
--
-- Requires 20261031120000_financing_journey.sql.
-- Run once in Supabase -> SQL Editor. One transaction: all or nothing.
-- =====================================================================
begin;


-- =====================================================================
-- 1) OBLIGATIONS
-- =====================================================================

-- Internal: no access check. Only used inside the functions below
-- (which run as the owner), never callable by users.
create or replace function public.rushd_obligations_internal(p_borrower_id uuid)
returns table (
  declared_debts numeric,
  rushd_installments numeric,
  rushd_count integer,
  total_obligations numeric
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  with declared as (
    select coalesce(
      (select bp.existing_debts from public.borrower_profiles bp
       where bp.user_id = p_borrower_id),
      0
    ) as amount
  ),
  rushd as (
    -- Agreements that are a real debt: accepted, signed / in cooling-off,
    -- or active. ('contract_signed' and 'disbursed' are transitional
    -- statuses of the same agreements and are counted too.)
    select coalesce(sum(o.monthly_installment), 0) as amount,
           count(*)::integer as n
    from public.financing_agreements a
    join public.financing_offers o on o.id = a.offer_id
    where a.borrower_id = p_borrower_id
      and a.status in ('offer_accepted', 'contract_signed', 'cooling_off',
                       'disbursed', 'active')
  )
  select declared.amount,
         rushd.amount,
         rushd.n,
         declared.amount + rushd.amount
  from declared, rushd;
$$;

-- Public: numbers only (no lender names or IDs). Callable by the borrower
-- themself, or by a verified lender who has a loan request from them.
create or replace function public.rushd_borrower_obligations(p_borrower_id uuid)
returns table (
  declared_debts numeric,
  rushd_installments numeric,
  rushd_count integer,
  total_obligations numeric
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'You must sign in first.';
  end if;

  if v_uid <> p_borrower_id
     and not exists (
       select 1
       from public.profiles p
       join public.loan_requests r on r.lender_id = p.id
       where p.id = v_uid
         and p.role = 'lender'
         and p.lender_verified
         and r.borrower_id = p_borrower_id
     ) then
    raise exception 'You do not have permission to see this borrower''s obligations.';
  end if;

  return query
  select o.declared_debts, o.rushd_installments, o.rushd_count, o.total_obligations
  from public.rushd_obligations_internal(p_borrower_id) o;
end;
$$;


-- =====================================================================
-- 2) ELIGIBILITY AT REQUEST TIME
--    Copy of set_loan_request_eligibility() from
--    20261001000000_baseline_schema.sql; only the CHANGED lines differ.
-- =====================================================================

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

  v_rushd_installments numeric;  -- CHANGED (new variable)
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

  -- CHANGED: obligations = declared debts + active Rushd installments.
  select o.rushd_installments
  into v_rushd_installments
  from public.rushd_obligations_internal(new.borrower_id) o;

  v_monthly_obligations :=
    coalesce(v_monthly_obligations, 0) + coalesce(v_rushd_installments, 0);

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


-- =====================================================================
-- 3) ISSUE OFFER
--    Copy of rushd_issue_offer() from 20261031120000_financing_journey.sql;
--    only the CHANGED lines differ.
-- =====================================================================
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
  v_rushd numeric;  -- CHANGED (new variable)
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
  select bp.monthly_income
  into v_income
  from public.borrower_profiles bp
  where bp.user_id = v_app.borrower_id;

  if v_income is null or v_income <= 0 then
    raise exception 'The borrower''s monthly income is missing, so the Debt Burden Ratio cannot be checked.';
  end if;

  -- CHANGED: declared debts and active Rushd installments (simulated
  -- credit bureau) instead of declared debts only.
  select o.declared_debts, o.rushd_installments
  into v_existing, v_rushd
  from public.rushd_obligations_internal(v_app.borrower_id) o;

  -- CHANGED: Rushd installments count towards both ratios.
  v_salary_dbr := round((v_rushd + v_calc.monthly_installment) / v_income * 100, 2);
  v_total_dbr := round((v_existing + v_rushd + v_calc.monthly_installment) / v_income * 100, 2);

  v_total_cap := case
    when v_income <= v_cfg.dbr_income_limit_sar then v_cfg.dbr_total_cap_pct
    else v_cfg.dbr_total_cap_above_limit_pct
  end;

  -- CHANGED (wording only): the ratio now includes Rushd financing.
  if v_salary_dbr > v_cfg.dbr_salary_deduction_cap_pct then
    raise exception 'Debt Burden Ratio check failed: the new installment (SAR %) plus existing Rushd financing is % %% of the borrower''s income; the limit is % %%. Lower the amount or extend the term.',
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
      'rushd_installments', v_rushd,  -- CHANGED (audit detail)
      'valid_until', v_offer.valid_until
    )
  );

  return v_offer;
end;
$$;


-- =====================================================================
-- 4) ACCEPT OFFER
--    Copy of rushd_accept_offer() from 20261031120000_financing_journey.sql;
--    only the CHANGED / NEW lines differ.
-- =====================================================================
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

  -- NEW: for the debt-burden re-check
  v_cfg public.rushd_settings%rowtype;
  v_income numeric;
  v_existing numeric;
  v_rushd numeric;
  v_total_cap numeric;
begin
  -- NEW: one accept at a time per borrower, so two offers accepted at the
  -- same moment cannot both pass the debt-burden re-check below.
  perform pg_advisory_xact_lock(hashtext('rushd_accept:' || v_uid::text));

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

  -- NEW: re-run the debt-burden check with the CURRENT obligations; the
  -- borrower may have accepted another Rushd offer since this one was
  -- issued. Same formulas and caps as rushd_issue_offer.
  select * into v_cfg from public.rushd_settings limit 1;

  select bp.monthly_income
  into v_income
  from public.borrower_profiles bp
  where bp.user_id = v_uid;

  if v_income is null or v_income <= 0 then
    raise exception 'Your monthly income is missing from your profile, so this offer cannot be accepted.';
  end if;

  select o.declared_debts, o.rushd_installments
  into v_existing, v_rushd
  from public.rushd_obligations_internal(v_uid) o;

  v_total_cap := case
    when v_income <= v_cfg.dbr_income_limit_sar then v_cfg.dbr_total_cap_pct
    else v_cfg.dbr_total_cap_above_limit_pct
  end;

  if round((v_rushd + v_offer.monthly_installment) / v_income * 100, 2)
       > v_cfg.dbr_salary_deduction_cap_pct
     or round((v_existing + v_rushd + v_offer.monthly_installment) / v_income * 100, 2)
       > v_total_cap then
    raise exception 'Your monthly obligations have changed since this offer was issued. Accepting it would exceed the allowed limit. Ask the bank for an updated offer.';
  end if;

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


-- =====================================================================
-- 5) PRIVILEGES
-- =====================================================================
revoke execute on function public.rushd_borrower_obligations(uuid) from public, anon;
grant execute on function public.rushd_borrower_obligations(uuid) to authenticated;

revoke execute on function public.rushd_obligations_internal(uuid)
  from public, anon, authenticated;

-- create or replace keeps the existing grants of the three replaced
-- functions, so nothing else changes.

commit;


-- =====================================================================
-- ROLLBACK (commented out)
-- =====================================================================
-- begin;
--
-- -- Restore the previous definitions by re-running, unchanged:
-- --   * set_loan_request_eligibility()  from 20261001000000_baseline_schema.sql
-- --   * rushd_issue_offer(...)          from 20261031120000_financing_journey.sql
-- --   * rushd_accept_offer(...)         from 20261031120000_financing_journey.sql
-- -- (they no longer call the functions below), then:
--
-- drop function if exists public.rushd_borrower_obligations(uuid);
-- drop function if exists public.rushd_obligations_internal(uuid);
--
-- commit;
