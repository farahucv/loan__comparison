import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/financing.dart';
import '../services/error_messages.dart';
import '../services/financing_service.dart';
import '../services/loan_request_service.dart';
import '../services/money_format.dart';
import 'journey_ui.dart' show formatDateTime;
import 'lender_application_screen.dart';

/// Lender dashboard section: approved applications grouped by where they
/// are in the financing journey.
class FinancingPipelineSection extends StatefulWidget {
  const FinancingPipelineSection({super.key});

  @override
  State<FinancingPipelineSection> createState() =>
      _FinancingPipelineSectionState();
}

class _PipelineEntry {
  final LenderRequestData request;
  final FinancingOffer? offer;
  final FinancingAgreement? agreement;
  final LenderStage stage;

  _PipelineEntry(this.request, this.offer, this.agreement)
    : stage = lenderStageFor(offer, agreement);
}

const Map<LenderStage, (String, IconData, Color)> _stageInfo = {
  LenderStage.awaitingOffer: (
    'Awaiting offer',
    Icons.hourglass_top,
    Colors.lightBlueAccent,
  ),
  LenderStage.offerIssued: (
    'Offer issued',
    Icons.local_offer_outlined,
    Colors.lightBlueAccent,
  ),
  LenderStage.awaitingSignature: (
    'Awaiting signature',
    Icons.draw_outlined,
    Colors.amberAccent,
  ),
  LenderStage.coolingOff: (
    'Cooling-off',
    Icons.shield_outlined,
    Colors.amberAccent,
  ),
  LenderStage.readyToRelease: (
    'Ready to release',
    Icons.account_balance_wallet_outlined,
    Colors.greenAccent,
  ),
  LenderStage.active: ('Active', Icons.verified, Colors.greenAccent),
};

class _FinancingPipelineSectionState extends State<FinancingPipelineSection> {
  final FinancingService _financing = FinancingService();
  final LoanRequestService _requests = LoanRequestService();

  List<_PipelineEntry> entries = [];
  LenderStage selected = LenderStage.awaitingOffer;
  bool _picked = false;

  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final pipeline = await _financing.getLenderPipeline();
      final requests = await _requests.getLenderRequests();

      final loaded = [
        for (final r in requests)
          if (pipeline.containsKey(r.id))
            _PipelineEntry(r, pipeline[r.id]!.offer, pipeline[r.id]!.agreement),
      ];

      if (!mounted) return;

      setState(() {
        entries = loaded;
        isLoading = false;

        // Open on the first stage that needs work, until the lender picks one.
        if (!_picked) {
          selected = LenderStage.values.firstWhere(
            (s) => loaded.any((e) => e.stage == s),
            orElse: () => LenderStage.awaitingOffer,
          );
        }
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = friendlyError(error);
      });
    }
  }

  Future<void> _open(_PipelineEntry entry) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LenderApplicationScreen(request: entry.request),
      ),
    );

    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppSettings.instance.tr;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.view_kanban_outlined, color: Colors.lightBlue),
              const SizedBox(width: 10),
              Expanded(
                child: AppText(
                  'Financing pipeline',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                tooltip: tr('Refresh'),
                onPressed: isLoading ? null : _load,
                icon: const Icon(Icons.refresh, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 4),
          AppText(
            'Approved applications by financing stage. Open one to issue an offer or release funds.',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 16),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (errorMessage != null)
            _message(
              Icons.error_outline,
              Colors.redAccent,
              'Unable to load the pipeline.',
              errorMessage!,
              retry: true,
            )
          else if (entries.isEmpty)
            _message(
              Icons.inbox_outlined,
              Colors.lightBlue,
              'No approved applications yet.',
              'Applications you approve in Review Requests will appear here.',
            )
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final stage in LenderStage.values)
                  ChoiceChip(
                    selected: selected == stage,
                    selectedColor: _stageInfo[stage]!.$3.withValues(alpha: .25),
                    backgroundColor: Colors.white.withValues(alpha: .06),
                    side: BorderSide(
                      color: _stageInfo[stage]!.$3.withValues(alpha: .4),
                    ),
                    avatar: Icon(
                      _stageInfo[stage]!.$2,
                      size: 16,
                      color: _stageInfo[stage]!.$3,
                    ),
                    label: Text(
                      '${tr(_stageInfo[stage]!.$1)} (${entries.where((e) => e.stage == stage).length})',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    onSelected: (_) => setState(() {
                      selected = stage;
                      _picked = true;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            ..._rows(),
          ],
        ],
      ),
    );
  }

  List<Widget> _rows() {
    final list = entries.where((e) => e.stage == selected).toList();

    if (list.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: AppText(
              'Nothing in this stage.',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        ),
      ];
    }

    return [
      for (final e in list)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () => _open(e),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .05),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(_stageInfo[e.stage]!.$2, color: _stageInfo[e.stage]!.$3),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.request.borrowerName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _detail(e),
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? Icons.chevron_left
                        : Icons.chevron_right,
                    color: Colors.white54,
                  ),
                ],
              ),
            ),
          ),
        ),
    ];
  }

  String _detail(_PipelineEntry e) {
    final tr = AppSettings.instance.tr;
    final amount = formatSar(e.request.requestedAmount, decimals: 0);
    final o = e.offer;
    final a = e.agreement;

    switch (e.stage) {
      case LenderStage.awaitingOffer:
        if (a?.status == 'withdrawn' || a?.status == 'cancelled') {
          return '$amount • ${tr('Borrower withdrew')}';
        }
        if (o?.effectiveStatus == 'offer_declined') {
          return '$amount • ${tr('Offer declined')}';
        }
        if (o?.effectiveStatus == 'offer_expired') {
          return '$amount • ${tr('Offer expired')}';
        }
        return '$amount • ${tr(e.request.loanType)}';
      case LenderStage.offerIssued:
        return '${formatSar(o!.monthlyInstallment)} / ${tr('month')} • ${tr('Valid until')} ${formatDateTime(o.validUntil)}';
      case LenderStage.awaitingSignature:
        return '${a!.referenceNo} • ${formatSar(o!.monthlyInstallment)} / ${tr('month')}';
      case LenderStage.coolingOff:
        return '${a!.referenceNo} • ${tr('Ends')} ${formatDateTime(a.coolingOffEndsAt)}';
      case LenderStage.readyToRelease:
        return '${a!.referenceNo} • ${formatSar(o!.principal - o.adminFee)} ${tr('to release')}';
      case LenderStage.active:
        return '${a!.referenceNo} • ${tr('Released on')} ${formatDateTime(a.disbursedAt)}';
    }
  }

  Widget _message(
    IconData icon,
    Color color,
    String title,
    String body, {
    bool retry = false,
  }) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Icon(icon, color: color, size: 38),
          const SizedBox(height: 8),
          AppText(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          AppText(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          if (retry) ...[
            const SizedBox(height: 10),
            ElevatedButton(onPressed: _load, child: AppText('Try Again')),
          ],
        ],
      ),
    );
  }
}
