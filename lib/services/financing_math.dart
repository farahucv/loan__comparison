import 'dart:math';

/// Dart copy of the financing maths in
/// supabase/migrations/20261031120000_financing_journey.sql
/// (rushd_schedule_rows, rushd_calc_apr, rushd_calc_financing,
/// rushd_admin_fee_cap).
///
/// The database is the source of truth: saved offers always use the SQL
/// numbers. This copy is only for previews (e.g. the estimated schedule
/// before signing) and is kept in line with the SQL by unit tests.

class ScheduleLine {
  final int installmentNo;
  final DateTime dueDate;
  final double principalPart;
  final double profitPart;
  final double installment;
  final double remainingBalance;

  const ScheduleLine({
    required this.installmentNo,
    required this.dueDate,
    required this.principalPart,
    required this.profitPart,
    required this.installment,
    required this.remainingBalance,
  });
}

class FinancingQuote {
  final double monthlyInstallment;
  final double totalProfit;
  final double totalRepayable;
  final double apr;

  const FinancingQuote({
    required this.monthlyInstallment,
    required this.totalProfit,
    required this.totalRepayable,
    required this.apr,
  });
}

class FinancingMath {
  /// Same as SQL round(x, 2): half away from zero.
  static double round2(double value) {
    final scaled = value * 100;
    final nudge = scaled >= 0 ? 1e-7 : -1e-7;

    return (scaled + nudge).round() / 100;
  }

  /// rushd_admin_fee_cap: least(pct % of principal, max).
  static double adminFeeCap(
    double principal, {
    double pct = 1,
    double max = 5000,
  }) {
    return round2(min(principal * pct / 100, max));
  }

  /// Same as SQL  date + make_interval(months => n):
  /// the day is clamped to the end of the month (Jan 31 + 1 month = Feb 28).
  static DateTime addMonths(DateTime date, int months) {
    final firstOfTarget = DateTime(date.year, date.month + months, 1);
    final lastDay = DateTime(
      firstOfTarget.year,
      firstOfTarget.month + 1,
      0,
    ).day;

    return DateTime(
      firstOfTarget.year,
      firstOfTarget.month,
      min(date.day, lastDay),
    );
  }

  /// rushd_schedule_rows. The last installment absorbs the rounding so the
  /// balance ends at exactly 0.
  static List<ScheduleLine> schedule({
    required double principal,
    required double annualProfitRate,
    required String rateType,
    required int termMonths,
    required DateTime startDate,
  }) {
    if (principal <= 0) {
      throw ArgumentError('The amount must be greater than zero');
    }

    if (annualProfitRate < 0) {
      throw ArgumentError('The profit rate cannot be negative');
    }

    if (termMonths <= 0) {
      throw ArgumentError('The term must be greater than zero');
    }

    final monthlyRate = annualProfitRate / 1200;

    double installment;
    double flatProfit = 0;
    double flatProfitPart = 0;

    if (rateType == 'flat') {
      flatProfit = round2(principal * annualProfitRate / 100 * termMonths / 12);
      installment = round2((principal + flatProfit) / termMonths);
      flatProfitPart = round2(flatProfit / termMonths);
    } else if (rateType == 'reducing') {
      installment = monthlyRate == 0
          ? round2(principal / termMonths)
          : round2(
              principal * monthlyRate / (1 - pow(1 + monthlyRate, -termMonths)),
            );
    } else {
      throw ArgumentError('Rate type must be flat or reducing');
    }

    final lines = <ScheduleLine>[];
    var balance = principal;
    var profitSoFar = 0.0;

    for (var k = 1; k <= termMonths; k++) {
      final last = k == termMonths;

      final profitPart = rateType == 'flat'
          ? (last ? round2(flatProfit - profitSoFar) : flatProfitPart)
          : round2(balance * monthlyRate);

      final principalPart = last ? balance : round2(installment - profitPart);

      balance = round2(balance - principalPart);
      profitSoFar = round2(profitSoFar + profitPart);

      lines.add(
        ScheduleLine(
          installmentNo: k,
          dueDate: addMonths(startDate, k),
          principalPart: principalPart,
          profitPart: profitPart,
          installment: round2(principalPart + profitPart),
          remainingBalance: balance,
        ),
      );
    }

    return lines;
  }

  /// rushd_calc_apr: monthly IRR of the cash flows x 12, as a percent.
  /// The borrower receives [netAmount] today and pays [installment] every
  /// month for [termMonths]. Solved by bisection, like the SQL.
  static double apr({
    required double netAmount,
    required double installment,
    required int termMonths,
  }) {
    if (netAmount <= 0 || installment <= 0 || termMonths <= 0) {
      throw ArgumentError('The APR cannot be calculated for these values');
    }

    if (installment * termMonths <= netAmount) return 0;

    var low = 0.0;
    var high = 1.0;
    var mid = 0.0;

    for (var k = 0; k < 100; k++) {
      mid = (low + high) / 2;
      final presentValue = installment * (1 - pow(1 + mid, -termMonths)) / mid;

      if (presentValue > netAmount) {
        low = mid;
      } else {
        high = mid;
      }
    }

    return round2(mid * 12 * 100);
  }

  /// rushd_calc_financing.
  static FinancingQuote quote({
    required double principal,
    required double annualProfitRate,
    required String rateType,
    required int termMonths,
    required double adminFee,
    DateTime? startDate,
  }) {
    if (adminFee < 0) {
      throw ArgumentError('The admin fee cannot be negative');
    }

    if (adminFee >= principal) {
      throw ArgumentError('The admin fee must be less than the amount');
    }

    final lines = schedule(
      principal: principal,
      annualProfitRate: annualProfitRate,
      rateType: rateType,
      termMonths: termMonths,
      startDate: startDate ?? DateTime.now(),
    );

    final installment = lines.first.installment;
    final totalProfit = round2(lines.fold(0.0, (sum, l) => sum + l.profitPart));
    final totalInstallments = round2(
      lines.fold(0.0, (sum, l) => sum + l.installment),
    );

    return FinancingQuote(
      monthlyInstallment: installment,
      totalProfit: totalProfit,
      totalRepayable: round2(totalInstallments + adminFee),
      apr: apr(
        netAmount: principal - adminFee,
        installment: installment,
        termMonths: termMonths,
      ),
    );
  }
}
