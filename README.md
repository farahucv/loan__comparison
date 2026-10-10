# Rushd — Loan Comparison

Rushd is a Flutter application for comparing loan offers and assessing affordability. Borrowers can explore financing options and track requests, while lenders can manage offers and review applications. Supabase provides authentication and database access.

## Features

| Borrowers | Lenders |
| --- | --- |
| Register, sign in, and manage a profile | Register with a bank affiliation and sign in |
| Choose personal, business, or investment loans | Create, edit, and delete loan offers |
| Enter income, debts, expenses, and the desired amount | Configure rates, amount limits, terms, and contact details |
| Compare active offers and view affordability metrics | View offer and request statistics |
| Submit requests and track their status | Approve or reject requests with an optional reason |

The interface includes English and Arabic language settings, right-to-left layout support, and light and dark themes.

## Technology

- **Frontend:** Flutter and Dart with Material widgets.
- **Backend:** Supabase Auth and PostgreSQL through `supabase_flutter`.
- **State:** `ChangeNotifier` models for settings and local borrower state.
- **Testing:** `flutter_test` for eligibility calculations.

Platform scaffolding is included for web, Android, iOS, Linux, macOS, and Windows. This does not establish that every platform has been tested; the instructions below focus on web development.

## Getting Started

### Prerequisites

- Flutter **3.44.0 or later**, with a Dart SDK compatible with **`^3.12.2`**.
- Git and Chrome or Chromium for web development.
- A Supabase project with the required schema, authentication configuration, and database policies.

Check your toolchain and install the locked dependencies:

```bash
flutter --version
flutter doctor

git clone https://github.com/farahucv/loan__comparison.git
cd loan__comparison
flutter pub get --enforce-lockfile
```

### Configure Supabase

[`lib/main.dart`](lib/main.dart) currently contains the Supabase project URL and publishable client key. To connect your own backend, replace these values in `Supabase.initialize(...)`. The application does not currently read them from `.env` files or `--dart-define` values.

Use a publishable client key in the application. Never embed a service-role key in client code. Enforce database access through appropriate row-level security policies.

| Required table | Purpose |
| --- | --- |
| `profiles` | User identity, role, contact information, and bank affiliation |
| `borrower_profiles` | Borrower financial information |
| `loan_offers` | Rates, amount limits, repayment terms, and offer availability |
| `loan_requests` | Requests, review status, and calculated eligibility |

Registration sends user metadata to Supabase Auth. Your backend must create corresponding profile records. Configure email/password authentication and profile creation; when email confirmation is enabled, users must confirm their email before signing in.

Apply [`20261004005600_eligibility_backend.sql`](supabase/migrations/20261004005600_eligibility_backend.sql) through your Supabase migration workflow or SQL Editor **after the required tables and columns exist**. It adds eligibility fields, a calculation function, and a trigger that calculates eligibility before a request is inserted.

**The migration is not a complete backend bootstrap.** Base table definitions, profile-creation setup, and row-level security policies are not included, so the repository alone cannot recreate the full backend.

### Run

From the repository root:

```bash
flutter run -d chrome
```

For a cloud machine without a graphical browser:

```bash
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
```

Use your hosting environment's supported browser access mechanism. Restart the development server when a new cloud machine is created.

## Eligibility Model

[`EligibilityService`](lib/services/eligibility_service.dart) calculates a fixed-rate monthly installment, the installment-to-income ratio, and the debt-to-income (DTI) ratio:

```text
Monthly rate = annual interest rate / 100 / 12
Installment = principal × rate × (1 + rate)^months / ((1 + rate)^months − 1)
Installment ratio (%) = installment / monthly income × 100
DTI ratio (%) = (existing monthly obligations + installment) / monthly income × 100
```

For zero interest, the installment is the principal divided by the term in months. Each factor receives 100, 70, or 40 points:

| Factor | Weight | 100 points | 70 points | 40 points |
| --- | --- | --- | --- | --- |
| DTI ratio | 45% | Below 30% | 30–50% | Above 50% |
| Annual interest rate | 25% | Below 4% | 4–7% | Above 7% |
