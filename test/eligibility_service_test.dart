import 'package:flutter_test/flutter_test.dart';
import 'package:loan_comparison/services/eligibility_service.dart';

void main() {
  late EligibilityService service;

  setUp(() {
    service = EligibilityService();
  });

  test('calculates PMT, ratios, score and classification correctly', () {
    final result = service.calculate(
      monthlyIncome: 10000,
      currentMonthlyObligations: 1000,
      loanAmount: 100000,
      annualInterestRate: 5,
      termMonths: 60,
    );

    expect(result.monthlyInstallment, closeTo(1887.12, 0.01));

    expect(result.installmentRatio, closeTo(18.87, 0.01));

    expect(result.dtiRatio, closeTo(28.87, 0.01));

    expect(result.finalScore, closeTo(88.0, 0.01));

    expect(result.classification, 'Highly Suitable');
  });

  test('handles zero interest rate correctly', () {
    final result = service.calculate(
      monthlyIncome: 10000,
      currentMonthlyObligations: 0,
      loanAmount: 12000,
      annualInterestRate: 0,
      termMonths: 12,
    );

    expect(result.monthlyInstallment, closeTo(1000, 0.01));

    expect(result.installmentRatio, closeTo(10, 0.01));

    expect(result.dtiRatio, closeTo(10, 0.01));

    expect(result.finalScore, closeTo(100, 0.01));

    expect(result.classification, 'Highly Suitable');
  });

  test('returns Moderately Suitable for high financial ratios', () {
    final result = service.calculate(
      monthlyIncome: 3000,
      currentMonthlyObligations: 2000,
      loanAmount: 100000,
      annualInterestRate: 9,
      termMonths: 144,
    );

    expect(result.finalScore, closeTo(40, 0.01));

    expect(result.classification, 'Moderately Suitable');
  });

  test('throws error when monthly income is zero', () {
    expect(
      () => service.calculate(
        monthlyIncome: 0,
        currentMonthlyObligations: 0,
        loanAmount: 100000,
        annualInterestRate: 5,
        termMonths: 60,
      ),
      throwsArgumentError,
    );
  });

  test('throws error when loan amount is zero', () {
    expect(
      () => service.calculate(
        monthlyIncome: 10000,
        currentMonthlyObligations: 0,
        loanAmount: 0,
        annualInterestRate: 5,
        termMonths: 60,
      ),
      throwsArgumentError,
    );
  });
}
