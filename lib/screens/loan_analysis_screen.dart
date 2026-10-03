import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/borrower_app_state.dart';
import '../models/loan_offer.dart';

import '../services/loan_offer_service.dart';

import 'borrower_ui.dart';

class LoanAnalysisScreen extends StatefulWidget {
  const LoanAnalysisScreen({super.key});

  @override
  State<LoanAnalysisScreen> createState() =>
      _LoanAnalysisScreenState();
}

class _LoanAnalysisScreenState extends State<LoanAnalysisScreen> {
  final LoanOfferService _offerService = LoanOfferService();

  List<LoanOffer> offers = [];

  bool isLoading = true;

  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

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

  Future<void> _loadOffers() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      final allOffers = await _offerService.getActiveOffers();

      final state = BorrowerAppState.instance;

      final filteredOffers = allOffers.where((offer) {
        final maxAmount = double.tryParse(offer.amount) ?? 0;

        final sameLoanType = offer.loanType == state.loanType;
        final enoughAmount = maxAmount >= state.amount;

        return sameLoanType && enoughAmount;
      }).toList();

      if (!mounted) return;

      setState(() {
        offers = filteredOffers;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = BorrowerAppState.instance;

    return BorrowerShell(
      active: 1,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 28,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1050),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (_, box) {
                    final title = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          'Your Loan Analysis',
                          style: white(
                            28,
                            w: FontWeight.w900,
                          ),
                        ),

                        const SizedBox(height: 6),

                        AppText(
                          'Showing available ${state.loanType.toLowerCase()} offers for your requested amount of SAR ${state.amount.toStringAsFixed(0)}.',
                          style: white(
                            12,
                            c: Colors.white54,
                          ),
                        ),
                      ],
                    );

                    if (box.maxWidth < 650) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          title,
                          const SizedBox(height: 14),
                          blueButton(
                            'Refresh Offers',
                            _loadOffers,
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: title),
                        const SizedBox(width: 16),
                        blueButton(
                          'Refresh Offers',
                          _loadOffers,
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 22),

                LayoutBuilder(
                  builder: (_, box) {
                    final items = [
                      metric(
                        'Monthly Income',
                        'SAR ${state.income.toStringAsFixed(0)}',
                      ),
                      metric(
                        'Monthly Expenses',
                        'SAR ${state.expenses.toStringAsFixed(0)}',
                      ),
                      metric(
                        'Requested Amount',
                        'SAR ${state.amount.toStringAsFixed(0)}',
                      ),
                    ];

                    if (box.maxWidth < 700) {
                      return Column(
                        children: [
                          for (final item in items)
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 12),
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
                        const SizedBox(width: 14),
                        Expanded(child: items[1]),
                        const SizedBox(width: 14),
                        Expanded(child: items[2]),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 18),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: panel(radius: 18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        color: kCyan,
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText(
                              'Rushd Loan Recommendations',
                              style: white(
                                15,
                                w: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 4),

                            AppText(
                              'Offers are retrieved from Rushd partner lenders and filtered according to your selected loan type and requested amount.',
                              style: white(
                                11,
                                c: Colors.white60,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                AppText(
                  'Available Offers',
                  style: white(
                    20,
                    w: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 14),

                if (isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (errorMessage != null)
                  _errorCard(errorMessage!)
                else if (offers.isEmpty)
                  _emptyCard(state)
                else
                  _offersGrid(context, offers),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _offersGrid(
    BuildContext context,
    List<LoanOffer> offers,
  ) {
    return LayoutBuilder(
      builder: (_, box) {
        if (box.maxWidth < 820) {
          return Column(
            children: [
              for (final offer in offers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _offerCard(
                    context,
                    offer,
                  ),
                ),
            ],
          );
        }

        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: offers
              .map(
                (offer) => SizedBox(
                  width: (box.maxWidth - 28) / 3,
                  child: _offerCard(
                    context,
                    offer,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _offerCard(
    BuildContext context,
    LoanOffer offer,
  ) {
    final logo = _bankLogo(offer.bankName);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: panel(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 42,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: logo != null
                    ? Image.asset(
                        logo,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) {
                          return const Icon(
                            Icons.account_balance,
                            color: kBlue,
                          );
                        },
                      )
                    : const Icon(
                        Icons.account_balance,
                        color: kBlue,
                      ),
              ),

              const Spacer(),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: kBlue.withOpacity(.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: AppText(
                  'Available',
                  style: white(
                    10,
                    c: kCyan,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          AppText(
            offer.bankName,
            style: white(
              17,
              w: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 3),

          AppText(
            offer.offerName,
            style: white(
              11,
              c: Colors.white60,
            ),
          ),

          const SizedBox(height: 3),

          AppText(
            offer.loanType,
            style: white(
              10,
              c: Colors.white54,
            ),
          ),

          const SizedBox(height: 15),

          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              _mini(
                'Rate',
                '${offer.interestRate}%',
              ),
              _mini(
                'Term',
                '${offer.term} months',
              ),
              _mini(
                'Max Amount',
                'SAR ${offer.amount}',
              ),
            ],
          ),

          const SizedBox(height: 14),

          AppText(
            'This offer matches your selected loan type and supports your requested amount.',
            style: white(
              10,
              c: Colors.white60,
            ),
          ),

          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            child: blueButton(
              'View Offer',
              () {
                BorrowerAppState.instance.selectBank(
                  offer.bankName,
                );

                Navigator.pushNamed(
                  context,
                  '/loanOfferDetails',
                  arguments: offer,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _mini(
    String label,
    String value,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          label,
          style: white(
            9,
            c: Colors.white38,
          ),
        ),
        AppText(
          value,
          style: white(
            11,
            w: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _emptyCard(
    BorrowerAppState state,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(35),
      decoration: panel(),
      child: Column(
        children: [
          const Icon(
            Icons.search_off_outlined,
            color: kCyan,
            size: 50,
          ),

          const SizedBox(height: 15),

          AppText(
            'No matching offers found.',
            style: white(
              17,
              w: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 7),

          AppText(
            'There are currently no active ${state.loanType.toLowerCase()} offers that support your requested amount of SAR ${state.amount.toStringAsFixed(0)}.',
            textAlign: TextAlign.center,
            style: white(
              11,
              c: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorCard(String error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: panel(),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.redAccent,
            size: 45,
          ),

          const SizedBox(height: 12),

          AppText(
            'Unable to load offers.',
            style: white(
              16,
              w: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
            ),
          ),

          const SizedBox(height: 15),

          blueButton(
            'Try Again',
            _loadOffers,
          ),
        ],
      ),
    );
  }
}