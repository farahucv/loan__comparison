import 'dart:async';

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
import 'journey_ui.dart';

/// Lender: issue the final financing offer (Key Facts Statement) for an
/// approved application. The preview uses the database's own maths
/// (rushd_calc_financing); rushd_issue_offer recalculates and checks
/// everything, so its result is final.
class LenderIssueOfferScreen extends StatefulWidget {
  final LenderRequestData request;
  final LoanApplicationData application;

  /// 1 for the first offer, 2+ after a declined / expired / withdrawn one.
  final int version;

  const LenderIssueOfferScreen({
    super.key,
    required this.request,
    required this.application,
    this.version = 1,
  });

  @override
  State<LenderIssueOfferScreen> createState() => _LenderIssueOfferScreenState();
}

class _LenderIssueOfferScreenState extends State<LenderIssueOfferScreen> {
  final FinancingService _service = FinancingService();

  final principalController = TextEditingController();
  final rateController = TextEditingController();
  final feeController = TextEditingController(text: '0');

  FinancingSettings settings = const FinancingSettings();
  LoanOfferTerms? offerTerms;

  String rateType = 'reducing';
  int termMonths = 36;
  int validDays = 7;

  bool isLoading = true;
  bool isIssuing = false;
  String? loadError;

  // Live preview
  Timer? _debounce;
  int _previewSeq = 0;
  bool isPreviewing = false;
  FinancingQuote? preview;
  double? feeCap;
  String? previewError;

  double get _principal =>
      double.tryParse(principalController.text.trim()) ?? 0;
  double get _rate => double.tryParse(rateController.text.trim()) ?? -1;
  double get _fee => double.tryParse(feeController.text.trim()) ?? -1;

  double get _income => widget.request.monthlyIncome;
  double get _existing => widget.request.existingDebts;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    principalController.dispose();
    rateController.dispose();
    feeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      isLoading = true;
      loadError = null;
    });

    try {
      final loadedSettings = await _service.getSettings();
      final terms = await _service.getLoanOfferTerms(widget.request.id);

      if (!mounted) return;

      final minTerm = loadedSettings.minTermMonths;
      final maxTerm = loadedSettings.maxTermMonths;
      final offerTerm = terms?.maxTermMonths ?? 36;

      setState(() {
        settings = loadedSettings;
        offerTerms = terms;
        principalController.text = _plain(widget.request.requestedAmount);
        rateController.text = _plain(terms?.interestRate ?? 5);
        termMonths = offerTerm.clamp(minTerm, maxTerm);
        validDays = 7.clamp(1, loadedSettings.maxOfferValidDays);
        isLoading = false;
      });

      _schedulePreview(immediate: true);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        loadError = friendlyError(error);
      });
    }
  }

  String _plain(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  // =========================
  // PREVIEW
  // =========================

  void _schedulePreview({bool immediate = false}) {
    _debounce?.cancel();
    _debounce = Timer(
      immediate ? Duration.zero : const Duration(milliseconds: 450),
      _runPreview,
    );
  }

  Future<void> _runPreview() async {
    final principal = _principal;
    final rate = _rate;
    final fee = _fee;

    if (principal <= 0 || rate < 0 || fee < 0) {
      setState(() {
        preview = null;
        previewError =
            'Enter the amount, profit rate and admin fee to see the preview.';
      });
      return;
    }

    final seq = ++_previewSeq;

    setState(() => isPreviewing = true);

    try {
      final cap = await _service.adminFeeCap(principal);
      final quote = await _service.previewOffer(
        principal: principal,
        annualProfitRate: rate,
        rateType: rateType,
        termMonths: termMonths,
        adminFee: fee,
      );

      // Ignore answers that arrive after a newer request.
      if (!mounted || seq != _previewSeq) return;

      setState(() {
        feeCap = cap;
        preview = quote;
        previewError = null;
        isPreviewing = false;
      });
    } catch (error) {
      if (!mounted || seq != _previewSeq) return;

      setState(() {
        preview = null;
        previewError = friendlyError(error);
        isPreviewing = false;
      });
    }
  }

  /// Warnings the database will also enforce (it has the final say).
  List<String> get _warnings {
    final w = <String>[];
    final principal = _principal;

    if (principal > widget.request.requestedAmount) {
      w.add(
        '${tr('The amount is more than the borrower requested')} (${formatSar(widget.request.requestedAmount, decimals: 0)}).',
      );
    }

    final max = offerTerms?.maxAmount ?? 0;

    if (max > 0 && principal > max) {
      w.add(
        '${tr('The amount is more than the maximum of your loan offer')} (${formatSar(max, decimals: 0)}).',
      );
    }

    if (feeCap != null && _fee > feeCap!) {
      w.add('${tr('The admin fee is above the cap of')} ${formatSar(feeCap)}.');
    }

    return w;
  }

  // =========================
  // ISSUE
  // =========================

  Future<void> _issue() async {
    if (_principal <= 0 || _rate < 0 || _fee < 0) {
      showError(
        context,
        'Please enter a valid amount, profit rate and admin fee.',
      );
      return;
    }

    setState(() => isIssuing = true);

    try {
      final offer = await _service.issueOffer(
        applicationId: widget.application.id,
        principal: _principal,
        annualProfitRate: _rate,
        rateType: rateType,
        termMonths: termMonths,
        adminFee: _fee,
        validDays: validDays,
      );

      if (!mounted) return;

      showInfo(
        context,
        '${tr('Offer issued to the borrower.')} ${tr('Monthly installment')}: ${formatSar(offer.monthlyInstallment)}',
      );

      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) showError(context, friendlyError(error));
    } finally {
      if (mounted) setState(() => isIssuing = false);
    }
  }

  // =========================
  // UI
  // =========================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: rushdBackground(),
        child: SafeArea(
          child: JourneyPage(
            maxWidth: 760,
            children: [
              JourneyHeader(
                title: widget.version > 1
                    ? '${tr('Issue new offer')} (${tr('version')} ${widget.version})'
                    : 'Issue final offer',
                subtitle:
                    '${widget.request.borrowerName} • ${tr(widget.request.loanType)} • ${formatSar(widget.request.requestedAmount, decimals: 0)}',
              ),
              if (isLoading)
                const LoadingView()
              else if (loadError != null)
                ErrorView(
                  title: 'Unable to load the offer settings.',
                  message: loadError!,
                  onRetry: _load,
                )
              else ...[
                _form(),
                const SizedBox(height: 16),
                _previewCard(),
                const SizedBox(height: 16),
                _dbrCard(),
                const SizedBox(height: 16),
                const DemoNote(
                  'The preview uses the same formulas as the database, but only the database result is final. The offer is a simulation.',
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kBlue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.white12,
                    ),
                    onPressed: isIssuing ? null : _issue,
                    icon: isIssuing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send),
                    label: AppText(
                      'Issue offer',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _form() {
    final minTerm = settings.minTermMonths;
    final maxTerm = settings.maxTermMonths;

    return SectionCard(
      title: 'Offer terms',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _row(
            _number(
              'Financed amount (SAR)',
              principalController,
              helper:
                  '${tr('Requested')}: ${formatSar(widget.request.requestedAmount, decimals: 0)}',
            ),
            _number(
              'Annual profit rate (%)',
              rateController,
              helper: offerTerms == null
                  ? null
                  : '${tr('Your loan offer')}: ${formatPercent(offerTerms!.interestRate)}',
            ),
          ),
          const SizedBox(height: 16),
          AppText(
            'Rate type',
            style: white(11, w: FontWeight.bold, c: Colors.white70),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: 'reducing',
                label: AppText('Reducing balance'),
              ),
              ButtonSegment(value: 'flat', label: AppText('Flat rate')),
            ],
            selected: {rateType},
            onSelectionChanged: (s) {
              setState(() => rateType = s.first);
              _schedulePreview();
            },
          ),
          if (rateType == 'flat') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.amber, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: AppText(
                    'Flat rate: APR is higher than the quoted rate.',
                    style: const TextStyle(color: Colors.amber, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          _sliderLabel('Term', '$termMonths ${tr('months')}'),
          Slider(
            value: termMonths.toDouble(),
            min: minTerm.toDouble(),
            max: maxTerm.toDouble(),
            divisions: (maxTerm - minTerm).clamp(1, 1000),
            label: '$termMonths',
            onChanged: (v) {
              setState(() => termMonths = v.round());
              _schedulePreview();
            },
          ),
          Text(
            '${tr('Allowed')}: $minTerm–$maxTerm ${tr('months')} (${tr('SAMA consumer finance limit')})',
            style: white(10, c: Colors.white38),
          ),
          const SizedBox(height: 16),
          _row(
            _number(
              'Admin fee (SAR)',
              feeController,
              helper: feeCap == null
                  ? null
                  : '${tr('Maximum')}: ${formatSar(feeCap)}',
              trailing: feeCap == null
                  ? null
                  : TextButton(
                      onPressed: () {
                        feeController.text = feeCap!.toStringAsFixed(2);
                        _schedulePreview(immediate: true);
                      },
                      child: AppText(
                        'Use maximum',
                        style: const TextStyle(color: kCyan, fontSize: 12),
                      ),
                    ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sliderLabel('Offer valid for', '$validDays ${tr('days')}'),
                Slider(
                  value: validDays.toDouble(),
                  min: 1,
                  max: settings.maxOfferValidDays.toDouble(),
                  divisions: (settings.maxOfferValidDays - 1).clamp(1, 1000),
                  label: '$validDays',
                  onChanged: (v) => setState(() => validDays = v.round()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewCard() {
    final q = preview;
    final warnings = _warnings;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: AppText(
                  'Live preview',
                  style: white(16, w: FontWeight.bold),
                ),
              ),
              if (isPreviewing)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (q == null)
            AppText(
              previewError ?? 'Calculating…',
              style: TextStyle(
                color: previewError == null
                    ? Colors.white54
                    : Colors.orangeAccent,
                fontSize: 12,
              ),
            )
          else ...[
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _metric(
                  'Monthly installment',
                  formatSar(q.monthlyInstallment),
                  big: true,
                ),
                _metric('Annual percentage rate (APR)', formatPercent(q.apr)),
                _metric('Total profit', formatSar(q.totalProfit)),
                _metric('Total repayable', formatSar(q.totalRepayable)),
                _metric(
                  'Paid to the borrower',
                  formatSar(_principal - (_fee < 0 ? 0 : _fee)),
                ),
              ],
            ),
          ],
          for (final w in warnings) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber,
                  color: Colors.orangeAccent,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    w,
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _dbrCard() {
    final q = preview;

    if (_income <= 0) {
      return SectionCard(
        title: 'Debt Burden Ratio',
        child: AppText(
          'The borrower has no monthly income in their profile, so the Debt Burden Ratio cannot be checked. The database will refuse the offer.',
          style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
        ),
      );
    }

    final installment = q?.monthlyInstallment ?? 0;
    final salaryDbr = installment / _income * 100;
    final totalDbr = (_existing + installment) / _income * 100;
    final totalCap = settings.totalDbrCapFor(_income);

    return SectionCard(
      title: 'Debt Burden Ratio',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${tr('Monthly income')}: ${formatSar(_income)} • ${tr('Existing obligations')}: ${formatSar(_existing)}',
            style: white(11, c: Colors.white54),
          ),
          const SizedBox(height: 14),
          DbrBar(
            label: 'New installment / income',
            value: salaryDbr,
            cap: settings.dbrSalaryDeductionCapPct,
          ),
          const SizedBox(height: 14),
          DbrBar(
            label: 'All obligations / income',
            value: totalDbr,
            cap: totalCap,
          ),
          const SizedBox(height: 10),
          AppText(
            'Green: under 80% of the limit. Amber: close to the limit. Red: over the limit — the database will refuse the offer.',
            style: white(10, c: Colors.white38),
          ),
        ],
      ),
    );
  }

  // ---- helpers ----

  Widget _metric(String label, String value, {bool big = false}) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppText(label, style: white(10, c: Colors.white54)),
          const SizedBox(height: 4),
          Text(value, style: white(big ? 20 : 14, w: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _sliderLabel(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: AppText(
            label,
            style: white(11, w: FontWeight.bold, c: Colors.white70),
          ),
        ),
        Text(value, style: white(13, w: FontWeight.bold)),
      ],
    );
  }

  Widget _row(Widget a, Widget b) {
    return LayoutBuilder(
      builder: (_, box) {
        if (box.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [a, const SizedBox(height: 14), b],
          );
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

  Widget _number(
    String label,
    TextEditingController controller, {
    String? helper,
    Widget? trailing,
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
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          onChanged: (_) {
            setState(() {});
            _schedulePreview();
          },
          style: white(14, w: FontWeight.w600),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withValues(alpha: .10),
            suffixIcon: trailing,
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
        if (helper != null) ...[
          const SizedBox(height: 4),
          Text(helper, style: white(10, c: Colors.white38)),
        ],
      ],
    );
  }
}

/// A Debt Burden Ratio bar against its cap:
/// green under 80% of the cap, amber up to the cap, red above.
class DbrBar extends StatelessWidget {
  final String label;
  final double value;
  final double cap;

  const DbrBar({
    super.key,
    required this.label,
    required this.value,
    required this.cap,
  });

  @override
  Widget build(BuildContext context) {
    final color = value > cap
        ? Colors.redAccent
        : value >= cap * .8
        ? Colors.amber
        : Colors.greenAccent;

    // The bar shows 0 .. 1.25 x cap, with a marker at the cap.
    final scale = cap * 1.25;
    final fill = scale <= 0 ? 0.0 : (value / scale).clamp(0.0, 1.0);
    final capAt = scale <= 0 ? 0.0 : (cap / scale);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: AppText(label, style: white(12, w: FontWeight.w600)),
            ),
            Text(
              '${formatPercent(value)} / ${formatPercent(cap)}',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (_, box) => Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              Container(
                height: 10,
                width: box.maxWidth * fill,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              PositionedDirectional(
                start: box.maxWidth * capAt - 1,
                top: -2,
                child: Container(width: 2, height: 14, color: Colors.white70),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
