import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/borrower_app_state.dart';
import '../models/loan_offer.dart';

import '../services/eligibility_service.dart';
import '../services/loan_request_service.dart';

import 'borrower_ui.dart';

class LoanOfferDetailsScreen extends StatefulWidget {
  const LoanOfferDetailsScreen({super.key});

  @override
  State<LoanOfferDetailsScreen> createState() => _LoanOfferDetailsScreenState();
}

class _LoanOfferDetailsScreenState extends State<LoanOfferDetailsScreen> {
  final LoanRequestService _requestService = LoanRequestService();
  final EligibilityService _eligibilityService = EligibilityService();

  bool isSubmitting = false;

  String? _bankLogo(String bankName) {
    final name = bankName.toLowerCase().trim();

    if (name.contains('rajhi')) {
      return 'assets/images/Alrajhi-Bank-Logo.png';
    }

    if (name.contains('riyad')) {
      return 'assets/images/Riyad-Bank-Logo.png';
    }

    if (name.contains('bilad')) {
      return 'assets/images/Albilad-Bank-Logo.png';
    }

    if (name.contains('national') ||
        name.contains('snb') ||
        name.contains('ahli')) {
      return 'assets/images/Saudi_National_Bank_Logo.png';
    }

    return null;
  }

  EligibilityResult? _calculateEligibility(
    LoanOffer offer,
    BorrowerAppState state,
  ) {
    final interestRate = double.tryParse(offer.interestRate);

    final termMonths = int.tryParse(offer.term);

    if (interestRate == null ||
        termMonths == null ||
        termMonths <= 0 ||
        interestRate < 0 ||
        state.income <= 0 ||
        state.amount <= 0 ||
        state.debts < 0) {
      return null;
    }

    try {
      return _eligibilityService.calculate(
        monthlyIncome: state.income,
        currentMonthlyObligations: state.debts,
        loanAmount: state.amount,
        annualInterestRate: interestRate,
        termMonths: termMonths,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _submitRequest(LoanOffer offer) async {
    final state = BorrowerAppState.instance;

    if (state.amount <= 0) {
      _showMessage('Requested amount is not available.', error: true);
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      await _requestService.submitRequest(
        offer: offer,
        requestedAmount: state.amount,
        loanType: state.loanType,
      );

      if (!mounted) return;

      state.selectBank(offer.bankName);

      _showMessage('Loan request submitted successfully.');

      Navigator.pushReplacementNamed(context, '/requestStatus');
    } catch (error) {
      if (!mounted) return;

      _showMessage('Error submitting request: $error', error: true);
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.redAccent : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final arguments = ModalRoute.of(context)?.settings.arguments;

    if (arguments == null || arguments is! LoanOffer) {
      return Scaffold(
        body: Container(
          decoration: rushdBackground(),
          child: Center(
            child: AppText(
              'Offer information is not available.',
              style: white(18, w: FontWeight.bold),
            ),
          ),
        ),
      );
    }

    final LoanOffer offer = arguments;
    final state = BorrowerAppState.instance;

    final eligibility = _calculateEligibility(offer, state);

    return BorrowerShell(
      active: 1,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 950),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.chevron_left,
                    color: Colors.white60,
                    size: 17,
                  ),
                  label: AppText(
                    'Back to Comparison',
                    style: white(11, c: Colors.white60),
                  ),
                ),

                const SizedBox(height: 10),

                LayoutBuilder(
                  builder: (context, box) {
                    final main = _mainOfferCard(offer, state, eligibility);

                    final side = _sideColumn(offer, eligibility);

                    if (box.maxWidth < 760) {
                      return Column(
                        children: [main, const SizedBox(height: 16), side],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: main),
                        const SizedBox(width: 16),
                        Expanded(child: side),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _mainOfferCard(
    LoanOffer offer,
    BorrowerAppState state,
    EligibilityResult? eligibility,
  ) {
    final logo = _bankLogo(offer.bankName);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 70,
                height: 58,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: logo != null
                    ? Image.asset(
                        logo,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) {
                          return const Icon(
                            Icons.account_balance,
                            color: kBlue,
                            size: 38,
                          );
                        },
                      )
                    : const Icon(Icons.account_balance, color: kBlue, size: 38),
              ),

              const Spacer(),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(.15),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: AppText(
                  'Available',
                  style: white(10, c: Colors.greenAccent),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          AppText(offer.bankName, style: white(26, w: FontWeight.w900)),

          const SizedBox(height: 4),

          AppText(
            offer.offerName,
            style: white(13, w: FontWeight.bold, c: kCyan),
          ),

          const SizedBox(height: 4),

          AppText(offer.loanType, style: white(10, c: Colors.white54)),

          const SizedBox(height: 22),

          LayoutBuilder(
            builder: (_, box) {
              final metrics = [
                metric('Interest Rate', '${offer.interestRate}%'),
                metric('Maximum Term', '${offer.term} months'),
                metric('Maximum Amount', 'SAR ${offer.amount}'),
              ];

              if (box.maxWidth < 600) {
                return Column(
                  children: [
                    for (final item in metrics)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SizedBox(width: double.infinity, child: item),
                      ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: metrics[0]),
                  const SizedBox(width: 10),
                  Expanded(child: metrics[1]),
                  const SizedBox(width: 10),
                  Expanded(child: metrics[2]),
                ],
              );
            },
          ),

          const SizedBox(height: 12),

          LayoutBuilder(
            builder: (_, box) {
              final items = [
                metric(
                  'Requested Amount',
                  'SAR ${state.amount.toStringAsFixed(0)}',
                ),
                metric(
                  'Monthly Income',
                  'SAR ${state.income.toStringAsFixed(0)}',
                ),
                metric('Loan Type', state.loanType),
              ];

              if (box.maxWidth < 600) {
                return Column(
                  children: [
                    for (final item in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SizedBox(width: double.infinity, child: item),
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

          const SizedBox(height: 20),

          AppText('Eligibility Analysis', style: white(15, w: FontWeight.bold)),

          const SizedBox(height: 10),

          if (eligibility != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: panel(radius: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (_, box) {
                      final items = [
                        metric(
                          'Eligibility Score',
                          '${eligibility.finalScore.toStringAsFixed(0)}%',
                        ),
                        metric('Classification', eligibility.classification),
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
                        metric(
                          'Monthly Installment',
                          'SAR ${eligibility.monthlyInstallment.toStringAsFixed(2)}',
                        ),
                        metric(
                          'DTI',
                          '${eligibility.dtiRatio.toStringAsFixed(1)}%',
                        ),
                        metric(
                          'Installment Ratio',
                          '${eligibility.installmentRatio.toStringAsFixed(1)}%',
                        ),
                      ];

                      if (box.maxWidth < 600) {
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

                  const SizedBox(height: 12),

                  AppText(
                    'This eligibility result is a preliminary suitability indicator and does not represent final loan approval.',
                    style: white(10, c: Colors.white60),
                  ),
                ],
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: panel(radius: 12),
              child: AppText(
                'Eligibility could not be calculated for this offer.',
                style: white(11, c: Colors.white60),
              ),
            ),

          const SizedBox(height: 20),

          AppText('Offer Details', style: white(15, w: FontWeight.bold)),

          const SizedBox(height: 10),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _feature('Financing offer from ${offer.bankName}'),
              _feature('Maximum term ${offer.term} months'),
              _feature('Maximum financing SAR ${offer.amount}'),
            ],
          ),

          const SizedBox(height: 22),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kBlue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: isSubmitting ? null : () => _submitRequest(offer),
              child: isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : AppText(
                      'Submit Request',
                      style: white(12, w: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sideColumn(LoanOffer offer, EligibilityResult? eligibility) {
    return Column(
      children: [
        _side('Contact', [offer.bankName, offer.email]),

        const SizedBox(height: 14),

        _side('Loan Offer', [
          offer.offerName,
          offer.loanType,
          'Interest Rate: ${offer.interestRate}%',
          'Maximum Term: ${offer.term} months',
        ]),

        if (eligibility != null) ...[
          const SizedBox(height: 14),

          _side('Eligibility', [
            'Score: ${eligibility.finalScore.toStringAsFixed(0)}%',
            'Classification: ${eligibility.classification}',
            'Monthly Installment: SAR ${eligibility.monthlyInstallment.toStringAsFixed(2)}',
            'DTI: ${eligibility.dtiRatio.toStringAsFixed(1)}%',
            'Installment Ratio: ${eligibility.installmentRatio.toStringAsFixed(1)}%',
          ]),
        ],
      ],
    );
  }

  Widget _feature(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: panel(radius: 9),
      child: AppText('• $text', style: white(10, c: Colors.white70)),
    );
  }

  Widget _side(String title, List<String> lines) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(title, style: white(16, w: FontWeight.w800)),

          const SizedBox(height: 12),

          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: AppText(line, style: white(10, c: Colors.white70)),
            ),
          ),
        ],
      ),
    );
  }
}
