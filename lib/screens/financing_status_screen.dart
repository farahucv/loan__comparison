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

class _TimelineStep {
  final String title;
  final DateTime? at;
  final String? note;
  final bool done;
  final bool failed;

  const _TimelineStep(
    this.title, {
    this.at,
    this.note,
    this.done = false,
    this.failed = false,
  });
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

  DateTime? _eventAt(String type) {
    for (final e in events.reversed) {
      if (e.eventType == type) return e.createdAt;
    }

    return null;
  }

  List<_TimelineStep> _steps() {
    final app = application;
    final o = offer;
    final a = agreement;

    final steps = <_TimelineStep>[
      _TimelineStep(
        'Application approved',
        at: app?.status == 'approved' ? app?.updatedAt : null,
        done: app?.status == 'approved',
      ),
    ];

    if (o == null) {
      steps.add(
        const _TimelineStep(
          'Offer issued',
          note: 'Waiting for the bank to send your final offer.',
        ),
      );
    } else {
      steps.add(
        _TimelineStep(
          'Offer issued',
          at: _eventAt('offer_issued') ?? o.createdAt,
          note: o.version > 1 ? '${tr('Offer version')} ${o.version}' : null,
          done: true,
        ),
      );

      switch (o.effectiveStatus) {
        case 'offer_declined':
          steps.add(
            _TimelineStep(
              'Offer declined',
              at: _eventAt('offer_declined'),
              failed: true,
              done: true,
            ),
          );
          return steps;
        case 'offer_expired':
          steps.add(
            _TimelineStep(
              'Offer expired',
              at: _eventAt('offer_expired') ?? o.validUntil,
              failed: true,
              done: true,
            ),
          );
          return steps;
      }
    }

    steps.add(
      _TimelineStep(
        'Accepted',
        at: _eventAt('offer_accepted') ?? a?.kfsAcceptedAt,
        note: a == null ? null : '${tr('Reference')} ${a.referenceNo}',
        done: a != null,
      ),
    );

    steps.add(
      _TimelineStep(
        'Signed',
        at: _eventAt('contract_signed') ?? a?.signedAt,
        done: a?.signedAt != null,
      ),
    );

    steps.add(
      _TimelineStep(
        'Cooling-off',
        at: _eventAt('cooling_off_started') ?? a?.signedAt,
        note: a?.coolingOffEndsAt == null
            ? null
            : '${tr('Ends')} ${formatDateTime(a!.coolingOffEndsAt)}',
        done: a?.signedAt != null,
      ),
    );

    if (a?.status == 'withdrawn' || a?.status == 'cancelled') {
      steps.add(
        _TimelineStep(
          'Withdrawn from the agreement',
          at: _eventAt('withdrawn') ?? a?.withdrawnAt,
          failed: true,
          done: true,
        ),
      );
      return steps;
    }

    steps.add(
      _TimelineStep(
        'Disbursed',
        at: _eventAt('disbursed') ?? a?.disbursedAt,
        done: a?.disbursedAt != null,
      ),
    );

    steps.add(
      _TimelineStep(
        'Active',
        at: _eventAt('activated') ?? a?.disbursedAt,
        done: a?.status == 'active',
      ),
    );

    return steps;
  }

  Future<void> _continue() async {
    final screen = journeyScreen(widget.request, _journey);

    // This screen is already the right place for these stages.
    if (screen == null || screen is FinancingStatusScreen) return;

    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

    if (mounted) await _load();
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
      SectionCard(title: 'Timeline', child: _timeline(_steps())),
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

  Widget _timeline(List<_TimelineStep> steps) {
    // The first step that is not done is the current one.
    final current = steps.indexWhere((s) => !s.done);

    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 30,
                  child: Column(
                    children: [
                      _dot(steps[i], isCurrent: i == current),
                      if (i < steps.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: steps[i].done && !steps[i].failed
                                ? Colors.greenAccent.withValues(alpha: .6)
                                : Colors.white24,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          steps[i].title,
                          style: white(
                            13,
                            w: FontWeight.bold,
                            c: steps[i].failed
                                ? Colors.redAccent
                                : steps[i].done || i == current
                                ? Colors.white
                                : Colors.white38,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          steps[i].done
                              ? formatDateTime(steps[i].at)
                              : i == current
                              ? tr('In progress')
                              : tr('Not started'),
                          style: white(11, c: Colors.white54),
                        ),
                        if (steps[i].note != null) ...[
                          const SizedBox(height: 2),
                          AppText(
                            steps[i].note!,
                            style: white(11, c: Colors.white54),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _dot(_TimelineStep step, {required bool isCurrent}) {
    final color = step.failed
        ? Colors.redAccent
        : step.done
        ? Colors.greenAccent
        : isCurrent
        ? kCyan
        : Colors.white24;

    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: step.done ? color : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: step.done
          ? Icon(
              step.failed ? Icons.close : Icons.check,
              size: 14,
              color: Colors.black,
            )
          : null,
    );
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
