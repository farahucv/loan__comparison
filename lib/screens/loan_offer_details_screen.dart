import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/borrower_app_state.dart';
import '../models/loan_offer.dart';

import '../services/loan_request_service.dart';

import 'borrower_ui.dart';

class LoanOfferDetailsScreen extends StatefulWidget {
  const LoanOfferDetailsScreen({super.key});

  @override
  State<LoanOfferDetailsScreen> createState() => _LoanOfferDetailsScreenState();
}

class _LoanOfferDetailsScreenState extends State<LoanOfferDetailsScreen> {
  final LoanRequestService _requestService = LoanRequestService();

  bool isSubmitting = false;

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
                    final main = _mainOfferCard(offer, state);

                    final side = _sideColumn(offer);

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

  Widget _mainOfferCard(LoanOffer offer, BorrowerAppState state) {
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
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.account_balance,
                  color: kBlue,
                  size: 38,
                ),
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
                      'Submit Loan Request Through Rushd',
                      style: white(12, w: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sideColumn(LoanOffer offer) {
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
