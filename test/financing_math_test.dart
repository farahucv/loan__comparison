import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:loan_comparison/services/financing_math.dart';

/// These cases use the same numbers you can run against the database
/// in the Supabase SQL editor, e.g.
///
///   select * from rushd_calc_financing(45000, 5, 'flat', 36, 450);
///   select * from rushd_calc_financing(10000, 12, 'reducing', 12, 0);
///   select * from rushd_schedule_rows(10000, 12, 'reducing', 12, '2026-01-31');
///   select rushd_admin_fee_cap(45000), rushd_admin_fee_cap(900000);
///
/// and the results must match.

/// Present value of [installment] paid for [n] months at monthly rate [r].
double presentValue(double installment, int n, double r) =>
    installment * (1 - pow(1 + r, -n)) / r;

void main() {
  group('flat rate: 45,000 at 5% for 36 months, fee 450', () {
    final quote = FinancingMath.quote(
      principal: 45000,
      annualProfitRate: 5,
      rateType: 'flat',
      termMonths: 36,
      adminFee: 450,
      startDate: DateTime(2026, 1, 15),
    );

    test('profit is 5% of the amount per year for 3 years', () {
      // 45,000 x 5% x 3 = 6,750
      expect(quote.totalProfit, 6750.00);
    });

    test('installment is (amount + profit) / 36', () {
      // 51,750 / 36 = 1,437.50
      expect(quote.monthlyInstallment, 1437.50);
    });

    test('total repayable is all installments + admin fee', () {
      // 51,750 + 450 = 52,200
      expect(quote.totalRepayable, 52200.00);
    });

    test('APR is the monthly IRR x 12 of the real cash flows', () {
      // A flat 5% costs much more than 5% a year: about 10%.
      expect(quote.apr, inInclusiveRange(9.9, 10.1));

      // Paying 1,437.50 x 36, valued at apr/12, equals the 44,550 received
      // (within SAR 5, because the APR is rounded to 0.01%).
      final monthly = quote.apr / 1200;
      expect(presentValue(1437.50, 36, monthly), closeTo(44550, 5));
    });
  });

  group('reducing rate: 10,000 at 12% for 12 months, no fee', () {
    final lines = FinancingMath.schedule(
      principal: 10000,
      annualProfitRate: 12,
      rateType: 'reducing',
      termMonths: 12,
      startDate: DateTime(2026, 1, 31),
    );

    final quote = FinancingMath.quote(
      principal: 10000,
      annualProfitRate: 12,
      rateType: 'reducing',
      termMonths: 12,
      adminFee: 0,
    );

    test('installment is the standard annuity payment', () {
      expect(quote.monthlyInstallment, 888.49);
    });

    test('APR equals the profit rate when there is no fee', () {
      expect(quote.apr, closeTo(12.00, 0.01));
    });

    test('first month profit is 1% of the full balance', () {
      expect(lines.first.profitPart, 100.00);
      expect(lines.first.principalPart, 788.49);
      expect(lines.first.remainingBalance, 9211.51);
    });

    test('principal parts add up to the amount and the balance ends at 0', () {
      final principalSum = lines.fold(0.0, (s, l) => s + l.principalPart);

      expect(FinancingMath.round2(principalSum), 10000.00);
      expect(lines.last.remainingBalance, 0);
    });

    test('total profit = all installments - amount', () {
      final installmentSum = lines.fold(0.0, (s, l) => s + l.installment);

      expect(
        quote.totalProfit,
        closeTo(FinancingMath.round2(installmentSum - 10000), 0.001),
      );
    });

    test('due dates are clamped to the end of the month like SQL', () {
      // 2026-01-31 + 1 month = 2026-02-28 (SQL make_interval behaviour)
      expect(lines.first.dueDate, DateTime(2026, 2, 28));
      expect(lines[1].dueDate, DateTime(2026, 3, 31));
      expect(lines.last.dueDate, DateTime(2027, 1, 31));
    });
  });

  group('edge cases', () {
    test('0% profit: installment is amount / term and APR is 0', () {
      final quote = FinancingMath.quote(
        principal: 12000,
        annualProfitRate: 0,
        rateType: 'reducing',
        termMonths: 12,
        adminFee: 0,
      );

      expect(quote.monthlyInstallment, 1000.00);
      expect(quote.totalProfit, 0);
      expect(quote.apr, 0);
    });

    test('flat: the last installment absorbs the profit rounding', () {
      // 10,000 x 7% x 7/12 = 408.33 profit; 408.33 / 7 = 58.333...
      final lines = FinancingMath.schedule(
        principal: 10000,
        annualProfitRate: 7,
        rateType: 'flat',
        termMonths: 7,
        startDate: DateTime(2026, 1, 1),
      );

      final profitSum = lines.fold(0.0, (s, l) => s + l.profitPart);

      expect(FinancingMath.round2(profitSum), 408.33);
      expect(lines.first.profitPart, 58.33);
      expect(lines.last.profitPart, 58.35);
      expect(lines.last.remainingBalance, 0);
    });

    test('an admin fee makes the APR higher than the profit rate', () {
      final quote = FinancingMath.quote(
        principal: 45000,
        annualProfitRate: 5,
        rateType: 'reducing',
        termMonths: 36,
        adminFee: 450,
      );

      expect(quote.apr, greaterThan(5));
    });

    test('admin fee cap is least(1% of the amount, SAR 5,000)', () {
      expect(FinancingMath.adminFeeCap(45000), 450.00);
      expect(FinancingMath.adminFeeCap(900000), 5000.00);
    });

    test('invalid input is refused like the SQL', () {
      expect(
        () => FinancingMath.quote(
          principal: 10000,
          annualProfitRate: 5,
          rateType: 'balloon',
          termMonths: 12,
          adminFee: 0,
        ),
        throwsArgumentError,
      );

      expect(
        () => FinancingMath.quote(
          principal: 10000,
          annualProfitRate: 5,
          rateType: 'flat',
          termMonths: 12,
          adminFee: 10000,
        ),
        throwsArgumentError,
      );
    });
  });
}
