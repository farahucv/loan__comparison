import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_settings.dart';
import '../models/financing.dart';
import '../services/error_messages.dart';
import '../services/financing_math.dart';
import '../services/financing_service.dart';
import '../services/loan_application_service.dart';
import '../services/loan_request_service.dart';
import '../services/money_format.dart';
import 'borrower_ui.dart';
import 'financing_offer_screen.dart';
import 'financing_timeline.dart';
import 'journey_navigation.dart';
import 'journey_ui.dart';
import 'loan_application_screen.dart';

/// Timeline of the whole financing journey for one request, the
/// disbursement receipt and the next installment.
class FinancingStatusScreen extends StatefulWidget {
  final BorrowerRequestData request;

  const FinancingStatusScreen({super.key, required this.request});

  @override
  State<FinancingStatusScreen> createState() => _FinancingStatusScreenState();
}

class _FinancingStatusScreenState extends State<FinancingStatusScreen> {
  final FinancingService _financing = FinancingService();
  final LoanApplicationService _applications = LoanApplicationService();

  LoanApplicationData? application;
  FinancingOffer? offer;
  FinancingAgreement? agreement;
  List<FinancingEvent> events = [];
  List<RepaymentInstallment> schedule = [];

  bool isLoading = true;
  bool isWithdrawing = false;
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
      final app = await _applications.getForRequest(widget.request.id);

      FinancingOffer? latest;
      FinancingAgreement? loadedAgreement;
      List<FinancingEvent> loadedEvents = [];
      List<RepaymentInstallment> loadedSchedule = [];

      if (app != null) {
        final offers = await _financing.getOffersForApplication(app.id);

        latest = offers.isEmpty ? null : offers.first;

        if (latest != null) {
          loadedAgreement = await _financing.getAgreementForOffer(latest.id);
          loadedEvents = await _financing.getEvents([latest.id]);
        }

        if (loadedAgreement?.signedAt != null) {
          loadedSchedule = await _financing.getSchedule(loadedAgreement!.id);
        }
      }

      if (!mounted) return;

      setState(() {
        application = app;
        offer = latest;
        agreement = loadedAgreement;
        events = loadedEvents;
        schedule = loadedSchedule;
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

  BorrowerJourney get _journey => BorrowerJourney(
    requestStatus: widget.request.status,
    applicationId: application?.id,
    applicationStatus: application?.status,
    offer: offer,
    agreement: agreement,
  );

  Future<void> _continue() async {
    final screen = journeyScreen(widget.request, _journey);

    // This screen is already the right place for these stages.
    if (screen == null || screen is FinancingStatusScreen) return;

    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

    if (mounted) await _load();
  }

  Future<void> _withdraw(FinancingAgreement a) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: AppText('Withdraw from agreement'),
        content: AppText(
          'You are within the cooling-off period, so you can withdraw without penalty. The agreement will be cancelled and no funds will be released. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: AppText('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: AppText('Yes, withdraw'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => isWithdrawing = true);

    try {
      await _financing.withdraw(a.id);

      if (!mounted) return;

      showInfo(context, 'You withdrew from the agreement.');
      await _load();
    } catch (error) {
      if (mounted) showError(context, friendlyError(error));
    } finally {
      if (mounted) setState(() => isWithdrawing = false);
    }
  }

  /// "You can still withdraw until ..." with a live countdown. When the
  /// countdown ends the screen rebuilds into the waiting-for-the-bank state.
  Widget _coolingOffCard(FinancingAgreement a) {
    final ends = a.coolingOffEndsAt!;

    return SectionCard(
      accent: Colors.amberAccent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${tr('Cooling-off period — you can still withdraw until')} ${formatDateTime(ends)}',
            style: white(13, w: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.timer_outlined,
                color: Colors.amberAccent,
                size: 18,
              ),
              const SizedBox(width: 6),
              CountdownText(
                target: ends,
                onFinished: () => setState(() {}),
                style: TextStyle(
                  color: journeyText,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 46,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
              ),
              onPressed: isWithdrawing ? null : () => _withdraw(a),
              icon: isWithdrawing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.undo),
              label: AppText(
                'Withdraw from agreement',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // UI
  // =========================

  @override
  Widget build(BuildContext context) {
    return BorrowerShell(
      active: 2,
      child: JourneyPage(
        maxWidth: 760,
        children: [
          JourneyHeader(
            title: 'Financing progress',
            subtitle:
                '${tr(widget.request.bankName)} • ${widget.request.offerName}',
            onRefresh: _load,
          ),
          if (isLoading)
            const LoadingView()
          else if (errorMessage != null)
            ErrorView(
              title: 'Unable to load your financing.',
              message: errorMessage!,
              onRetry: _load,
            )
          else if (application == null)
            EmptyView(
              icon: Icons.assignment_outlined,
              title: 'No application yet',
              message:
                  'Complete your loan application to start the financing journey.',
              action: ElevatedButton(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        LoanApplicationScreen(request: widget.request),
                  ),
                ),
                child: AppText('Start application'),
              ),
            )
          else
            ..._content(),
        ],
      ),
    );
  }

  List<Widget> _content() {
    final journey = _journey;
    final info = stageInfo(journey.stage);
    final next = journeyScreen(widget.request, journey);
    final canContinue = next != null && next is! FinancingStatusScreen;
    final a = agreement;

    return [
      SectionCard(
        accent: info.color,
        child: Row(
          children: [
            Icon(info.icon, color: info.color),
            const SizedBox(width: 12),
            Expanded(
              child: AppText(info.label, style: white(14, w: FontWeight.bold)),
            ),
          ],
        ),
      ),
      if (journey.stage == JourneyStage.coolingOff &&
          a?.coolingOffEndsAt != null) ...[
        const SizedBox(height: 12),
        _coolingOffCard(a!),
      ],
      if (canContinue) ...[
        const SizedBox(height: 12),
        SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: kBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: _continue,
            icon: const Icon(Icons.arrow_forward),
            label: AppText(
              'Continue',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
      if (a?.disbursedAt != null && offer != null) ...[
        const SizedBox(height: 16),
        _receipt(a!, offer!),
      ],
      if (schedule.isNotEmpty && a?.status == 'active') ...[
        const SizedBox(height: 16),
        _nextInstallment(),
      ],
      const SizedBox(height: 16),
      SectionCard(
        title: 'Timeline',
        child: FinancingTimeline(
          applicationApproved: application?.status == 'approved',
          approvedAt: application?.updatedAt,
          offer: offer,
          agreement: agreement,
          events: events,
        ),
      ),
      if (schedule.isNotEmpty) ...[
        const SizedBox(height: 16),
        Container(
          decoration: panel(),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              iconColor: kCyan,
              collapsedIconColor: kCyan,
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 4,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              title: AppText(
                'Repayment schedule',
                style: white(15, w: FontWeight.bold),
              ),
              children: [
                ScheduleTable(
                  rows: [
                    for (final r in schedule)
                      ScheduleLine(
                        installmentNo: r.installmentNo,
                        dueDate: r.dueDate,
                        principalPart: r.principalPart,
                        profitPart: r.profitPart,
                        installment: r.installment,
                        remainingBalance: r.remainingBalance,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
      const SizedBox(height: 16),
      const DemoNote(
        'This journey is a simulation. No real money is sent and no real contract is signed.',
      ),
    ];
  }

  Widget _receipt(FinancingAgreement a, FinancingOffer o) {
    final net = o.principal - o.adminFee;
    final last4 = a.disbursementIbanLast4 ?? '----';

    final text = AppSettings.instance.isArabic
        ? 'تم إرسال ${formatSar(net)} إلى الآيبان المنتهي بـ $last4 (محاكاة)'
        : '${formatSar(net)} sent to IBAN ending $last4 (simulated)';

    final receipt = [
      tr('Rushd — disbursement receipt (simulated)'),
      '${tr('Reference number')}: ${a.referenceNo}',
      '${tr('Bank')}: ${tr(widget.request.bankName)}',
      '${tr('Amount paid into your account')}: ${formatSar(net)}',
      '${tr('IBAN')}: SA** **** **** **** **** $last4',
      '${tr('Date')}: ${formatDateTime(a.disbursedAt)}',
    ].join('\n');

    return SectionCard(
      accent: Colors.greenAccent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long, color: Colors.greenAccent),
              const SizedBox(width: 10),
              Expanded(
                child: AppText(
                  'Disbursement receipt',
                  style: white(15, w: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(text, style: white(16, w: FontWeight.w800)),
          const SizedBox(height: 10),
          InfoRow('Reference number', a.referenceNo),
          InfoRow('Date', formatDateTime(a.disbursedAt)),
          InfoRow('Financed amount', formatSar(o.principal)),
          InfoRow('Admin fee deducted', formatSar(o.adminFee)),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: receipt));
                if (mounted) showInfo(context, 'Receipt copied.');
              },
              icon: const Icon(Icons.copy, size: 16),
              label: AppText('Copy receipt'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nextInstallment() {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);

    final next = schedule.firstWhere(
      (r) => !r.dueDate.isBefore(startOfToday),
      orElse: () => schedule.last,
    );

    return SectionCard(
      title: 'Next installment',
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kCyan.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.event, color: kCyan),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatSar(next.installment),
                  style: white(20, w: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  '${tr('Due on')} ${formatDate(next.dueDate)} • ${tr('Installment')} ${next.installmentNo}/${schedule.length}',
                  style: white(11, c: Colors.white54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
