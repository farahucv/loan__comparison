import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import 'borrower_ui.dart';
import '../models/borrower_app_state.dart';

class ChooseLoanTypeScreen extends StatelessWidget {
  const ChooseLoanTypeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = BorrowerAppState.instance;
    return AnimatedBuilder(
      animation: state,
      builder: (_, __) => BorrowerShell(
        active: 1,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppText('Choose Loan Type', textAlign: TextAlign.center, style: white(30, w: FontWeight.w900)),
                  const SizedBox(height: 10),
                  AppText('This helps Rushd show relevant offers and recommendations.', textAlign: TextAlign.center, style: white(13, c: Colors.white54)),
                  const SizedBox(height: 34),
                  LayoutBuilder(
                    builder: (context, box) {
                      final cards = [
                        _type(context, Icons.credit_card, 'Personal Loan', 'For individual financing needs.', state.loanType == 'Personal Loan'),
                        _type(context, Icons.business_center_outlined, 'Business Loan', 'For small businesses and business owners.', state.loanType == 'Business Loan'),
                        _type(context, Icons.trending_up, 'Investment Loan', 'For users seeking financing for investment purposes.', state.loanType == 'Investment Loan'),
                      ];
                      if (box.maxWidth < 760) {
                        return Column(children: [for (final card in cards) Padding(padding: const EdgeInsets.only(bottom: 16), child: card)]);
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: cards[0]), const SizedBox(width: 16),
                          Expanded(child: cards[1]), const SizedBox(width: 16),
                          Expanded(child: cards[2]),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _type(BuildContext context, IconData icon, String title, String description, bool active) {
    return InkWell(
      onTap: () {
        BorrowerAppState.instance.selectLoanType(title);
        Navigator.pushNamed(context, '/loanAssessment');
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: active ? const Color(0xff17205C) : Colors.white.withOpacity(.09),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? kBlue : Colors.white.withOpacity(.06)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: kCyan, size: 30),
            const SizedBox(height: 34),
            AppText(title, style: white(19, w: FontWeight.w800)),
            const SizedBox(height: 8),
            AppText(description, style: white(12, c: Colors.white54)),
          ],
        ),
      ),
    );
  }
}
