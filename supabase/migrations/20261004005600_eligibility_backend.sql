alter table public.loan_requests
add column if not exists monthly_installment numeric(12,2),
add column if not exists installment_ratio numeric(8,2),
add column if not exists dti_ratio numeric(8,2),
add column if not exists eligibility_classification text;

alter table public.loan_requests
drop constraint if exists loan_requests_monthly_installment_check,
drop constraint if exists loan_requests_installment_ratio_check,
drop constraint if exists loan_requests_dti_ratio_check,
drop constraint if exists loan_requests_eligibility_classification_check;

alter table public.loan_requests
add constraint loan_requests_monthly_installment_check
check (monthly_installment is null or monthly_installment >= 0),

add constraint loan_requests_installment_ratio_check
check (installment_ratio is null or installment_ratio >= 0),

add constraint loan_requests_dti_ratio_check
check (dti_ratio is null or dti_ratio >= 0),

add constraint loan_requests_eligibility_classification_check
check (
  eligibility_classification is null
  or eligibility_classification in (
    'Highly Suitable',
    'Suitable',
    'Moderately Suitable',
    'Not Suitable'
  )
);

create or replace function public.calculate_rushd_eligibility(
  p_monthly_income numeric,
  p_current_monthly_obligations numeric,
  p_loan_amount numeric,
  p_annual_interest_rate numeric,
  p_term_months integer
)
returns table (
  monthly_installment numeric,
  installment_ratio numeric,
  dti_ratio numeric,
  eligibility_score numeric,
  eligibility_classification text
)
language plpgsql
set search_path = ''
as $$
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
$$;

create or replace function public.set_loan_request_eligibility()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
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

  new.monthly_installment := v_monthly_installment;
  new.installment_ratio := v_installment_ratio;
  new.dti_ratio := v_dti_ratio;
  new.eligibility_score := v_eligibility_score;
  new.eligibility_classification := v_classification;

  return new;
end;
$$;

drop trigger if exists
  trg_set_loan_request_eligibility
on public.loan_requests;

create trigger trg_set_loan_request_eligibility
before insert
on public.loan_requests
for each row
execute function public.set_loan_request_eligibility();
