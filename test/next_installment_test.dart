import 'package:flutter_test/flutter_test.dart';
import 'package:loan_comparison/models/financing.dart';

/// 60 monthly installments due on the 30th from Nov 2026 to Oct 2031,
/// like a schedule built from a disbursement on 31/10/2026.
List<RepaymentInstallment> buildSchedule() => [
  for (var i = 1; i <= 60; i++)
    RepaymentInstallment(
      installmentNo: i,
      dueDate: DateTime(2026, 10 + i, 30),
      principalPart: 500,
      profitPart: 100,
      installment: 600,
      remainingBalance: 30000 - 500.0 * i,
    ),
];

void main() {
  final today = DateTime(2026, 10, 31, 15, 30);

  test('picks the first installment due from today, not the last', () {
    final next = nextInstallment(buildSchedule(), today);

    expect(next?.installmentNo, 1);
    expect(next?.dueDate, DateTime(2026, 11, 30));
  });

  test('does not depend on the order the rows arrive in', () {
    // The bug: the database returned the rows newest first (60, 59, ...).
    final reversed = buildSchedule().reversed.toList();

    expect(nextInstallment(reversed, today)?.installmentNo, 1);
  });

  test('an installment due today is still the next one', () {
    final dueToday = DateTime(2027, 1, 30, 23, 59);

    expect(nextInstallment(buildSchedule(), dueToday)?.installmentNo, 3);
  });

  test('skips installments already in the past', () {
    final later = DateTime(2027, 2, 1);

    expect(nextInstallment(buildSchedule(), later)?.installmentNo, 4);
  });

  test('returns null when every installment is in the past', () {
    final afterEnd = DateTime(2032, 1, 1);

    expect(nextInstallment(buildSchedule(), afterEnd), isNull);
  });

  test('returns null for an empty schedule', () {
    expect(nextInstallment(const [], today), isNull);
  });
}
