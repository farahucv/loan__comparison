import 'dart:math';

class EligibilityResult {
  final double monthlyInstallment;
  final double installmentRatio;
  final double dtiRatio;

  final double dtiScore;
  final double interestRateScore;
  final double repaymentPeriodScore;
  final double installmentRatioScore;

  final double finalScore;
  final String classification;

  const EligibilityResult({
    required this.monthlyInstallment,
    required this.installmentRatio,
    required this.dtiRatio,
    required this.dtiScore,
    required this.interestRateScore,
    required this.repaymentPeriodScore,
    required this.installmentRatioScore,
    required this.finalScore,
    required this.classification,
  });
}

class EligibilityService {
  EligibilityResult calculate({
    required double monthlyIncome,
    required double currentMonthlyObligations,
    required double loanAmount,
    required double annualInterestRate,
    required int termMonths,
  }) {
    if (monthlyIncome <= 0) {
      throw ArgumentError('Monthly income must be greater than zero.');
    }

    if (currentMonthlyObligations < 0) {
      throw ArgumentError('Current monthly obligations cannot be negative.');
    }

    if (loanAmount <= 0) {
      throw ArgumentError('Loan amount must be greater than zero.');
    }

    if (annualInterestRate < 0) {
      throw ArgumentError('Interest rate cannot be negative.');
    }

    if (termMonths <= 0) {
      throw ArgumentError('Repayment period must be greater than zero.');
    }

    final monthlyRate = annualInterestRate / 100 / 12;

    final double monthlyInstallment;

    if (monthlyRate == 0) {
      monthlyInstallment = loanAmount / termMonths;
    } else {
      monthlyInstallment =
          loanAmount *
          monthlyRate *
          pow(1 + monthlyRate, termMonths) /
          (pow(1 + monthlyRate, termMonths) - 1);
    }

    final installmentRatio = (monthlyInstallment / monthlyIncome) * 100;

    final dtiRatio =
        ((currentMonthlyObligations + monthlyInstallment) / monthlyIncome) *
        100;

    final dtiScore = _calculateDtiScore(dtiRatio);

    final interestRateScore = _calculateInterestRateScore(annualInterestRate);

    final repaymentPeriodScore = _calculateRepaymentPeriodScore(termMonths);

    final installmentRatioScore = _calculateInstallmentRatioScore(
      installmentRatio,
    );

    final finalScore =
        (dtiScore * 0.45) +
        (interestRateScore * 0.25) +
        (repaymentPeriodScore * 0.15) +
        (installmentRatioScore * 0.15);

    final classification = _classify(finalScore);

    return EligibilityResult(
      monthlyInstallment: monthlyInstallment,
      installmentRatio: installmentRatio,
      dtiRatio: dtiRatio,
      dtiScore: dtiScore,
      interestRateScore: interestRateScore,
      repaymentPeriodScore: repaymentPeriodScore,
      installmentRatioScore: installmentRatioScore,
      finalScore: finalScore,
      classification: classification,
    );
  }

  double _calculateDtiScore(double dti) {
    if (dti < 30) {
      return 100;
    }

    if (dti <= 50) {
      return 70;
    }

    return 40;
  }

  double _calculateInterestRateScore(double rate) {
    if (rate < 4) {
      return 100;
    }

    if (rate <= 7) {
      return 70;
    }

    return 40;
  }

  double _calculateRepaymentPeriodScore(int termMonths) {
    if (termMonths < 60) {
      return 100;
    }

    if (termMonths <= 120) {
      return 70;
    }

    return 40;
  }

  double _calculateInstallmentRatioScore(double ratio) {
    if (ratio < 20) {
      return 100;
    }

    if (ratio <= 35) {
      return 70;
    }

    return 40;
  }

  String _classify(double score) {
    if (score >= 80) {
      return 'Highly Suitable';
    }

    if (score >= 60) {
      return 'Suitable';
    }

    if (score >= 40) {
      return 'Moderately Suitable';
    }

    return 'Not Suitable';
  }
}
