import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/error_messages.dart';

import '../models/app_settings.dart';
import '../models/financing.dart';
import '../services/financing_service.dart';
import '../services/loan_application_service.dart';
import '../services/loan_request_service.dart';
import '../services/money_format.dart';
import 'financing_timeline.dart';
import 'journey_ui.dart'
    show CountdownText, formatDateTime, normalizeIban, saudiIban;
import 'lender_issue_offer_screen.dart';

/// Shown inside an approved request card on the lender's Review Requests
/// screen: the borrower's loan application, documents and the decision.
class LenderApplicationPanel extends StatefulWidget {
  final LenderRequestData request;

  const LenderApplicationPanel({super.key, required this.request});

  @override
  State<LenderApplicationPanel> createState() => _LenderApplicationPanelState();
}

class _LenderApplicationPanelState extends State<LenderApplicationPanel> {
  final LoanApplicationService _service = LoanApplicationService();
  final FinancingService _financing = FinancingService();

  LoanApplicationData? application;

  // Financing (only for approved applications)
  FinancingOffer? offer;
  FinancingAgreement? agreement;
  List<FinancingEvent> events = [];
  String? financingError;

  bool isLoading = true;
  bool isBusy = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final app = await _service.getForRequest(widget.request.id);

      FinancingOffer? latest;
      FinancingAgreement? loadedAgreement;
      List<FinancingEvent> loadedEvents = [];
      String? loadedError;

      if (app?.status == 'approved') {
        try {
          final offers = await _financing.getOffersForApplication(app!.id);
          latest = offers.isEmpty ? null : offers.first;

          if (latest != null) {
            loadedAgreement = await _financing.getAgreementForOffer(latest.id);
            loadedEvents = await _financing.getEvents([latest.id]);
          }
        } catch (error) {
          loadedError = friendlyError(error);
        }
      }

      if (!mounted) return;

      setState(() {
        application = app;
        offer = latest;
        agreement = loadedAgreement;
        events = loadedEvents;
        financingError = loadedError;
        isLoading = false;
        errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = friendlyError(error);
      });
    }
  }

  Future<void> _decide(
    String status, {
    String? message,
    List<InfoRequestItem> infoRequests = const [],
  }) async {
    final app = application;

    if (app == null) return;

    setState(() => isBusy = true);

    try {
      await _service.setStatus(
        applicationId: app.id,
        status: status,
        message: message,
        infoRequests: infoRequests,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText(
            status == 'approved'
                ? 'Application approved.'
                : status == 'rejected'
                ? 'Application rejected.'
                : 'Request for more information sent to the borrower.',
          ),
        ),
      );

      await _load();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(friendlyError(error)),
        ),
      );
    } finally {
      if (mounted) setState(() => isBusy = false);
    }
  }

  Future<String?> _askMessage({
    required String title,
    required String hint,
    required String confirm,
  }) async {
    final controller = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppSettings.instance.tr(title)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: AppSettings.instance.tr(hint),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppSettings.instance.tr('Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppSettings.instance.tr(confirm)),
          ),
        ],
      ),
    );

    final text = controller.text.trim();

    controller.dispose();

    if (ok != true) return null;

    if (text.isEmpty) {
      if (!mounted) return null;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: AppText('Please write a message first.')),
      );

      return null;
    }

    return text;
  }

  Future<void> _askMoreInfo() async {
    final result = await showDialog<_InfoRequestResult>(
      context: context,
      builder: (_) => const _InfoRequestDialog(),
    );

    if (result == null) return;

    await _decide(
      'more_info_required',
      message: result.message.isEmpty ? null : result.message,
      infoRequests: result.items,
    );
  }

  Future<void> _reject() async {
    final message = await _askMessage(
      title: 'Reject Application',
      hint: 'Enter the reason for rejection',
      confirm: 'Yes, Reject',
    );

    if (message != null) await _decide('rejected', message: message);
  }

  Future<void> _approve() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppSettings.instance.tr('Approve Application')),
        content: Text(
          AppSettings.instance.tr(
            'Approve this loan application? The borrower will be notified to expect your contact.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppSettings.instance.tr('Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppSettings.instance.tr('Yes, Approve')),
          ),
        ],
      ),
    );

    if (ok == true) await _decide('approved');
  }

  Future<void> _openDocument(LoanDocument doc) async {
    try {
      final url = await _service.signedUrl(doc.path);

      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(
            '${AppSettings.instance.tr('Could not open the document:')} ${friendlyError(error)}',
          ),
        ),
      );
    }
  }

  Future<void> _callBorrower() async {
    final phone = widget.request.borrowerPhone;

    if (phone.isEmpty) return;

    final launched = await launchUrl(Uri(scheme: 'tel', path: phone));

    if (!launched && mounted) {
      await Clipboard.setData(ClipboardData(text: phone));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppSettings.instance.tr('Number copied:')} $phone'),
        ),
      );
    }
  }

  // =========================
  // UI
  // =========================

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 22),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: .25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.folder_open, color: Colors.greenAccent),
              const SizedBox(width: 10),
              Expanded(
                child: AppText(
                  'Loan Application',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                tooltip: AppSettings.instance.tr('Refresh'),
                onPressed: _load,
                icon: const Icon(Icons.refresh, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _body(),
        ],
      ),
    );
  }

  Widget _body() {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (errorMessage != null) {
      return Text(
        errorMessage!,
        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
      );
    }

    final app = application;

    if (app == null) {
      return AppText(
        'Waiting for the borrower to complete the loan application.',
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      );
    }

    final dob = app.dateOfBirth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _statusChip(app.status),
            _chip(
              '${AppSettings.instance.tr('Round')} ${app.reviewRound}',
              Colors.lightBlueAccent,
            ),
          ],
        ),
        const SizedBox(height: 14),

        if (app.status == 'approved') ...[
          _financingCard(app),
          const SizedBox(height: 16),
        ],

        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _box('Full Name', app.fullName),
            _box('National ID / Iqama', app.nationalId),
            _box(
              'Date of birth',
              dob == null
                  ? ''
                  : '${dob.day.toString().padLeft(2, '0')}/${dob.month.toString().padLeft(2, '0')}/${dob.year}',
            ),
            _box('City', app.city),
            _box('National Address', app.address, width: 390),
            _box('Employer', app.employer),
            _box(
              'Employment sector',
              AppSettings.instance.tr(
                const {
                      'government': 'Government',
                      'private': 'Private sector',
                      'military': 'Military',
                      'retired': 'Retired',
                    }[app.employmentSector] ??
                    '',
              ),
            ),
            _box('Job Title', app.jobTitle),
            _box(
              'Years at Current Job',
              app.yearsAtJob == null ? '' : app.yearsAtJob.toString(),
            ),
            _box('IBAN', app.iban),
          ],
        ),

        if (app.notes.isNotEmpty) ...[
          const SizedBox(height: 12),
          _box('Notes from the borrower', app.notes, width: double.infinity),
        ],

        // info_requests stays saved after resubmission and decisions, so
        // only show it while it matters: pending, or answered and waiting
        // for the lender's review.
        if (_showRequests(app)) ...[
          const SizedBox(height: 16),
          _requestedItems(app),
        ],

        const SizedBox(height: 16),

        AppText(
          'Documents',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),

        if (app.documents.isEmpty)
          AppText(
            'The borrower did not upload any documents.',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),

        for (final doc in app.documents)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.description_outlined,
                  color: Colors.lightBlue,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      AppText(
                        doc.category,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _openDocument(doc),
                  child: Text(AppSettings.instance.tr('Open')),
                ),
              ],
            ),
          ),

        const SizedBox(height: 8),

        // Contact the borrower
        Row(
          children: [
            const Icon(Icons.phone_in_talk, color: Colors.lightBlue, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: AppText(
                widget.request.borrowerPhone.isEmpty
                    ? 'No phone number saved for this borrower.'
                    : '${AppSettings.instance.tr('Borrower phone:')} ${widget.request.borrowerPhone}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
            if (widget.request.borrowerPhone.isNotEmpty)
              OutlinedButton.icon(
                onPressed: _callBorrower,
                icon: const Icon(Icons.call, size: 16),
                label: Text(AppSettings.instance.tr('Call Borrower')),
              ),
          ],
        ),

        if (app.lenderMessage.isNotEmpty) ...[
          const SizedBox(height: 12),
          AppText(
            '${AppSettings.instance.tr('Your message:')} ${app.lenderMessage}',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],

        if (app.status == 'submitted') ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: isBusy ? null : _approve,
                icon: const Icon(Icons.check, color: Colors.white),
                label: Text(
                  AppSettings.instance.tr('Approve Application'),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: isBusy ? null : _askMoreInfo,
                icon: const Icon(Icons.help_outline, color: Colors.white),
                label: Text(
                  AppSettings.instance.tr('Request More Info'),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                onPressed: isBusy ? null : _reject,
                icon: const Icon(Icons.close, color: Colors.white),
                label: Text(
                  AppSettings.instance.tr('Reject'),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ],

        if (app.status == 'more_info_required') ...[
          const SizedBox(height: 12),
          AppText(
            'Waiting for the borrower to add the requested information.',
            style: const TextStyle(color: Colors.amberAccent, fontSize: 12),
          ),
        ],
      ],
    );
  }

  // =========================
  // FINANCING
  // =========================

  Future<void> _openIssueOffer(LoanApplicationData app) async {
    final issued = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LenderIssueOfferScreen(
          request: widget.request,
          application: app,
          version: (offer?.version ?? 0) + 1,
        ),
      ),
    );

    if (issued == true && mounted) await _load();
  }

  bool get _canRelease {
    final a = agreement;

    if (a == null || a.status != 'cooling_off') return false;

    final ended =
        a.coolingOffEndsAt != null &&
        !DateTime.now().isBefore(a.coolingOffEndsAt!);

    return ended || a.earlyDisbursementWaiver;
  }

  Future<void> _release(LoanApplicationData app) async {
    final a = agreement;
    final o = offer;

    if (a == null || o == null) return;

    final iban = normalizeIban(app.iban);
    final last4 = saudiIban.hasMatch(iban)
        ? iban.substring(iban.length - 4)
        : '????';
    final amount = formatSar(o.principal - o.adminFee);

    final question = AppSettings.instance.isArabic
        ? 'صرف $amount إلى الآيبان المنتهي بـ $last4؟ هذه محاكاة؛ لا تنتقل أي أموال.'
        : 'Release $amount to IBAN ending $last4? This is a simulation; no money moves.';

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: AppText('Release funds (simulated)'),
        content: Text(question),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: AppText('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: AppText('Release funds'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    setState(() => isBusy = true);

    try {
      await _financing.disburse(a.id);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: AppText('Funds released (simulated).')));

      await _load();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(friendlyError(error)),
        ),
      );
    } finally {
      if (mounted) setState(() => isBusy = false);
    }
  }

  (String, Color) _financingStatus() {
    final o = offer;
    final a = agreement;

    if (o == null) return ('Awaiting offer', Colors.lightBlueAccent);

    if (a?.status == 'withdrawn' || a?.status == 'cancelled') {
      return ('Borrower withdrew', Colors.white54);
    }

    switch (o.effectiveStatus) {
      case 'offer_declined':
        return ('Offer declined', Colors.white54);
      case 'offer_expired':
        return ('Offer expired', Colors.orangeAccent);
    }

    return switch (lenderStageFor(o, a)) {
      LenderStage.awaitingOffer => ('Awaiting offer', Colors.lightBlueAccent),
      LenderStage.offerIssued => ('Offer issued', Colors.lightBlueAccent),
      LenderStage.awaitingSignature => (
        'Awaiting signature',
        Colors.amberAccent,
      ),
      LenderStage.coolingOff => ('Cooling-off', Colors.amberAccent),
      LenderStage.readyToRelease => ('Ready to release', Colors.greenAccent),
      LenderStage.active => ('Active', Colors.greenAccent),
    };
  }

  /// Why a new offer version may be issued, or null when it may not.
  String? _closedReason() {
    final o = offer;
    final a = agreement;

    if (o == null) return null;

    if (a?.status == 'withdrawn' || a?.status == 'cancelled') {
      return AppSettings.instance.tr(
        'The borrower withdrew during the cooling-off period.',
      );
    }

    if (a != null) return null;

    switch (o.effectiveStatus) {
      case 'offer_declined':
        String reason = '';
        for (final e in events.reversed) {
          if (e.eventType == 'offer_declined') {
            reason = e.details['reason']?.toString().trim() ?? '';
            break;
          }
        }
        final base = AppSettings.instance.tr(
          'The borrower declined the offer.',
        );
        return reason.isEmpty
            ? base
            : '$base ${AppSettings.instance.tr('Reason:')} $reason';
      case 'offer_expired':
        return '${AppSettings.instance.tr('The offer expired on')} ${formatDateTime(o.validUntil)}.';
      case 'cancelled':
        return AppSettings.instance.tr('The offer was cancelled.');
    }

    return null;
  }

  Widget _financingCard(LoanApplicationData app) {
    final o = offer;
    final a = agreement;
    final (statusLabel, statusColor) = _financingStatus();
    final closed = _closedReason();
    final tr = AppSettings.instance.tr;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.lightBlue.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.lightBlueAccent.withValues(alpha: .3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.payments_outlined,
                color: Colors.lightBlueAccent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppText(
                  'Financing',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _chip(statusLabel, statusColor),
            ],
          ),
          const SizedBox(height: 12),

          if (financingError != null)
            Text(
              financingError!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            )
          else if (o == null) ...[
            AppText(
              'The application is approved. Issue the final offer so the borrower can review the Key Facts Statement.',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.lightBlue,
                foregroundColor: Colors.white,
              ),
              onPressed: isBusy ? null : () => _openIssueOffer(app),
              icon: const Icon(Icons.local_offer_outlined),
              label: AppText('Issue final offer'),
            ),
          ] else ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _mini('Version', '${o.version}'),
                _mini('Monthly installment', formatSar(o.monthlyInstallment)),
                _mini('APR', formatPercent(o.apr)),
                if (o.effectiveStatus == 'offer_issued')
                  _mini('Valid until', formatDateTime(o.validUntil)),
                if (a != null) _mini('Reference', a.referenceNo),
                if (a?.disbursedAt != null)
                  _mini('Released on', formatDateTime(a!.disbursedAt)),
              ],
            ),

            if (a?.status == 'cooling_off' && a!.coolingOffEndsAt != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    color: Colors.amberAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  AppText(
                    'Cooling-off ends in',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(width: 6),
                  CountdownText(
                    target: a.coolingOffEndsAt!,
                    onFinished: () => setState(() {}),
                    style: const TextStyle(
                      color: Colors.amberAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (a.earlyDisbursementWaiver) ...[
                const SizedBox(height: 4),
                AppText(
                  'The borrower allowed early release of the funds.',
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 11,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.white12,
                ),
                onPressed: isBusy || !_canRelease ? null : () => _release(app),
                icon: const Icon(Icons.account_balance_wallet_outlined),
                label: AppText('Release funds (simulated)'),
              ),
              if (!_canRelease)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: AppText(
                    'Available when the cooling-off period ends.',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ),
            ],

            if (closed != null) ...[
              const SizedBox(height: 12),
              Text(
                closed,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.lightBlueAccent,
                ),
                onPressed: isBusy ? null : () => _openIssueOffer(app),
                icon: const Icon(Icons.refresh),
                label: Text(
                  '${tr('Issue new offer')} (${tr('version')} ${o.version + 1})',
                ),
              ),
            ],
          ],

          const SizedBox(height: 8),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              iconColor: Colors.lightBlueAccent,
              collapsedIconColor: Colors.lightBlueAccent,
              title: AppText(
                'Timeline',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              children: [
                FinancingTimeline(
                  applicationApproved: true,
                  approvedAt: app.updatedAt,
                  offer: o,
                  agreement: a,
                  events: events,
                  waitingForOfferNote: 'Issue the final offer to the borrower.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mini(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppText(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  bool _showRequests(LoanApplicationData app) {
    if (app.infoRequests.isEmpty) return false;

    if (app.status == 'more_info_required') return true;

    // Resubmitted: the requests belong to the previous round.
    return app.status == 'submitted' && app.reviewRound > 1;
  }

  /// The items asked for in the last "more information" request: pending
  /// while the borrower works on them, then "Requested in round N" with the
  /// borrower's response once they resubmit.
  Widget _requestedItems(LoanApplicationData app) {
    final waiting = app.status == 'more_info_required';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orangeAccent.withValues(alpha: .35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            waiting
                ? 'Requested from the borrower'
                : '${AppSettings.instance.tr('Requested in round')} ${app.reviewRound - 1}',
            style: const TextStyle(
              color: Colors.orangeAccent,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          for (final item in app.infoRequests)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${waiting ? '•' : '✓'} ${infoRequestLabel(item)}${item.note.isEmpty ? '' : ' — ${item.note}'}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          if (!waiting) ...[
            const SizedBox(height: 12),
            AppText(
              "Borrower's response",
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
            const SizedBox(height: 4),
            app.borrowerResponse.isEmpty
                ? AppText(
                    'Not provided',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                : Text(
                    app.borrowerResponse,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ],
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = status == 'approved'
        ? Colors.greenAccent
        : status == 'rejected'
        ? Colors.redAccent
        : status == 'more_info_required'
        ? Colors.orangeAccent
        : Colors.amberAccent;

    final label = status == 'approved'
        ? 'APPLICATION APPROVED'
        : status == 'rejected'
        ? 'APPLICATION REJECTED'
        : status == 'more_info_required'
        ? 'MORE INFO REQUESTED'
        : 'READY FOR REVIEW';

    return _chip(label, color);
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: AppText(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _box(String label, String value, {double width = 190}) {
    final empty = value.trim().isEmpty || value.trim() == '-';

    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            empty ? AppSettings.instance.tr('Not provided') : value,
            style: TextStyle(
              color: empty ? Colors.white38 : Colors.white,
              fontWeight: empty ? FontWeight.normal : FontWeight.bold,
              fontStyle: empty ? FontStyle.italic : FontStyle.normal,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Upload a new Salary Certificate" / "Correct: Employer" (translated).
String infoRequestLabel(InfoRequestItem item) {
  final tr = AppSettings.instance.tr;

  switch (item.type) {
    case 'document':
      return '${tr('Upload a new/additional document:')} ${tr(item.category)}';
    case 'field':
      return '${tr('Correct:')} ${tr(infoRequestFields[item.field] ?? item.field)}';
    default:
      return item.note.isEmpty ? tr('Other') : tr('Other information');
  }
}

class _InfoRequestResult {
  final List<InfoRequestItem> items;
  final String message;

  const _InfoRequestResult(this.items, this.message);
}

/// Lets the lender pick exactly what the borrower must provide.
class _InfoRequestDialog extends StatefulWidget {
  const _InfoRequestDialog();

  @override
  State<_InfoRequestDialog> createState() => _InfoRequestDialogState();
}

class _InfoRequestDialogState extends State<_InfoRequestDialog> {
  // key: 'document:<category>' or 'field:<column>'
  final Set<String> selected = {};
  final Map<String, TextEditingController> notes = {};
  final messageController = TextEditingController();

  TextEditingController _note(String key) =>
      notes.putIfAbsent(key, TextEditingController.new);

  @override
  void dispose() {
    for (final c in notes.values) {
      c.dispose();
    }
    messageController.dispose();
    super.dispose();
  }

  String _id(String key) => key
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+$'), '');

  void _send() {
    final items = [
      for (final key in selected)
        InfoRequestItem(
          id: _id(key),
          type: key.startsWith('document:') ? 'document' : 'field',
          category: key.startsWith('document:') ? key.substring(9) : '',
          field: key.startsWith('field:') ? key.substring(6) : '',
          note: notes[key]?.text.trim() ?? '',
        ),
    ];

    Navigator.pop(
      context,
      _InfoRequestResult(items, messageController.text.trim()),
    );
  }

  Widget _option(String key, String label) {
    final isSelected = selected.contains(key);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: isSelected,
          title: AppText(label),
          onChanged: (v) => setState(() {
            if (v == true) {
              selected.add(key);
            } else {
              selected.remove(key);
            }
          }),
        ),
        if (isSelected)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 40, bottom: 8),
            child: TextField(
              controller: _note(key),
              decoration: InputDecoration(
                isDense: true,
                hintText: AppSettings.instance.tr(
                  'Note for the borrower (optional)',
                ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: AppText('Request More Information'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppText(
                'Choose exactly what the borrower must provide. At least one item is required.',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 14),
              AppText(
                'Upload a new/additional document',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              for (final category in infoRequestDocuments)
                _option('document:$category', category),
              const SizedBox(height: 10),
              AppText(
                'Fields to correct',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              for (final entry in infoRequestFields.entries)
                _option('field:${entry.key}', entry.value),
              const SizedBox(height: 12),
              TextField(
                controller: messageController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: AppSettings.instance.tr(
                    'General message (optional)',
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: AppText('Cancel'),
        ),
        ElevatedButton(
          onPressed: selected.isEmpty ? null : _send,
          child: AppText('Send to Borrower'),
        ),
      ],
    );
  }
}
