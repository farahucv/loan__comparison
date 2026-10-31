import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/error_messages.dart';

import '../models/app_settings.dart';
import '../services/loan_application_service.dart';
import '../services/loan_request_service.dart';

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

  LoanApplicationData? application;

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

      if (!mounted) return;

      setState(() {
        application = app;
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

  Future<void> _decide(String status, {String? message}) async {
    final app = application;

    if (app == null) return;

    setState(() => isBusy = true);

    try {
      await _service.setStatus(
        applicationId: app.id,
        status: status,
        message: message,
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
    final message = await _askMessage(
      title: 'Request More Information',
      hint: 'Tell the borrower what is missing',
      confirm: 'Send to Borrower',
    );

    if (message != null) await _decide('more_info_required', message: message);
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _statusChip(app.status),
        const SizedBox(height: 14),

        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _box('Full Name', app.fullName),
            _box('National ID / Iqama', app.nationalId),
            _box(
              'Date of birth',
              app.dateOfBirth == null
                  ? '-'
                  : '${app.dateOfBirth!.day.toString().padLeft(2, '0')}/${app.dateOfBirth!.month.toString().padLeft(2, '0')}/${app.dateOfBirth!.year}',
            ),
            _box('City', app.city),
            _box('Address', app.address.isEmpty ? '-' : app.address),
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
                    '-',
              ),
            ),
            _box('Job Title', app.jobTitle.isEmpty ? '-' : app.jobTitle),
            _box(
              'Years at Current Job',
              app.yearsAtJob == null ? '-' : app.yearsAtJob.toString(),
            ),
            _box('IBAN', app.iban.isEmpty ? '-' : app.iban),
          ],
        ),

        if (app.notes.isNotEmpty) ...[
          const SizedBox(height: 12),
          _box('Notes from the borrower', app.notes, width: double.infinity),
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
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
