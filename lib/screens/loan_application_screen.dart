import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_settings.dart';
import '../models/borrower_app_state.dart';
import '../services/loan_application_service.dart';
import '../services/loan_request_service.dart';
import 'borrower_ui.dart';

/// Step after the lender approves a request: the borrower completes the
/// loan application online, uploads documents and follows the bank's review.
class LoanApplicationScreen extends StatefulWidget {
  final BorrowerRequestData request;

  const LoanApplicationScreen({super.key, required this.request});

  @override
  State<LoanApplicationScreen> createState() => _LoanApplicationScreenState();
}

class _LoanApplicationScreenState extends State<LoanApplicationScreen> {
  static const List<String> _categories = [
    'National ID',
    'Salary Certificate',
    'Bank Statement',
    'Other',
  ];

  final LoanApplicationService _service = LoanApplicationService();

  final nameController = TextEditingController();
  final nationalIdController = TextEditingController();
  final cityController = TextEditingController();
  final addressController = TextEditingController();
  final employerController = TextEditingController();
  final jobTitleController = TextEditingController();
  final yearsController = TextEditingController();
  final ibanController = TextEditingController();
  final notesController = TextEditingController();

  LoanApplicationData? application;
  BankContact? contact;

  final List<PendingDocument> pending = [];
  String category = _categories.first;

  bool isLoading = true;
  bool isSaving = false;
  String? loadError;

  bool get _editable =>
      application == null || application!.status == 'more_info_required';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      nameController,
      nationalIdController,
      cityController,
      addressController,
      employerController,
      jobTitleController,
      yearsController,
      ibanController,
      notesController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final app = await _service.getForRequest(widget.request.id);

      BankContact? bank;

      try {
        bank = await _service.getBankContact(widget.request.id);
      } catch (_) {
        bank = null;
      }

      if (!mounted) return;

      _fill(app);

      setState(() {
        application = app;
        contact = bank;
        isLoading = false;
        loadError = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        loadError = error.toString();
      });
    }
  }

  void _fill(LoanApplicationData? app) {
    if (app == null) {
      final state = BorrowerAppState.instance;

      nameController.text = state.fullName == 'Borrower' ? '' : state.fullName;
      return;
    }

    nameController.text = app.fullName;
    nationalIdController.text = app.nationalId;
    cityController.text = app.city;
    addressController.text = app.address;
    employerController.text = app.employer;
    jobTitleController.text = app.jobTitle;
    yearsController.text = app.yearsAtJob?.toString() ?? '';
    ibanController.text = app.iban;
    notesController.text = app.notes;
  }

  // =========================
  // ACTIONS
  // =========================

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;

      if (bytes == null) {
        _error('Could not read the selected file.');
        return;
      }

      if (bytes.lengthInBytes > 5 * 1024 * 1024) {
        _error('File is too large. The maximum size is 5 MB.');
        return;
      }

      setState(() {
        pending.add(
          PendingDocument(name: file.name, category: category, bytes: bytes),
        );
      });
    } catch (error) {
      _error('Could not pick the file: $error');
    }
  }

  Future<void> _submit() async {
    final name = nameController.text.trim();
    final nationalId = nationalIdController.text.trim();
    final city = cityController.text.trim();
    final employer = employerController.text.trim();
    final years = yearsController.text.trim();

    if (name.isEmpty) {
      _error('Please enter your full name.');
      return;
    }

    if (!RegExp(r'^\d{10}$').hasMatch(nationalId)) {
      _error('National ID / Iqama number must be 10 digits.');
      return;
    }

    if (city.isEmpty) {
      _error('Please enter your city.');
      return;
    }

    if (employer.isEmpty) {
      _error('Please enter your employer.');
      return;
    }

    if (years.isNotEmpty && double.tryParse(years) == null) {
      _error('Years at current job must be a number.');
      return;
    }

    setState(() => isSaving = true);

    try {
      await _service.submit(
        requestId: widget.request.id,
        lenderId: widget.request.lenderId,
        existing: application,
        newDocuments: List.of(pending),
        fields: {
          'full_name': name,
          'national_id': nationalId,
          'city': city,
          'address': addressController.text.trim(),
          'employer': employer,
          'job_title': jobTitleController.text.trim(),
          'years_at_job': years.isEmpty ? null : double.parse(years),
          'iban': ibanController.text.trim(),
          'notes': notesController.text.trim(),
        },
      );

      if (!mounted) return;

      pending.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Application sent to the bank for review.'),
        ),
      );

      await _load();
    } catch (error) {
      if (!mounted) return;

      _error('Could not send the application: $error');
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> _openDocument(LoanDocument doc) async {
    try {
      final url = await _service.signedUrl(doc.path);

      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (error) {
      _error('Could not open the document: $error');
    }
  }

  Future<void> _callBank() async {
    final phone = contact?.phone ?? '';

    if (phone.isEmpty) return;

    final launched = await launchUrl(Uri(scheme: 'tel', path: phone));

    if (!launched && mounted) {
      await Clipboard.setData(ClipboardData(text: phone));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Number copied: $phone')),
      );
    }
  }

  void _error(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  // =========================
  // UI
  // =========================

  @override
  Widget build(BuildContext context) {
    final r = widget.request;

    return BorrowerShell(
      active: 2,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 38),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            'Loan Application',
                            style: white(28, w: FontWeight.w900),
                          ),
                          const SizedBox(height: 5),
                          AppText(
                            '${r.bankName} • ${r.offerName} • SAR ${r.requestedAmount.toStringAsFixed(0)}',
                            style: white(12, c: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                if (isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (loadError != null)
                  _loadErrorBox()
                else ...[
                  _statusCard(),
                  if (application != null) const SizedBox(height: 16),
                  _formCard(),
                  const SizedBox(height: 16),
                  _documentsCard(),
                  const SizedBox(height: 16),
                  _contactCard(),
                  if (_editable) ...[
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: isSaving ? null : _submit,
                        child: isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : AppText(
                                application == null
                                    ? 'Submit Application to the Bank'
                                    : 'Resubmit Application',
                                style: white(13, w: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _loadErrorBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: panel(),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 42),
          const SizedBox(height: 10),
          AppText(
            'Unable to load the application.',
            style: white(16, w: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            loadError!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 14),
          ElevatedButton(onPressed: _load, child: const Text('Try Again')),
        ],
      ),
    );
  }

  // ---- status tracker ----

  Widget _statusCard() {
    final app = application;

    if (app == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: panel(),
        child: Row(
          children: [
            const Icon(Icons.celebration_outlined, color: kCyan),
            const SizedBox(width: 12),
            Expanded(
              child: AppText(
                'Your request was approved. Complete the application below and the bank will review it.',
                style: white(12, c: Colors.white70),
              ),
            ),
          ],
        ),
      );
    }

    Color color;
    IconData icon;
    String title;
    String message;

    switch (app.status) {
      case 'approved':
        color = Colors.greenAccent;
        icon = Icons.verified;
        title = 'APPLICATION APPROVED';
        message =
            'The bank approved your application. A bank representative will contact you to finalize the loan.';
        break;
      case 'rejected':
        color = Colors.redAccent;
        icon = Icons.cancel;
        title = 'APPLICATION NOT APPROVED';
        message = 'The bank could not approve your application.';
        break;
      case 'more_info_required':
        color = Colors.orangeAccent;
        icon = Icons.error_outline;
        title = 'ACTION REQUIRED';
        message =
            'The bank needs more information. Update your details or add documents, then resubmit.';
        break;
      default:
        color = Colors.amberAccent;
        icon = Icons.schedule;
        title = 'UNDER REVIEW';
        message = 'Your application was sent. The bank is reviewing it.';
    }

    final step = switch (app.status) {
      'submitted' => 1,
      'more_info_required' => 1,
      _ => 2,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              AppText(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _stepDot('Submitted', done: true, color: color),
              _stepLine(step >= 1, color),
              _stepDot('Bank review', done: step >= 1, color: color),
              _stepLine(step >= 2, color),
              _stepDot('Decision', done: step >= 2, color: color),
            ],
          ),
          const SizedBox(height: 14),
          AppText(message, style: white(12, c: Colors.white70)),
          if (app.lenderMessage.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    'Message from the bank',
                    style: white(10, c: Colors.white54),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    app.lenderMessage,
                    style: TextStyle(
                      color: AppSettings.instance.isDark
                          ? Colors.white
                          : const Color(0xff202033),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stepDot(String label, {required bool done, required Color color}) {
    return Column(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: done ? color : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(color: done ? color : Colors.white38, width: 2),
          ),
        ),
        const SizedBox(height: 5),
        AppText(label, style: white(9, c: Colors.white70)),
      ],
    );
  }

  Widget _stepLine(bool active, Color color) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 18, left: 6, right: 6),
        color: active ? color : Colors.white24,
      ),
    );
  }

  // ---- form ----

  Widget _formCard() {
    final readOnly = !_editable;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText('Your Information', style: white(17, w: FontWeight.bold)),
          const SizedBox(height: 4),
          AppText(
            'This information is sent to the bank for review. Make sure it is accurate.',
            style: white(10, c: Colors.white54),
          ),
          const SizedBox(height: 16),
          _row(
            _field('Full Name', nameController, readOnly: readOnly),
            _field(
              'National ID / Iqama Number',
              nationalIdController,
              readOnly: readOnly,
              number: true,
              maxLength: 10,
            ),
          ),
          const SizedBox(height: 12),
          _row(
            _field('City', cityController, readOnly: readOnly),
            _field('Address (optional)', addressController, readOnly: readOnly),
          ),
          const SizedBox(height: 12),
          _row(
            _field('Employer', employerController, readOnly: readOnly),
            _field('Job Title', jobTitleController, readOnly: readOnly),
          ),
          const SizedBox(height: 12),
          _row(
            _field(
              'Years at Current Job',
              yearsController,
              readOnly: readOnly,
              number: true,
            ),
            _field(
              'IBAN (optional)',
              ibanController,
              readOnly: readOnly,
            ),
          ),
          const SizedBox(height: 12),
          _field(
            'Notes for the bank (optional)',
            notesController,
            readOnly: readOnly,
            lines: 3,
          ),
        ],
      ),
    );
  }

  Widget _row(Widget a, Widget b) {
    return LayoutBuilder(
      builder: (_, box) {
        if (box.maxWidth < 520) {
          return Column(children: [a, const SizedBox(height: 12), b]);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: a),
            const SizedBox(width: 14),
            Expanded(child: b),
          ],
        );
      },
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    bool readOnly = false,
    bool number = false,
    int lines = 1,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          label,
          style: white(11, w: FontWeight.bold, c: Colors.white70),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          readOnly: readOnly,
          maxLines: lines,
          maxLength: maxLength,
          keyboardType: number
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          style: white(13),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: Colors.white.withOpacity(readOnly ? .05 : .10),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  // ---- documents ----

  Widget _documentsCard() {
    final existing = application?.documents ?? const <LoanDocument>[];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText('Documents', style: white(17, w: FontWeight.bold)),
          const SizedBox(height: 4),
          AppText(
            'Upload any documents the bank may need, such as your ID, salary certificate or bank statement (PDF, JPG or PNG, up to 5 MB each).',
            style: white(10, c: Colors.white54),
          ),
          const SizedBox(height: 14),

          if (existing.isEmpty && pending.isEmpty)
            AppText('No documents uploaded yet.', style: white(11, c: Colors.white54)),

          for (final doc in existing)
            _docTile(
              doc.name,
              doc.category,
              Icons.cloud_done_outlined,
              onTap: () => _openDocument(doc),
              actionLabel: 'Open',
            ),

          for (var i = 0; i < pending.length; i++)
            _docTile(
              pending[i].name,
              pending[i].category,
              Icons.insert_drive_file_outlined,
              onTap: () => setState(() => pending.removeAt(i)),
              actionLabel: 'Remove',
            ),

          if (_editable) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<String>(
                  value: category,
                  dropdownColor: const Color(0xff1E0B36),
                  style: const TextStyle(color: Colors.white),
                  items: [
                    for (final c in _categories)
                      DropdownMenuItem(
                        value: c,
                        child: Text(AppSettings.instance.tr(c)),
                      ),
                  ],
                  onChanged: (v) => setState(() => category = v ?? category),
                ),
                OutlinedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.upload_file, color: kCyan),
                  label: AppText(
                    'Choose File',
                    style: white(12, w: FontWeight.bold, c: kCyan),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _docTile(
    String name,
    String cat,
    IconData icon, {
    required VoidCallback onTap,
    required String actionLabel,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: panel(radius: 10),
      child: Row(
        children: [
          Icon(icon, color: kCyan, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppSettings.instance.isDark
                        ? Colors.white
                        : const Color(0xff202033),
                  ),
                ),
                AppText(cat, style: white(10, c: Colors.white54)),
              ],
            ),
          ),
          TextButton(onPressed: onTap, child: Text(AppSettings.instance.tr(actionLabel))),
        ],
      ),
    );
  }

  // ---- contact ----

  Widget _contactCard() {
    final phone = contact?.phone ?? '';
    final bank = contact?.bankName ?? widget.request.bankName;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: panel(),
      child: Row(
        children: [
          const Icon(Icons.support_agent, color: kCyan, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText('Questions? Call the bank',
                    style: white(15, w: FontWeight.bold)),
                const SizedBox(height: 4),
                AppText(
                  phone.isEmpty
                      ? '$bank has not added a phone number yet.'
                      : '$bank • $phone',
                  style: white(11, c: Colors.white54),
                ),
                AppText(
                  'The bank representative can also call you on the phone number saved in your profile.',
                  style: white(10, c: Colors.white38),
                ),
              ],
            ),
          ),
          if (phone.isNotEmpty)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: _callBank,
              icon: const Icon(Icons.call, size: 18),
              label: Text(AppSettings.instance.tr('Call')),
            ),
        ],
      ),
    );
  }
}
