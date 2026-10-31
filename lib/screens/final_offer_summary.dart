import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/financing.dart';
import '../services/money_format.dart';
import 'borrower_ui.dart';

// Shown on request cards (borrower and lender) once the bank has issued a
// final offer, so the card stops showing the preliminary request numbers.

/// The offer counts as the final one unless it was declined, expired or
/// cancelled (then the request falls back to its original numbers).
bool isFinalOffer(FinancingOffer? offer) =>
    offer != null &&
    !const {
      'offer_declined',
      'offer_expired',
      'cancelled',
    }.contains(offer.effectiveStatus);

/// "Requested SAR 500,000 • Approved SAR 349,000" when they differ,
/// otherwise just the requested amount.
String requestedApprovedLine(double requested, FinancingOffer? offer) {
  final tr = AppSettings.instance.tr;
  final requestedText = formatSar(requested, decimals: 0);

  if (!isFinalOffer(offer) || offer!.principal == requested) {
    return requestedText;
  }

  return '${tr('Requested')} $requestedText • ${tr('Approved')} ${formatSar(offer.principal, decimals: 0)}';
}

class FinalOfferSummary extends StatelessWidget {
  final FinancingOffer offer;
  final double requestedAmount;

  const FinalOfferSummary({
    super.key,
    required this.offer,
    required this.requestedAmount,
  });

  @override
  Widget build(BuildContext context) {
    final tr = AppSettings.instance.tr;
    final counterOffer = offer.principal < requestedAmount;

    Widget item(String label, String value) => Container(
      constraints: const BoxConstraints(minWidth: 120),
      padding: const EdgeInsets.all(12),
      decoration: panel(radius: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppText(label, style: white(9, c: Colors.white38)),
          const SizedBox(height: 3),
          Text(value, style: white(12, w: FontWeight.bold)),
        ],
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.greenAccent.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: .3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_outlined,
                color: Colors.greenAccent,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppText(
                  'Final offer',
                  style: white(14, w: FontWeight.bold),
                ),
              ),
              if (counterOffer)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: AppText(
                    'Counter-offer',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              item('Approved amount', formatSar(offer.principal, decimals: 0)),
              item('Monthly installment', formatSar(offer.monthlyInstallment)),
              item('Term', '${offer.termMonths} ${tr('months')}'),
              item('APR', formatPercent(offer.apr)),
              item('Total DBR', formatPercent(offer.totalDbr)),
            ],
          ),
        ],
      ),
    );
  }
}

/// The preliminary eligibility numbers, collapsed under
/// "Initial estimate (at request time)". The stored values are unchanged.
class InitialEstimateSection extends StatelessWidget {
  final Widget child;
  final bool initiallyExpanded;

  const InitialEstimateSection({
    super.key,
    required this.child,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        iconColor: kCyan,
        collapsedIconColor: kCyan,
        title: AppText(
          'Initial estimate (at request time)',
          style: white(13, w: FontWeight.bold),
        ),
        children: [child],
      ),
    );
  }
}
