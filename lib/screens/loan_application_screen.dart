import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_settings.dart';
import '../models/borrower_app_state.dart';
import '../services/error_messages.dart';
import '../services/loan_application_service.dart';
import '../services/loan_request_service.dart';
import '../services/money_format.dart';
import 'borrower_ui.dart';
import 'financing_status_screen.dart';
import 'journey_ui.dart';

/// Step after the lender approves a request: the borrower completes the
/// loan application in four steps (identity, employment & income,
/// documents, review & consents) and follows the bank's review.
class LoanApplicationScreen extends StatefulWidget {
  final BorrowerRequestData request;

  const LoanApplicationScreen({super.key, required this.request});

  @override
  State<LoanApplicationScreen> createState() => _LoanApplicationScreenState();
}

enum _DocStatus { missing, uploaded, accepted, needsReupload }

class _LoanApplicationScreenState extends State<LoanApplicationScreen> {
  static const List<String> _docCategories = [
    'National ID',
    'Salary Certificate',
    '3-Month Bank Statement',
  ];

  static const Map<String, String> _sectors = {
    'government': 'Government',
    'private': 'Private sector',
    'military': 'Military',
    'retired': 'Retired',
  };

  static const List<String> _steps = [
    'Identity',
    'Employment & income',
    'Documents',
    'Review & consents',
  ];

  static const int _maxFileBytes = 5 * 1024 * 1024;

  final LoanApplicationService _service = LoanApplicationService();

  final nameController = TextEditingController();
  final nationalIdController = TextEditingController();
  final cityController = TextEditingController();
  final employerController = TextEditingController();
  final jobTitleController = TextEditingController();
  final yearsController = TextEditingController();
  final ibanController = TextEditingController();

  DateTime? dateOfBirth;
  String? sector;
  double? monthlyIncome;

  // Identity is "verified" for this exact name + ID + date of birth.
  String? _verifiedFor;
  bool isVerifying = false;

  bool ibanEditing = true;

  LoanApplicationData? application;
  BankContact? contact;

  final List<PendingDocument> pending = [];

  /// category -> why the last file was refused
  final Map<String, String> refused = {};

  bool consentBureau = false;
  bool consentAccurate = false;
  bool consentSimulation = false;

  int step = 0;

  bool isLoading = true;
  bool isSaving = false;
  String? loadError;

  bool get _editable =>
      application == null || application!.status == 'more_info_required';

  String get _identityKey =>
      '${nameController.text.trim()}|${nationalIdController.text.trim()}|${dateOfBirth?.toIso8601String()}';

  bool get _identityVerified => _verifiedFor == _identityKey;

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
      employerController,
      jobTitleController,
      yearsController,
      ibanController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      isLoading = true;
      loadError = null;
    });

    try {
      final app = await _service.getForRequest(widget.request.id);

      BankContact? bank;
      double? income;

      try {
        bank = await _service.getBankContact(widget.request.id);
      } catch (_) {
        bank = null;
      }

      try {
        income = await _service.getMonthlyIncome();
      } catch (_) {
        income = null;
      }

      if (!mounted) return;

      _fill(app);

      setState(() {
        application = app;
        contact = bank;
        monthlyIncome = income;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        loadError = friendlyError(error);
      });
    }
  }

  Future<void> _reloadIncome() async {
    try {
      final income = await _service.getMonthlyIncome();

      if (mounted) setState(() => monthlyIncome = income);
    } catch (_) {
      // Keep the old value.
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
    employerController.text = app.employer;
    jobTitleController.text = app.jobTitle;
    yearsController.text = app.yearsAtJob == null
        ? ''
        : app.yearsAtJob!.toStringAsFixed(app.yearsAtJob! % 1 == 0 ? 0 : 1);
    ibanController.text = app.iban;
    dateOfBirth = app.dateOfBirth;
    sector = _sectors.containsKey(app.employmentSector)
        ? app.employmentSector
        : null;

    ibanEditing = !saudiIban.hasMatch(normalizeIban(app.iban));

    if (app.consents['identity_verified_simulated'] == true) {
      _verifiedFor = _identityKey;
    }
  }

  // =========================
  // VALIDATION
  // =========================

  int? _age(DateTime dob) {
    final now = DateTime.now();
    var age = now.year - dob.year;

    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }

    return age;
  }

  String? _identityBasicsError() {
    if (nameController.text.trim().isEmpty) {
      return 'Please enter your full name.';
    }

    if (!RegExp(r'^[12]\d{9}$').hasMatch(nationalIdController.text.trim())) {
      return 'National ID / Iqama number must be 10 digits and start with 1 or 2.';
    }

    if (dateOfBirth == null) return 'Please enter your date of birth.';

    if ((_age(dateOfBirth!) ?? 0) < 18) {
      return 'You must be at least 18 years old.';
    }

    return null;
  }

  String? _stepError(int index) {
    switch (index) {
      case 0:
        final basics = _identityBasicsError();

        if (basics != null) return basics;

        if (cityController.text.trim().isEmpty) {
          return 'Please enter your city.';
        }

        if (!_identityVerified) return 'Please verify your identity first.';

        return null;

      case 1:
        if (employerController.text.trim().isEmpty) {
          return 'Please enter your employer.';
        }

        if (sector == null) return 'Please choose your employment sector.';

        final years = yearsController.text.trim();

        if (years.isNotEmpty && double.tryParse(years) == null) {
          return 'Years at current job must be a number.';
        }

        if ((monthlyIncome ?? 0) <= 0) {
          return 'Add your monthly salary to your profile first.';
        }

        if (!saudiIban.hasMatch(normalizeIban(ibanController.text))) {
          return 'IBAN must be SA followed by 22 digits (24 characters).';
        }

        return null;

      case 2:
        final missing = _docCategories
            .where(
              (c) =>
                  _statusFor(c) != _DocStatus.uploaded &&
                  _statusFor(c) != _DocStatus.accepted,
            )
            .map(tr)
            .toList();

        if (missing.isNotEmpty) {
          return '${tr('Please upload:')} ${missing.join(tr(', '))}';
        }

        return null;

      default:
        if (!consentBureau || !consentAccurate || !consentSimulation) {
          return 'Please accept all the required consents.';
        }

        return null;
    }
  }

  void _next() {
    final error = _stepError(step);

    if (error != null) {
      showError(context, error);
      return;
    }

    setState(() => step = (step + 1).clamp(0, _steps.length - 1));
  }

  void _goTo(int index) {
    // Only allow jumping forward over steps that are complete.
    for (var i = 0; i < index; i++) {
      final error = _stepError(i);

      if (error != null) {
        setState(() => step = i);
        showError(context, error);
        return;
      }
    }

    setState(() => step = index);
  }

  // =========================
  // ACTIONS
  // =========================

  Future<void> _verifyIdentity() async {
    final error = _identityBasicsError();

    if (error != null) {
      showError(context, error);
      return;
    }

    setState(() => isVerifying = true);

    // Simulated check: a short wait, then success.
    await Future.delayed(const Duration(milliseconds: 1600));

    if (!mounted) return;

    setState(() {
      isVerifying = false;
      _verifiedFor = _identityKey;
    });
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: dateOfBirth ?? DateTime(now.year - 30, now.month, now.day),
      firstDate: DateTime(1930),
      lastDate: now,
      helpText: tr('Date of birth'),
    );

    if (picked != null) setState(() => dateOfBirth = picked);
  }

  Future<void> _pickFile(String category) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      final ext = file.name.toLowerCase().split('.').last;

      String? problem;

      if (bytes == null) {
        problem = 'Could not read the selected file.';
      } else if (!['pdf', 'jpg', 'jpeg', 'png'].contains(ext)) {
        problem = 'Only PDF, JPG and PNG files are allowed.';
      } else if (bytes.lengthInBytes > _maxFileBytes) {
        problem = 'File is too large. The maximum size is 5 MB.';
      }

      if (problem != null) {
        setState(() => refused[category] = problem!);
        if (mounted) showError(context, problem);
        return;
      }

      setState(() {
        refused.remove(category);
        pending.add(
          PendingDocument(name: file.name, category: category, bytes: bytes!),
        );
      });
    } catch (error) {
      if (mounted) showError(context, friendlyError(error));
    }
  }

  Future<void> _submit() async {
    for (var i = 0; i < _steps.length; i++) {
      final error = _stepError(i);

      if (error != null) {
        setState(() => step = i);
        showError(context, error);
        return;
      }
    }

    setState(() => isSaving = true);

    final years = yearsController.text.trim();
    final dob = dateOfBirth!;

    try {
      await _service.submit(
        requestId: widget.request.id,
        lenderId: widget.request.lenderId,
        existing: application,
        newDocuments: List.of(pending),
        fields: {
          'full_name': nameController.text.trim(),
          'national_id': nationalIdController.text.trim(),
          'date_of_birth':
              '${dob.year.toString().padLeft(4, '0')}-${dob.month.toString().padLeft(2, '0')}-${dob.day.toString().padLeft(2, '0')}',
          'city': cityController.text.trim(),
          'address': application?.address ?? '',
          'employer': employerController.text.trim(),
          'employment_sector': sector,
          'job_title': jobTitleController.text.trim(),
          'years_at_job': years.isEmpty ? null : double.parse(years),
          'iban': normalizeIban(ibanController.text),
          'notes': application?.notes ?? '',
          'consents': {
            'credit_bureau_check': true,
            'info_accurate': true,
            'simulation_ack': true,
            'identity_verified_simulated': true,
            'accepted_at': DateTime.now().toUtc().toIso8601String(),
          },
        },
      );

      if (!mounted) return;

      pending.clear();
      showInfo(context, 'Application sent to the bank for review.');

      setState(() {
        step = 0;
        consentBureau = false;
        consentAccurate = false;
        consentSimulation = false;
      });

      await _load();
    } catch (error) {
      if (mounted) showError(context, friendlyError(error));
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> _openDocument(LoanDocument doc) async {
    try {
      final url = await _service.signedUrl(doc.path);

      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (error) {
      if (mounted) {
        showError(
          context,
          '${tr('Could not open the document:')} ${friendlyError(error)}',
        );
      }
    }
  }

  Future<void> _callBank() async {
    final phone = contact?.phone ?? '';

    if (phone.isEmpty) return;

    final launched = await launchUrl(Uri(scheme: 'tel', path: phone));

    if (!launched && mounted) {
      await Clipboard.setData(ClipboardData(text: phone));

      if (mounted) showInfo(context, '${tr('Number copied:')} $phone');
    }
  }

  // =========================
  // DOCUMENT HELPERS
  // =========================

  bool _inCategory(String docCategory, String card) =>
      docCategory == card ||
      (card == '3-Month Bank Statement' && docCategory == 'Bank Statement');

  List<LoanDocument> _existingFor(String card) =>
      (application?.documents ?? const <LoanDocument>[])
          .where((d) => _inCategory(d.category, card))
          .toList();

  List<PendingDocument> _pendingFor(String card) =>
      pending.where((d) => d.category == card).toList();

  List<LoanDocument> get _otherDocuments =>
      (application?.documents ?? const <LoanDocument>[])
          .where((d) => !_docCategories.any((c) => _inCategory(d.category, c)))
          .toList();

  _DocStatus _statusFor(String card) {
    if (refused.containsKey(card)) return _DocStatus.needsReupload;

    final has = _existingFor(card).isNotEmpty || _pendingFor(card).isNotEmpty;

    if (!has) return _DocStatus.missing;

    if (application?.status == 'approved') return _DocStatus.accepted;

    return _DocStatus.uploaded;
  }

  // =========================
  // UI
  // =========================

  @override
  Widget build(BuildContext context) {
    final r = widget.request;

    return BorrowerShell(
      active: 2,
      child: JourneyPage(
        children: [
          JourneyHeader(
            title: 'Loan Application',
            subtitle:
                '${tr(r.bankName)} • ${r.offerName} • ${formatSar(r.requestedAmount, decimals: 0)}',
          ),
          if (isLoading)
            const LoadingView()
          else if (loadError != null)
            ErrorView(
              title: 'Unable to load the application.',
              message: loadError!,
              onRetry: _load,
            )
          else if (_editable)
            ..._stepper()
          else
            ..._readOnly(),
        ],
      ),
    );
  }

  // ---- editable: 4-step form ----

  List<Widget> _stepper() {
    return [
      if (application != null) ...[
        _statusCard(application!),
        const SizedBox(height: 16),
      ],
      const DemoNote('Use test data — do not enter your real ID or IBAN.'),
      const SizedBox(height: 16),
      _progress(),
      const SizedBox(height: 16),
      SectionCard(
        title: '${tr('Step')} ${step + 1}: ${tr(_steps[step])}',
        child: switch (step) {
          0 => _identityStep(),
          1 => _employmentStep(),
          2 => _documentsStep(),
          _ => _reviewStep(),
        },
      ),
      const SizedBox(height: 18),
      _navButtons(),
    ];
  }

  Widget _progress() {
    final narrow = MediaQuery.sizeOf(context).width < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (step + 1) / _steps.length,
            minHeight: 8,
            backgroundColor: Colors.white12,
            color: kCyan,
          ),
        ),
        const SizedBox(height: 10),
        if (narrow)
          AppText(
            '${tr('Step')} ${step + 1} ${tr('of')} ${_steps.length} — ${tr(_steps[step])}',
            style: white(11, c: Colors.white70),
          )
        else
          Row(
            children: [
              for (var i = 0; i < _steps.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => _goTo(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 11,
                            backgroundColor: i <= step
                                ? kCyan
                                : Colors.white.withValues(alpha: .12),
                            child: i < step
                                ? const Icon(
                                    Icons.check,
                                    size: 13,
                                    color: Colors.white,
                                  )
                                : Text(
                                    '${i + 1}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: AppText(
                              _steps[i],
                              overflow: TextOverflow.ellipsis,
                              style: white(
                                11,
                                w: i == step
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                c: i == step ? Colors.white : Colors.white54,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _navButtons() {
    final last = step == _steps.length - 1;
    final consentsDone = consentBureau && consentAccurate && consentSimulation;

    return Row(
      children: [
        if (step > 0)
          OutlinedButton.icon(
            onPressed: isSaving ? null : () => setState(() => step--),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: AppText('Back'),
            style: OutlinedButton.styleFrom(
              foregroundColor: journeyText,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            ),
          ),
        const Spacer(),
        SizedBox(
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kBlue,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.white12,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: isSaving || (last && !consentsDone)
                ? null
                : (last ? _submit : _next),
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
                    last
                        ? (application == null
                              ? 'Submit Application to the Bank'
                              : 'Resubmit Application')
                        : 'Next',
                    style: white(13, w: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }

  // ---- step 1 ----

  Widget _identityStep() {
    final verified = _identityVerified;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _row(
          _field('Full Name', nameController),
          _field(
            'National ID / Iqama Number',
            nationalIdController,
            digitsOnly: true,
            maxLength: 10,
            hint: '1XXXXXXXXX',
          ),
        ),
        const SizedBox(height: 12),
        _row(_dateField(), _field('City', cityController)),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: (verified ? Colors.greenAccent : kCyan).withValues(
              alpha: .07,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (verified ? Colors.greenAccent : kCyan).withValues(
                alpha: .3,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (verified)
                Row(
                  children: [
                    const Icon(Icons.verified, color: Colors.greenAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppText(
                        'Identity verified (simulated)',
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                )
              else
                OutlinedButton.icon(
                  onPressed: isVerifying ? null : _verifyIdentity,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kCyan,
                    side: const BorderSide(color: kCyan),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  icon: isVerifying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.fingerprint),
                  label: AppText(
                    isVerifying ? 'Verifying…' : 'Verify identity (simulated)',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              const SizedBox(height: 8),
              AppText(
                'In a live service this step uses the national digital-identity platform.',
                style: white(10, c: Colors.white54),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          'Date of birth',
          style: white(11, w: FontWeight.bold, c: Colors.white70),
        ),
        const SizedBox(height: 7),
        InkWell(
          onTap: _pickDateOfBirth,
          borderRadius: BorderRadius.circular(9),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              children: [
                Expanded(
                  child: dateOfBirth == null
                      ? AppText(
                          'Select date',
                          style: white(13, c: Colors.white54),
                        )
                      : Text(formatDate(dateOfBirth), style: white(13)),
                ),
                const Icon(Icons.calendar_today, size: 16, color: kCyan),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---- step 2 ----

  Widget _employmentStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _row(
          _field('Employer', employerController),
          _field('Job Title', jobTitleController),
        ),
        const SizedBox(height: 14),
        AppText(
          'Employment sector',
          style: white(11, w: FontWeight.bold, c: Colors.white70),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in _sectors.entries)
              ChoiceChip(
                label: AppText(
                  entry.value,
                  style: TextStyle(
                    color: sector == entry.key ? Colors.white : journeyText,
                    fontSize: 12,
                  ),
                ),
                selected: sector == entry.key,
                selectedColor: kBlue,
                backgroundColor: Colors.white.withValues(alpha: .08),
                onSelected: (_) => setState(() => sector = entry.key),
              ),
          ],
        ),
        const SizedBox(height: 14),
        _row(
          _field('Years at Current Job', yearsController, decimal: true),
          _salaryBox(),
        ),
        const SizedBox(height: 14),
        _ibanField(),
      ],
    );
  }

  Widget _salaryBox() {
    final has = (monthlyIncome ?? 0) > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          'Monthly salary',
          style: white(11, w: FontWeight.bold, c: Colors.white70),
        ),
        const SizedBox(height: 7),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .05),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_outline, size: 15, color: Colors.white38),
              const SizedBox(width: 8),
              Expanded(
                child: has
                    ? Text(formatSar(monthlyIncome), style: white(13))
                    : AppText('Not set', style: white(13, c: Colors.white54)),
              ),
              TextButton(
                onPressed: () async {
                  await Navigator.pushNamed(context, '/borrowerProfile');
                  await _reloadIncome();
                },
                child: AppText(
                  'Update profile',
                  style: const TextStyle(color: kCyan, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _ibanField() {
    final value = normalizeIban(ibanController.text);
    final valid = saudiIban.hasMatch(value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          'Salary account IBAN',
          style: white(11, w: FontWeight.bold, c: Colors.white70),
        ),
        const SizedBox(height: 7),
        if (!ibanEditing && valid)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Colors.greenAccent,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      maskIban(value),
                      style: white(13, w: FontWeight.w600),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: tr('Edit'),
                  onPressed: () => setState(() => ibanEditing = true),
                  icon: const Icon(Icons.edit, size: 18, color: kCyan),
                ),
              ],
            ),
          )
        else
          Focus(
            onFocusChange: (hasFocus) {
              if (!hasFocus &&
                  saudiIban.hasMatch(normalizeIban(ibanController.text))) {
                setState(() => ibanEditing = false);
              }
            },
            child: TextField(
              controller: ibanController,
              maxLength: 29,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              enableSuggestions: false,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 ]')),
              ],
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (saudiIban.hasMatch(normalizeIban(ibanController.text))) {
                  setState(() => ibanEditing = false);
                }
              },
              style: white(13),
              decoration: _inputDecoration(
                hint: 'SA0000000000000000000000',
                error: value.isNotEmpty && !valid && value.length >= 24
                    ? tr(
                        'IBAN must be SA followed by 22 digits (24 characters).',
                      )
                    : null,
              ),
            ),
          ),
        const SizedBox(height: 4),
        AppText(
          'SA followed by 22 digits (24 characters). The financing is paid into this account.',
          style: white(10, c: Colors.white38),
        ),
      ],
    );
  }

  // ---- step 3 ----

  Widget _documentsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppText(
          'PDF, JPG or PNG, up to 5 MB each.',
          style: white(11, c: Colors.white54),
        ),
        const SizedBox(height: 12),
        for (final category in _docCategories) ...[
          _documentCard(category, editable: true),
          const SizedBox(height: 12),
        ],
        if (_otherDocuments.isNotEmpty) _otherDocumentsList(),
      ],
    );
  }

  Widget _statusChip(_DocStatus status) {
    switch (status) {
      case _DocStatus.missing:
        return const StatusChip(
          label: 'Missing',
          color: Colors.white54,
          icon: Icons.radio_button_unchecked,
        );
      case _DocStatus.uploaded:
        return const StatusChip(
          label: 'Uploaded',
          color: kCyan,
          icon: Icons.cloud_done_outlined,
        );
      case _DocStatus.accepted:
        return const StatusChip(
          label: 'Accepted',
          color: Colors.greenAccent,
          icon: Icons.check_circle,
        );
      case _DocStatus.needsReupload:
        return const StatusChip(
          label: 'Needs re-upload',
          color: Colors.orangeAccent,
          icon: Icons.refresh,
        );
    }
  }

  Widget _documentCard(String category, {required bool editable}) {
    final status = _statusFor(category);
    final existing = _existingFor(category);
    final waiting = _pendingFor(category);

    final borderColor = switch (status) {
      _DocStatus.missing => Colors.white24,
      _DocStatus.uploaded => kCyan.withValues(alpha: .5),
      _DocStatus.accepted => Colors.greenAccent.withValues(alpha: .5),
      _DocStatus.needsReupload => Colors.orangeAccent.withValues(alpha: .6),
    };

    return InkWell(
      onTap: editable ? () => _pickFile(category) : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  status == _DocStatus.missing
                      ? Icons.upload_file
                      : Icons.description_outlined,
                  color: kCyan,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppText(
                    category,
                    style: white(14, w: FontWeight.bold),
                  ),
                ),
                _statusChip(status),
              ],
            ),
            if (refused[category] != null) ...[
              const SizedBox(height: 8),
              AppText(
                refused[category]!,
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 11,
                ),
              ),
            ],
            for (final doc in existing)
              _fileLine(
                doc.name,
                Icons.cloud_done_outlined,
                actionLabel: 'Open',
                onAction: () => _openDocument(doc),
              ),
            for (final doc in waiting)
              _fileLine(
                doc.name,
                Icons.insert_drive_file_outlined,
                actionLabel: 'Remove',
                onAction: () => setState(() => pending.remove(doc)),
              ),
            if (editable) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: kCyan.withValues(alpha: .06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kCyan.withValues(alpha: .25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add, color: kCyan, size: 18),
                    const SizedBox(width: 6),
                    AppText(
                      existing.isEmpty && waiting.isEmpty
                          ? 'Tap to choose a file'
                          : 'Add another file',
                      style: const TextStyle(color: kCyan, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _fileLine(
    String name,
    IconData icon, {
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white54),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: white(12),
            ),
          ),
          TextButton(onPressed: onAction, child: AppText(actionLabel)),
        ],
      ),
    );
  }

  Widget _otherDocumentsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppText('Other documents', style: white(13, w: FontWeight.bold)),
        for (final doc in _otherDocuments)
          _fileLine(
            doc.name,
            Icons.cloud_done_outlined,
            actionLabel: 'Open',
            onAction: () => _openDocument(doc),
          ),
      ],
    );
  }

  // ---- step 4 ----

  Widget _reviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ..._summary(editLinks: true, maskSensitive: false),
        const SizedBox(height: 16),
        AppText('Consents', style: white(14, w: FontWeight.bold)),
        const SizedBox(height: 6),
        _consent(
          'I consent to a credit-bureau check (simulated)',
          consentBureau,
          (v) => setState(() => consentBureau = v),
        ),
        _consent(
          'The information I gave is accurate',
          consentAccurate,
          (v) => setState(() => consentAccurate = v),
        ),
        _consent(
          'I understand this is a simulation',
          consentSimulation,
          (v) => setState(() => consentSimulation = v),
        ),
      ],
    );
  }

  Widget _consent(String text, bool value, ValueChanged<bool> onChanged) {
    return CheckboxListTile(
      value: value,
      onChanged: (v) => onChanged(v ?? false),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      activeColor: kBlue,
      side: const BorderSide(color: Colors.white54),
      title: AppText(text, style: white(12)),
    );
  }

  List<Widget> _summary({
    required bool editLinks,
    required bool maskSensitive,
  }) {
    final id = nationalIdController.text.trim();
    final iban = normalizeIban(ibanController.text);

    String maskId(String v) => v.length < 4
        ? v
        : '${v.substring(0, 1)}••••••${v.substring(v.length - 3)}';

    Widget group(String title, int stepIndex, List<Widget> rows) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .04),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: AppText(title, style: white(13, w: FontWeight.bold)),
                ),
                if (editLinks)
                  TextButton(
                    onPressed: () => setState(() => step = stepIndex),
                    child: AppText(
                      'Edit',
                      style: const TextStyle(color: kCyan),
                    ),
                  ),
              ],
            ),
            ...rows,
          ],
        ),
      );
    }

    final docCount = (application?.documents.length ?? 0) + pending.length;

    return [
      group('Identity', 0, [
        InfoRow('Full Name', nameController.text.trim()),
        InfoRow('National ID / Iqama Number', maskSensitive ? maskId(id) : id),
        InfoRow('Date of birth', formatDate(dateOfBirth)),
        InfoRow('City', cityController.text.trim(), translateValue: true),
        InfoRow(
          'Identity check',
          _identityVerified ? 'Verified (simulated)' : 'Not verified',
          translateValue: true,
        ),
      ]),
      group('Employment & income', 1, [
        InfoRow('Employer', employerController.text.trim()),
        InfoRow(
          'Employment sector',
          sector == null ? '-' : _sectors[sector]!,
          translateValue: true,
        ),
        InfoRow(
          'Job Title',
          jobTitleController.text.trim().isEmpty
              ? '-'
              : jobTitleController.text.trim(),
        ),
        InfoRow(
          'Years at Current Job',
          yearsController.text.trim().isEmpty
              ? '-'
              : yearsController.text.trim(),
        ),
        InfoRow(
          'Monthly salary',
          (monthlyIncome ?? 0) > 0 ? formatSar(monthlyIncome) : '-',
        ),
        InfoRow('Salary account IBAN', iban.isEmpty ? '-' : maskIban(iban)),
      ]),
      group('Documents', 2, [
        for (final c in _docCategories)
          InfoRow(c, _docLabel(_statusFor(c)), translateValue: true),
        InfoRow('Files', '$docCount'),
      ]),
    ];
  }

  String _docLabel(_DocStatus s) => switch (s) {
    _DocStatus.missing => 'Missing',
    _DocStatus.uploaded => 'Uploaded',
    _DocStatus.accepted => 'Accepted',
    _DocStatus.needsReupload => 'Needs re-upload',
  };

  // ---- read-only (submitted / approved / rejected) ----

  List<Widget> _readOnly() {
    final app = application!;

    return [
      _statusCard(app),
      if (app.status == 'approved') ...[
        const SizedBox(height: 14),
        SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: kBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FinancingStatusScreen(request: widget.request),
              ),
            ),
            icon: const Icon(Icons.arrow_forward),
            label: AppText(
              'Continue to your financing offer',
              style: white(13, w: FontWeight.bold),
            ),
          ),
        ),
      ],
      const SizedBox(height: 16),
      SectionCard(
        title: 'Your Information',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _summary(editLinks: false, maskSensitive: true),
        ),
      ),
      const SizedBox(height: 16),
      SectionCard(
        title: 'Documents',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final category in _docCategories) ...[
              _documentCard(category, editable: false),
              const SizedBox(height: 10),
            ],
            if (_otherDocuments.isNotEmpty) _otherDocumentsList(),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _contactCard(),
    ];
  }

  Widget _statusCard(LoanApplicationData app) {
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
            'The bank approved your application. Your final financing offer will appear here.';
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

    return SectionCard(
      accent: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: AppText(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AppText(message, style: white(12, c: Colors.white70)),
          if (app.lenderMessage.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .06),
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
                    style: TextStyle(color: journeyText, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _contactCard() {
    final phone = contact?.phone ?? '';
    final bank = tr(contact?.bankName ?? widget.request.bankName);

    return SectionCard(
      child: Row(
        children: [
          const Icon(Icons.support_agent, color: kCyan, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  'Questions? Call the bank',
                  style: white(15, w: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  phone.isEmpty
                      ? '$bank ${tr('has not added a phone number yet.')}'
                      : '$bank • $phone',
                  style: white(11, c: Colors.white54),
                ),
              ],
            ),
          ),
          if (phone.isNotEmpty)
            IconButton.filled(
              tooltip: tr('Call'),
              style: IconButton.styleFrom(backgroundColor: Colors.green),
              onPressed: _callBank,
              icon: const Icon(Icons.call, color: Colors.white, size: 18),
            ),
        ],
      ),
    );
  }

  // ---- form helpers ----

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

  InputDecoration _inputDecoration({String? hint, String? error}) {
    return InputDecoration(
      counterText: '',
      hintText: hint,
      hintStyle: white(12, c: Colors.white38),
      errorText: error,
      filled: true,
      fillColor: Colors.white.withValues(alpha: .10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    bool digitsOnly = false,
    bool decimal = false,
    int? maxLength,
    String? hint,
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
          maxLength: maxLength,
          onChanged: (_) => setState(() {}),
          keyboardType: digitsOnly
              ? TextInputType.number
              : decimal
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          inputFormatters: digitsOnly
              ? [FilteringTextInputFormatter.digitsOnly]
              : decimal
              ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
              : null,
          style: white(13),
          decoration: _inputDecoration(hint: hint),
        ),
      ],
    );
  }
}
