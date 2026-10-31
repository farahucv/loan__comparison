import 'package:flutter/material.dart';
import '../services/error_messages.dart';

import '../models/app_settings.dart';
import '../models/financing.dart';
import '../services/financing_service.dart';
import '../services/loan_application_service.dart';
import '../services/loan_request_service.dart';
import '../services/money_format.dart';

import 'borrower_ui.dart';
import 'final_offer_summary.dart';
import 'journey_navigation.dart';
import 'journey_ui.dart' show bankLogoFor;

class RequestStatusScreen extends StatefulWidget {
  const RequestStatusScreen({super.key});

  @override
  State<RequestStatusScreen> createState() => _RequestStatusScreenState();
}

class _RequestStatusScreenState extends State<RequestStatusScreen> {
  final LoanRequestService _requestService = LoanRequestService();

  final LoanApplicationService _applicationService = LoanApplicationService();

  final FinancingService _financingService = FinancingService();

  List<BorrowerRequestData> requests = [];

  // request id -> where that request is in the financing journey
  Map<String, BorrowerJourney> journeys = {};

  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  String? _bankLogo(String bankName) => bankLogoFor(bankName);

  /// Falls back to the application status only, e.g. when the financing
  /// tables are not reachable.
  Future<Map<String, BorrowerJourney>> _loadJourneys(
    List<BorrowerRequestData> data,
  ) async {
    final requestStatuses = {
      for (final r in data) r.id: r.status.toLowerCase().trim(),
    };

    try {
      return await _financingService.getBorrowerJourneys(requestStatuses);
    } catch (_) {
      Map<String, String> applications = {};

      try {
        applications = await _applicationService.getBorrowerStatuses();
      } catch (_) {
        // Keep the list working.
      }

      return {
        for (final entry in requestStatuses.entries)
          entry.key: BorrowerJourney(
            requestStatus: entry.value,
            applicationStatus: applications[entry.key],
          ),
      };
    }
  }

  Future<void> _loadRequests() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final data = await _requestService.getBorrowerRequests();
      final loadedJourneys = await _loadJourneys(data);

      if (!mounted) return;

      setState(() {
        requests = data;
        journeys = loadedJourneys;
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

  @override
  Widget build(BuildContext context) {
    return BorrowerShell(
      active: 2,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 38),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            'Request Status',
                            style: white(28, w: FontWeight.w900),
                          ),
                          const SizedBox(height: 5),
                          AppText(
                            'Track your submitted loan requests.',
                            style: white(12, c: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: AppSettings.instance.tr('Refresh'),
                      onPressed: _loadRequests,
                      icon: const Icon(Icons.refresh, color: Colors.white),
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                _buildContent(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (errorMessage != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: panel(),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 45),
            const SizedBox(height: 12),
            AppText(
              'Unable to load requests.',
              style: white(17, w: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 15),
            ElevatedButton(
              onPressed: _loadRequests,
              child: AppText('Try Again'),
            ),
          ],
        ),
      );
    }

    if (requests.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(34),
        decoration: panel(),
        child: Column(
          children: [
            const Icon(Icons.assignment_outlined, color: kCyan, size: 48),
            const SizedBox(height: 12),
            AppText(
              'No submitted requests yet.',
              style: white(17, w: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            AppText(
              'Choose a loan offer and submit it to track it here.',
              textAlign: TextAlign.center,
              style: white(11, c: Colors.white54),
            ),
          ],
        ),
      );
    }

    return Column(
      children: requests
          .map(
            (request) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _requestCard(request),
            ),
          )
          .toList(),
    );
  }

  Widget _requestCard(BorrowerRequestData request) {
    final status = request.status.toLowerCase().trim();

    final logo = _bankLogo(request.bankName);

    final hasEligibility =
        request.eligibilityScore != null &&
        request.monthlyInstallment != null &&
        request.installmentRatio != null &&
        request.dtiRatio != null &&
        request.eligibilityClassification != null;

    // Once the bank has issued a final offer, its numbers replace the
    // preliminary estimate made at request time.
    final journeyOffer = _journeyFor(request).offer;
    final finalOffer = isFinalOffer(journeyOffer) ? journeyOffer : null;

    Color statusColor;
    IconData statusIcon;
    String statusTitle;

    if (status == 'approved') {
      statusColor = Colors.greenAccent;
      statusIcon = Icons.check_circle;
      statusTitle = 'APPROVED';
    } else if (status == 'rejected') {
      statusColor = Colors.redAccent;
      statusIcon = Icons.cancel;
      statusTitle = 'REJECTED';
    } else {
      statusColor = Colors.amberAccent;
      statusIcon = Icons.schedule;
      statusTitle = 'PENDING';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 55,
                height: 50,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: logo != null
                    ? Image.asset(
                        logo,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) {
                          return const Icon(
                            Icons.account_balance,
                            color: kBlue,
                          );
                        },
                      )
                    : const Icon(Icons.account_balance, color: kBlue),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      request.bankName,
                      style: white(17, w: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    AppText(request.offerName, style: white(11, c: kCyan)),
                    const SizedBox(height: 3),
                    AppText(
                      '${AppSettings.instance.tr(request.loanType)} • ${requestedApprovedLine(request.requestedAmount, finalOffer)}',
                      style: white(10, c: Colors.white54),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 16),
                    const SizedBox(width: 6),
                    AppText(
                      statusTitle,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (finalOffer != null) ...[
            const SizedBox(height: 18),
            FinalOfferSummary(
              offer: finalOffer,
              requestedAmount: request.requestedAmount,
            ),
          ],

          if (hasEligibility) ...[
            const SizedBox(height: 12),

            InitialEstimateSection(
              initiallyExpanded: finalOffer == null,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .08),
                  ),
                ),
                child: Column(
                  children: [
                    LayoutBuilder(
                      builder: (_, box) {
                        final items = [
                          _eligibilityMetric(
                            'Eligibility Score',
                            '${request.eligibilityScore!.toStringAsFixed(0)}%',
                          ),
                          _eligibilityMetric(
                            'Classification',
                            request.eligibilityClassification!,
                          ),
                        ];

                        if (box.maxWidth < 500) {
                          return Column(
                            children: [
                              for (final item in items)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: item,
                                  ),
                                ),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: items[0]),
                            const SizedBox(width: 10),
                            Expanded(child: items[1]),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 10),

                    LayoutBuilder(
                      builder: (_, box) {
                        final items = [
                          _eligibilityMetric(
                            'Monthly Installment',
                            formatSar(request.monthlyInstallment!, decimals: 2),
                          ),
                          _eligibilityMetric(
                            'DTI',
                            '${request.dtiRatio!.toStringAsFixed(2)}%',
                          ),
                          _eligibilityMetric(
                            'Installment Ratio',
                            '${request.installmentRatio!.toStringAsFixed(2)}%',
                          ),
                        ];

                        if (box.maxWidth < 650) {
                          return Column(
                            children: [
                              for (final item in items)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: item,
                                  ),
                                ),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: items[0]),
                            const SizedBox(width: 10),
                            Expanded(child: items[1]),
                            const SizedBox(width: 10),
                            Expanded(child: items[2]),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 10),

                    AppText(
                      'This result is a preliminary suitability indicator and does not represent final loan approval.',
                      style: white(9, c: Colors.white54),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 18),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withValues(alpha: .25)),
            ),
            child: AppText(
              _statusMessage(request),
              style: white(11, c: Colors.white70),
            ),
          ),

          const SizedBox(height: 14),

          _journeySection(request),
        ],
      ),
    );
  }

  BorrowerJourney _journeyFor(BorrowerRequestData request) =>
      journeys[request.id] ??
      BorrowerJourney(requestStatus: request.status.toLowerCase().trim());

  /// Current stage, a 6-step progress strip and one Continue button.
  Widget _journeySection(BorrowerRequestData request) {
    final journey = _journeyFor(request);
    final info = stageInfo(journey.stage);
    final canContinue = journeyScreen(request, journey) != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(info.icon, color: info.color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: AppText(info.label, style: white(12, w: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 1; i <= journeySteps.length; i++)
              Expanded(
                child: Container(
                  height: 5,
                  margin: const EdgeInsetsDirectional.only(end: 4),
                  decoration: BoxDecoration(
                    color: i <= info.step
                        ? info.color
                        : Colors.white.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '${AppSettings.instance.tr('Step')} ${info.step} ${AppSettings.instance.tr('of')} ${journeySteps.length} — ${AppSettings.instance.tr(journeySteps[info.step - 1])}',
          style: white(10, c: Colors.white54),
        ),
        if (canContinue) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: kBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => _continue(request, journey),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: AppText('Continue', style: white(13, w: FontWeight.bold)),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _continue(
    BorrowerRequestData request,
    BorrowerJourney journey,
  ) async {
    await openJourney(context, request, journey);

    if (!mounted) return;

    await _loadRequests();
  }

  Widget _eligibilityMetric(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: panel(radius: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(label, style: white(9, c: Colors.white38)),
          const SizedBox(height: 3),
          AppText(value, style: white(12, w: FontWeight.bold)),
        ],
      ),
    );
  }

  String _statusMessage(BorrowerRequestData request) {
    final status = request.status.toLowerCase().trim();

    if (status == 'approved') {
      return 'Your loan request has been approved by the lender.';
    }

    if (status == 'rejected') {
      final reason = request.rejectionReason?.trim() ?? '';

      if (reason.isNotEmpty) {
        return '${AppSettings.instance.tr('Your loan request was not approved by the lender.')}\n${AppSettings.instance.tr('Reason:')} $reason';
      }

      return 'Your loan request was not approved by the lender.';
    }

    return 'Your request is currently under review by the lender.';
  }
}
