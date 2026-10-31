import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/financing.dart';
import '../services/error_messages.dart';
import '../services/financing_service.dart';
import '../services/money_format.dart';
import 'borrower_ui.dart';

// Rushd financings count as debt in every check (a simulated credit
// bureau). These helpers show that to the borrower and the lender.

/// "Rushd financing: SAR 4,200.00/month (1 active, added automatically)"
String rushdObligationsLine(BorrowerObligations o) {
  final amount = formatSar(o.rushdInstallments);

  return AppSettings.instance.isArabic
      ? 'التزامات تمويل رشد: $amount شهريًا (${o.rushdCount} نشط، تُضاف تلقائياً)'
      : 'Rushd financing: $amount/month (${o.rushdCount} active, added automatically)';
}

/// Loads the obligations; falls back to the declared debts if the
/// database function is not reachable (e.g. migration not run yet).
Future<BorrowerObligations> loadObligations(
  double declaredDebts, {
  String? borrowerId,
}) async {
  try {
    return await FinancingService().getObligations(borrowerId);
  } catch (_) {
    return BorrowerObligations.declaredOnly(declaredDebts);
  }
}

/// Small line under the existing-debts value / field.
class RushdObligationsNote extends StatelessWidget {
  final BorrowerObligations obligations;

  const RushdObligationsNote(this.obligations, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.link, size: 14, color: kCyan),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            rushdObligationsLine(obligations),
            style: white(10, c: kCyan),
          ),
        ),
      ],
    );
  }
}

/// Lender view: "Credit bureau summary (simulated)".
class CreditBureauSummary extends StatelessWidget {
  final BorrowerObligations obligations;

  const CreditBureauSummary(this.obligations, {super.key});

  @override
  Widget build(BuildContext context) {
    Widget row(String label, String value, {bool strong = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: AppText(label, style: white(11, c: Colors.white60)),
          ),
          Text(
            value,
            style: white(
              strong ? 13 : 12,
              w: strong ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.purpleAccent.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purpleAccent.withValues(alpha: .3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.fact_check_outlined,
                color: Colors.purpleAccent,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppText(
                  'Credit bureau summary (simulated)',
                  style: white(13, w: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          row('Active Rushd financings', '${obligations.rushdCount}'),
          row(
            'Rushd monthly installments',
            formatSar(obligations.rushdInstallments),
          ),
          row('Declared debts', formatSar(obligations.declaredDebts)),
          const Divider(color: Colors.white12, height: 14),
          row(
            'Total monthly obligations',
            formatSar(obligations.totalObligations),
            strong: true,
          ),
        ],
      ),
    );
  }
}

/// Loads and shows the credit bureau summary for one borrower
/// (lender's Review Requests card).
class CreditBureauSummaryLoader extends StatefulWidget {
  final String borrowerId;

  const CreditBureauSummaryLoader({super.key, required this.borrowerId});

  @override
  State<CreditBureauSummaryLoader> createState() =>
      _CreditBureauSummaryLoaderState();
}

class _CreditBureauSummaryLoaderState extends State<CreditBureauSummaryLoader> {
  BorrowerObligations? obligations;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final o = await FinancingService().getObligations(widget.borrowerId);

      if (mounted) setState(() => obligations = o);
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Text(error!, style: white(11, c: Colors.orangeAccent));
    }

    if (obligations == null) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }

    return CreditBureauSummary(obligations!);
  }
}
