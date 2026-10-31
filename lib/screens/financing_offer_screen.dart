import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/financing.dart';
import '../services/error_messages.dart';
import '../services/financing_math.dart';
import '../services/financing_service.dart';
import '../services/loan_request_service.dart';
import '../services/money_format.dart';
import 'borrower_ui.dart';
import 'financing_status_screen.dart';
import 'journey_ui.dart';
import 'sign_agreement_screen.dart';

/// "Your final offer": the monthly installment, the Key Facts Statement,
/// the repayment schedule, and accept / decline.
class FinancingOfferScreen extends StatefulWidget {
  final BorrowerRequestData request;
  final String offerId;

  const FinancingOfferScreen({
    super.key,
    required this.request,
    required this.offerId,
  });

  @override
  State<FinancingOfferScreen> createState() => _FinancingOfferScreenState();
}

class _FinancingOfferScreenState extends State<FinancingOfferScreen> {
  final FinancingService _service = FinancingService();

  FinancingOffer? offer;
  FinancingSettings settings = const FinancingSettings();
  List<ScheduleLine> schedule = [];

  bool isLoading = true;
  bool isBusy = false;
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
      final loaded = await _service.getOffer(widget.offerId);

      FinancingSettings loadedSettings = const FinancingSettings();

      try {
        loadedSettings = await _service.getSettings();
      } catch (_) {
        // Defaults are fine for display.
      }

      if (!mounted) return;

      setState(() {
        offer = loaded;
        settings = loadedSettings;
        schedule = loaded == null
            ? []
            : FinancingMath.schedule(
                principal: loaded.principal,
                annualProfitRate: loaded.annualProfitRate,
                rateType: loaded.rateType,
                termMonths: loaded.termMonths,
                startDate: DateTime.now(),
              );
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = friendlyError(error);
      });
    }
  }

  // =========================
  // ACTIONS
  // =========================

  Future<void> _accept() async {
    final consents = await showModalBottomSheet<Map<String, bool>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppSettings.instance.isDark
          ? const Color(0xff1E0B36)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => const _ConsentsSheet(),
    );

    if (consents == null || !mounted) return;

    setState(() => isBusy = true);

    try {
      final agreement = await _service.acceptOffer(
        offerId: widget.offerId,
        consents: consents,
      );

      if (!mounted) return;

      showInfo(context, 'Offer accepted. Please sign the agreement.');

      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SignAgreementScreen(
            request: widget.request,
            agreementId: agreement.id,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      showError(context, friendlyError(error));
      await _load();
    } finally {
      if (mounted) setState(() => isBusy = false);
    }
  }

  Future<void> _decline() async {
    final controller = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: AppText('Decline offer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              'Please tell the bank why you are declining this offer.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: tr('Reason'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: AppText('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final text = controller.text.trim();

              if (text.isEmpty) {
                showError(dialogContext, 'Please write a reason first.');
                return;
              }

              Navigator.pop(dialogContext, text);
            },
            child: AppText('Decline offer'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (reason == null || !mounted) return;

    setState(() => isBusy = true);

    try {
      await _service.declineOffer(offerId: widget.offerId, reason: reason);

      if (!mounted) return;

      showInfo(context, 'You declined the offer.');
      await _load();
    } catch (error) {
      if (mounted) showError(context, friendlyError(error));
    } finally {
      if (mounted) setState(() => isBusy = false);
    }
  }

  Future<void> _openAgreement() async {
    setState(() => isBusy = true);

    try {
      final agreement = await _service.getAgreementForOffer(widget.offerId);

      if (!mounted) return;

      if (agreement == null) {
        showError(context, 'Agreement not found.');
        return;
      }

      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SignAgreementScreen(
            request: widget.request,
            agreementId: agreement.id,
          ),
        ),
      );
    } catch (error) {
      if (mounted) showError(context, friendlyError(error));
    } finally {
      if (mounted) setState(() => isBusy = false);
    }
  }

  // =========================
  // UI
  // =========================

  @override
  Widget build(BuildContext context) {
    return BorrowerShell(
      active: 2,
      child: JourneyPage(
        children: [
          JourneyHeader(
            title: 'Your final offer',
            subtitle:
                '${tr(widget.request.bankName)} • ${widget.request.offerName}',
            onRefresh: _load,
          ),
          if (isLoading)
            const LoadingView()
          else if (errorMessage != null)
            ErrorView(
              title: 'Unable to load the offer.',
              message: errorMessage!,
              onRetry: _load,
            )
          else if (offer == null)
            const EmptyView(
              icon: Icons.local_offer_outlined,
              title: 'No offer yet',
              message:
                  'The bank has not issued a financing offer for this application yet.',
            )
          else
            ..._content(offer!),
        ],
      ),
    );
  }

  List<Widget> _content(FinancingOffer o) {
    final status = o.effectiveStatus;

    return [
      if (status != 'offer_issued') ...[
        _closedBanner(status),
        const SizedBox(height: 16),
      ],
      if (o.principal < widget.request.requestedAmount) ...[
        _counterOfferBanner(o),
        const SizedBox(height: 16),
      ],
      _installmentHero(o),
      const SizedBox(height: 16),
      _keyFacts(o),
      const SizedBox(height: 16),
      _scheduleCard(),
      const SizedBox(height: 16),
      const DemoNote(
        'This is a simulated offer for a graduation project. No real financing is provided.',
      ),
      if (o.isOpen) ...[const SizedBox(height: 20), _actions()],
    ];
  }

  /// The bank approved less than the borrower asked for (a counter-offer).
  Widget _counterOfferBanner(FinancingOffer o) {
    final approved = formatSar(o.principal, decimals: 0);
    final requested = formatSar(widget.request.requestedAmount, decimals: 0);

    final message = AppSettings.instance.isArabic
        ? 'وافق البنك على $approved بدلًا من $requested التي طلبتها، للحفاظ على التزاماتك الشهرية ضمن الحد المسموح.'
        : 'The bank approved $approved instead of the $requested you requested, to keep your monthly obligations within the allowed limit.';

    return SectionCard(
      accent: Colors.amber,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Colors.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  'Counter-offer',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(message, style: white(12, c: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _closedBanner(String status) {
    final (color, title, message) = switch (status) {
      'offer_accepted' => (
        Colors.greenAccent,
        'Offer accepted',
        'You accepted this offer. Continue to sign the agreement.',
      ),
      'offer_declined' => (
        Colors.white54,
        'Offer declined',
        'You declined this offer. The bank may send you a new one.',
      ),
      'offer_expired' => (
        Colors.orangeAccent,
        'Offer expired',
        'This offer is no longer valid. Ask the bank for a new offer.',
      ),
      _ => (Colors.white54, 'Offer closed', 'This offer is no longer open.'),
    };

    return SectionCard(
      accent: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppText(
            title,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          AppText(message, style: white(12, c: Colors.white70)),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: status == 'offer_accepted'
                ? ElevatedButton(
                    onPressed: isBusy ? null : _openAgreement,
                    child: AppText('Continue'),
                  )
                : OutlinedButton(
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            FinancingStatusScreen(request: widget.request),
                      ),
                    ),
                    child: AppText('View progress'),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _installmentHero(FinancingOffer o) {
    final narrow = MediaQuery.sizeOf(context).width < 600;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff2F74F5), Color(0xff6A3DE8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            'Monthly installment',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              formatSar(o.monthlyInstallment),
              style: TextStyle(
                color: Colors.white,
                fontSize: narrow ? 34 : 44,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${tr('for')} ${o.termMonths} ${tr('months')} • ${tr(o.rateType == 'flat' ? 'Flat rate' : 'Reducing balance')}',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _heroChip(
                Icons.handshake_outlined,
                'Tawarruq-based personal finance (simulated)',
              ),
              if (o.isOpen)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 5),
                      AppText(
                        'Valid for',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 5),
                      CountdownText(
                        target: o.validUntil,
                        onFinished: () => setState(() {}),
                        finishedText: 'Expired',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroChip(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .16),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 14),
        const SizedBox(width: 5),
        Flexible(
          child: AppText(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ),
      ],
    ),
  );

  Widget _keyFacts(FinancingOffer o) {
    final first = schedule.isEmpty ? null : schedule.first.dueDate;
    final last = schedule.isEmpty ? null : schedule.last.dueDate;

    final coolingOff = settings.demoFastCoolingOff
        ? '${settings.demoFastCoolingOffMinutes} ${tr('minutes (demo mode)')}'
        : '${settings.coolingOffBusinessDays} ${tr('business days after signing')}';

    return SectionCard(
      title: 'Key Facts Statement — ملخص المعلومات الأساسية',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InfoRow('Financed amount', formatSar(o.principal), strong: true),
          InfoRow(
            'Profit rate',
            '${formatPercent(o.annualProfitRate)} ${tr(o.rateType == 'flat' ? '(flat)' : '(reducing balance)')}',
          ),
          InfoRow(
            'Annual percentage rate (APR)',
            formatPercent(o.apr),
            strong: true,
          ),
          InfoRow('Term', '${o.termMonths} ${tr('months')}'),
          InfoRow('Admin fee', formatSar(o.adminFee)),
          InfoRow(
            'Amount paid into your account',
            formatSar(o.principal - o.adminFee),
          ),
          InfoRow('Total profit', formatSar(o.totalProfit)),
          InfoRow('Total repayable', formatSar(o.totalRepayable), strong: true),
          InfoRow('First installment (estimated)', formatDate(first)),
          InfoRow('Last installment (estimated)', formatDate(last)),
          InfoRow('Debt burden ratio', formatPercent(o.totalDbr)),
          InfoRow('Offer valid until', formatDateTime(o.validUntil)),
          const Divider(height: 26, color: Colors.white12),
          _note(
            Icons.savings_outlined,
            'Early settlement',
            'You may repay the whole amount early at any time. Profit for the remaining period is not charged; the bank may only ask for a limited compensation allowed by SAMA rules (simulated).',
          ),
          const SizedBox(height: 12),
          _note(
            Icons.shield_outlined,
            'Cooling-off right',
            '${tr('After you sign, you can withdraw from the agreement without penalty within')} $coolingOff.',
            translateBody: false,
          ),
          const SizedBox(height: 12),
          _note(
            Icons.info_outline,
            'Total repayable',
            'Total repayable = all monthly installments + the admin fee. The admin fee is deducted from the amount paid into your account.',
          ),
        ],
      ),
    );
  }

  Widget _note(
    IconData icon,
    String title,
    String body, {
    bool translateBody = true,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: kCyan, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(title, style: white(12, w: FontWeight.bold)),
              const SizedBox(height: 3),
              translateBody
                  ? AppText(body, style: white(11, c: Colors.white60))
                  : Text(body, style: white(11, c: Colors.white60)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _scheduleCard() {
    return Container(
      decoration: panel(),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: kCyan,
          collapsedIconColor: kCyan,
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          title: AppText(
            'Full repayment schedule',
            style: white(15, w: FontWeight.bold),
          ),
          subtitle: AppText(
            'Estimated dates; the final schedule starts when the funds are released.',
            style: white(10, c: Colors.white54),
          ),
          children: [ScheduleTable(rows: schedule)],
        ),
      ),
    );
  }

  Widget _actions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: isBusy ? null : _decline,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: AppText('Decline'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: isBusy ? null : _accept,
            style: ElevatedButton.styleFrom(
              backgroundColor: kBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: isBusy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : AppText(
                    'Accept offer',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }
}

/// Table of installments. Scrolls sideways on phones.
class ScheduleTable extends StatelessWidget {
  final List<ScheduleLine> rows;

  const ScheduleTable({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return AppText('No schedule yet.', style: white(12, c: Colors.white54));
    }

    TextStyle head = white(11, w: FontWeight.bold, c: Colors.white70);
    TextStyle cell = white(11);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 38,
        dataRowMinHeight: 34,
        dataRowMaxHeight: 38,
        columnSpacing: 22,
        horizontalMargin: 8,
        columns: [
          DataColumn(label: AppText('#', style: head)),
          DataColumn(label: AppText('Due date', style: head)),
          DataColumn(label: AppText('Principal', style: head), numeric: true),
          DataColumn(label: AppText('Profit', style: head), numeric: true),
          DataColumn(label: AppText('Installment', style: head), numeric: true),
          DataColumn(label: AppText('Remaining', style: head), numeric: true),
        ],
        rows: [
          for (final r in rows)
            DataRow(
              cells: [
                DataCell(Text('${r.installmentNo}', style: cell)),
                DataCell(Text(formatDate(r.dueDate), style: cell)),
                DataCell(Text(formatNumber(r.principalPart), style: cell)),
                DataCell(Text(formatNumber(r.profitPart), style: cell)),
                DataCell(Text(formatNumber(r.installment), style: cell)),
                DataCell(Text(formatNumber(r.remainingBalance), style: cell)),
              ],
            ),
        ],
      ),
    );
  }
}

/// Bottom sheet with the consents needed to accept the offer.
class _ConsentsSheet extends StatefulWidget {
  const _ConsentsSheet();

  @override
  State<_ConsentsSheet> createState() => _ConsentsSheetState();
}

class _ConsentsSheetState extends State<_ConsentsSheet> {
  final Map<String, bool> required = {
    'credit_bureau_consent': false,
    'terms_read': false,
    'simulation_ack': false,
    'data_sharing': false,
  };

  bool earlyDisbursement = false;

  static const Map<String, String> labels = {
    'credit_bureau_consent': 'I consent to a credit-bureau check (simulated)',
    'terms_read': 'I have read the Key Facts Statement and the terms',
    'simulation_ack':
        'I understand this is a simulation and no real financing is provided',
    'data_sharing': 'I agree that Rushd shares my application with this bank',
  };

  bool get _ready => required.values.every((v) => v);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AppText(
                'Before you accept',
                style: white(18, w: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              AppText(
                'Please confirm the following to accept the offer.',
                style: white(12, c: Colors.white54),
              ),
              const SizedBox(height: 10),
              for (final key in required.keys)
                CheckboxListTile(
                  value: required[key],
                  onChanged: (v) => setState(() => required[key] = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  activeColor: kBlue,
                  side: const BorderSide(color: Colors.white54),
                  title: AppText(labels[key]!, style: white(12)),
                ),
              const Divider(color: Colors.white12),
              CheckboxListTile(
                value: earlyDisbursement,
                onChanged: (v) =>
                    setState(() => earlyDisbursement = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                activeColor: Colors.orange,
                side: const BorderSide(color: Colors.white54),
                title: AppText(
                  'Optional: release the funds before the cooling-off period ends',
                  style: white(12, w: FontWeight.w600),
                ),
                subtitle: AppText(
                  'Some banks allow early release. If the funds are released early, you can no longer withdraw from the agreement.',
                  style: white(10, c: Colors.white54),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kBlue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.white12,
                  ),
                  onPressed: _ready
                      ? () => Navigator.pop(context, {
                          ...required,
                          'early_disbursement_waiver': earlyDisbursement,
                        })
                      : null,
                  child: AppText(
                    'Accept offer',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
