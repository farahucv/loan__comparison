-- =====================================================================
-- RUSHD — Cancel or lapse accepted-but-unsigned agreements
--
-- Gap fixed: an agreement in status 'offer_accepted' (accepted, never
-- signed) counted as debt forever and the borrower could not cancel it.
--
--   1) rushd_settings.unsigned_lapse_days (default 3)
--   2) rushd_lapse_unsigned(): marks a borrower's stale acceptances
--      'cancelled' and logs 'agreement_lapsed' (like
--      rushd_expire_stale_offers does for offers)
--   3) rushd_obligations_internal(): stale acceptances are not debt
--   4) rushd_cancel_unsigned(): the borrower cancels an acceptance
--   5) rushd_request_signing_code() / rushd_sign_agreement(): refuse a
--      lapsed acceptance
--   6) rushd_issue_offer() / rushd_accept_offer(): lapse stale
--      acceptances first, so a lapsed one never blocks a new offer
--
-- Each replaced function is a copy of its current definition with only
-- the marked CHANGED / NEW lines different.
--
-- Requires 20261031160000_rushd_obligations.sql.
-- Run once in Supabase -> SQL Editor. One transaction: all or nothing.
-- =====================================================================
begin;


-- =====================================================================
-- 1) SETTING
-- =====================================================================
alter table public.rushd_settings
  add column if not exists unsigned_lapse_days integer not null default 3;

alter table public.rushd_settings
  drop constraint if exists rushd_settings_unsigned_lapse_days_check;

alter table public.rushd_settings
  add constraint rushd_settings_unsigned_lapse_days_check
  check (unsigned_lapse_days >= 1);


-- =====================================================================
-- 2) LAPSE STALE ACCEPTANCES (internal)
--    An 'offer_accepted' agreement whose kfs_accepted_at is
--    unsigned_lapse_days or more in the past is cancelled, its offer is
--    cancelled (so the bank may issue a new version), its signing code is
--    removed and 'agreement_lapsed' is logged.
-- =====================================================================
create or replace function public.rushd_lapse_unsigned(p_borrower_id uuid)
returns void
language sql
security definer
set search_path = public, pg_temp
as $$
  with cfg as (
    select s.unsigned_lapse_days as days from public.rushd_settings s limit 1
  ),
  lapsed as (
    update public.financing_agreements a
    set status = 'cancelled',
        updated_at = now()
    from cfg
    where a.borrower_id = p_borrower_id
      and a.status = 'offer_accepted'
      and a.kfs_accepted_at <= now() - make_interval(days => cfg.days)
    returning a.id, a.offer_id, a.borrower_id, a.lender_id, a.kfs_accepted_at
  ),
  cancelled_offers as (
    update public.financing_offers o
    set status = 'cancelled'
    from lapsed
    where o.id = lapsed.offer_id
    returning o.id
  ),
  removed_codes as (
    delete from public.financing_signing_codes c
    using lapsed
    where c.agreement_id = lapsed.id
    returning c.agreement_id
  )
  insert into public.financing_events (
    offer_id, agreement_id, borrower_id, lender_id,
    actor_id, actor_role, event_type, details
  )
  select lapsed.offer_id, lapsed.id, lapsed.borrower_id, lapsed.lender_id,
         auth.uid(), 'system', 'agreement_lapsed',
         jsonb_build_object(
           'accepted_at', lapsed.kfs_accepted_at,
           'lapse_days', (select days from cfg),
           'simulated', true
         )
  from lapsed;
$$;


-- =====================================================================
-- 3) OBLIGATIONS
--    Copy of rushd_obligations_internal() from
--    20261031160000_rushd_obligations.sql; only the CHANGED lines differ.
-- =====================================================================
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
      -- CHANGED: an 'offer_accepted' agreement older than
      -- unsigned_lapse_days has lapsed and is no longer debt.
      and (
        a.status in ('contract_signed', 'cooling_off', 'disbursed', 'active')
        or (
          a.status = 'offer_accepted'
          and a.kfs_accepted_at > now() - make_interval(
            days => (select s.unsigned_lapse_days from public.rushd_settings s limit 1)
          )
        )
      )
  )
  select declared.amount,
         rushd.amount,
         rushd.n,
         declared.amount + rushd.amount
  from declared, rushd;
$$;


-- =====================================================================
-- 4) CANCEL AN UNSIGNED ACCEPTANCE (borrower)
-- =====================================================================
create or replace function public.rushd_cancel_unsigned(p_agreement_id uuid)
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

  if v_agreement.status <> 'offer_accepted' then
    raise exception 'Only an acceptance that is not signed yet can be cancelled.';
  end if;

  update public.financing_agreements
  set status = 'cancelled',
      updated_at = now()
  where id = p_agreement_id;

  -- Frees the application so the bank may issue a new offer version.
  update public.financing_offers
  set status = 'cancelled'
  where id = v_agreement.offer_id;

  delete from public.financing_signing_codes where agreement_id = p_agreement_id;

  perform public.rushd_log_event(
    v_agreement.offer_id, v_agreement.id, v_agreement.borrower_id, v_agreement.lender_id,
    'borrower', 'agreement_cancelled',
    jsonb_build_object('accepted_at', v_agreement.kfs_accepted_at)
  );
end;
$$;


-- =====================================================================
-- 5a) REQUEST SIGNING CODE
--    Copy of rushd_request_signing_code() from
--    20261031120000_financing_journey.sql; only the NEW lines differ.
-- =====================================================================
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

  -- NEW: an acceptance not signed within unsigned_lapse_days has lapsed.
  -- (Raising undoes any change, so it is marked 'cancelled' by the next
  -- signing / offer / accept call for this borrower.)
  if v_agreement.kfs_accepted_at <= now() - make_interval(days => v_cfg.unsigned_lapse_days) then
    raise exception 'This acceptance has lapsed. Ask the bank for a new offer.';
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


-- =====================================================================
-- 5b) SIGN AGREEMENT
--    Copy of rushd_sign_agreement() from
--    20261031120000_financing_journey.sql; only the NEW lines differ.
-- =====================================================================
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

  -- NEW: a lapsed acceptance is marked 'cancelled' and refused. This
  -- function returns instead of raising, so the change is kept.
  if v_agreement.kfs_accepted_at <= now() - make_interval(days => v_cfg.unsigned_lapse_days) then
    perform public.rushd_lapse_unsigned(v_uid);

    return jsonb_build_object(
      'ok', false,
      'lapsed', true,
      'error', 'This acceptance has lapsed. Ask the bank for a new offer.',
      'attempts_left', 0
    );
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


-- =====================================================================
-- 6a) ISSUE OFFER
--    Copy of rushd_issue_offer() from 20261031160000_rushd_obligations.sql;
--    only the NEW lines differ (CHANGED marks are from 20261031160000).
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

  -- NEW: lapse the borrower's stale acceptances first, so a lapsed one
  -- does not block a new offer (it still looks like a live offer).
  perform public.rushd_lapse_unsigned(v_app.borrower_id);

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
-- 6b) ACCEPT OFFER
--    Copy of rushd_accept_offer() from 20261031160000_rushd_obligations.sql;
--    only the NEW lines differ (CHANGED marks are from 20261031160000).
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

  -- NEW: tidy up the borrower's lapsed acceptances (they are already not
  -- counted as debt by rushd_obligations_internal).
  perform public.rushd_lapse_unsigned(v_uid);

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
-- 7) PRIVILEGES
-- =====================================================================
revoke execute on function public.rushd_cancel_unsigned(uuid) from public, anon;
grant execute on function public.rushd_cancel_unsigned(uuid) to authenticated;

revoke execute on function public.rushd_lapse_unsigned(uuid)
  from public, anon, authenticated;

-- create or replace keeps the existing grants of the replaced functions.

commit;


-- =====================================================================
-- ROLLBACK (commented out)
-- =====================================================================
-- begin;
--
-- -- Restore the previous definitions by re-running, unchanged:
-- --   * rushd_obligations_internal(), rushd_issue_offer(), rushd_accept_offer()
-- --       from 20261031160000_rushd_obligations.sql
-- --   * rushd_request_signing_code(), rushd_sign_agreement()
-- --       from 20261031120000_financing_journey.sql
-- -- (they no longer call the functions below), then:
--
-- drop function if exists public.rushd_cancel_unsigned(uuid);
-- drop function if exists public.rushd_lapse_unsigned(uuid);
--
-- alter table public.rushd_settings
--   drop constraint if exists rushd_settings_unsigned_lapse_days_check,
--   drop column if exists unsigned_lapse_days;
--
-- commit;
