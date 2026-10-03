import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_settings.dart';
import '../models/borrower_app_state.dart';
import 'borrower_ui.dart';

class BorrowerProfileScreen extends StatefulWidget {
  const BorrowerProfileScreen({super.key});

  @override
  State<BorrowerProfileScreen> createState() =>
      _BorrowerProfileScreenState();
}

class _BorrowerProfileScreenState
    extends State<BorrowerProfileScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  final BorrowerAppState s = BorrowerAppState.instance;

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  String money(double n) =>
      n == 0 ? 'Not entered' : 'SAR ${n.toStringAsFixed(0)}';

  double _toDouble(dynamic value) {
    if (value == null) return 0;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0;
  }

  Future<void> _loadProfile() async {
    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        throw Exception('User is not signed in.');
      }

      final profile = await _supabase
          .from('profiles')
          .select('full_name, phone')
          .eq('id', user.id)
          .maybeSingle();

      final financial = await _supabase
          .from('borrower_profiles')
          .select(
            'preferred_loan_type, monthly_income, existing_debts, monthly_expenses, desired_amount',
          )
          .eq('user_id', user.id)
          .maybeSingle();

      s.register(
        name: profile?['full_name']?.toString() ?? 'Borrower',
        emailAddress: user.email ?? '',
        mobile: profile?['phone']?.toString() ?? '',
      );

      if (financial != null) {
        s.selectLoanType(
          financial['preferred_loan_type']?.toString() ??
              'Personal Loan',
        );

        s.saveAssessment(
          monthlyIncome:
              _toDouble(financial['monthly_income']),
          existingDebts:
              _toDouble(financial['existing_debts']),
          monthlyExpenses:
              _toDouble(financial['monthly_expenses']),
          desiredAmount:
              _toDouble(financial['desired_amount']),
        );
      }

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading profile: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _openFinancialAssessment() async {
    await Navigator.pushNamed(
      context,
      '/loanAssessment',
    );

    if (!mounted) return;

    // Reload updated information from Supabase
    // after returning from the assessment.
    await _loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: s,
      builder: (_, __) => BorrowerShell(
        active: 3,
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 38,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxWidth: 900),
                    child: LayoutBuilder(
                      builder: (_, c) {
                        final compact = c.maxWidth < 700;

                        final summary = _summary(s);
                        final details = _details(context, s);

                        if (compact) {
                          return Column(
                            children: [
                              summary,
                              const SizedBox(height: 16),
                              details,
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: summary,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 4,
                              child: details,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _summary(BorrowerAppState s) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: panel(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: kBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outline,
                color: Colors.white,
                size: 32,
              ),
            ),

            const SizedBox(height: 16),

            AppText(
              s.fullName,
              textAlign: TextAlign.center,
              style: white(
                16,
                w: FontWeight.w800,
              ),
            ),

            AppText(
              'Borrower',
              style: white(
                10,
                c: Colors.white54,
              ),
            ),

            const SizedBox(height: 26),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: panel(radius: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  AppText(
                    'Profile Status',
                    style: white(
                      10,
                      w: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 4),

                  AppText(
                    s.income > 0
                        ? 'Financial information saved and ready for loan assessment.'
                        : 'Complete your financial assessment to save your profile.',
                    style: white(
                      9,
                      c: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _details(
    BuildContext context,
    BorrowerAppState s,
  ) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: panel(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              'Borrower Profile',
              style: white(
                23,
                w: FontWeight.w900,
              ),
            ),

            const SizedBox(height: 16),

            _responsiveInfo(
              'Email',
              s.email.isEmpty ? 'Not entered' : s.email,
              'Mobile',
              s.phone.isEmpty ? 'Not entered' : s.phone,
            ),

            const SizedBox(height: 10),

            _responsiveInfo(
              'Monthly Income',
              money(s.income),
              'Monthly Expenses',
              money(s.expenses),
            ),

            const SizedBox(height: 10),

            _responsiveInfo(
              'Existing Loans/Debts',
              money(s.debts),
              'Preferred Loan Type',
              s.loanType,
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: blueButton(
                'Update Financial Profile',
                _openFinancialAssessment,
              ),
            ),
          ],
        ),
      );

  Widget _responsiveInfo(
    String a,
    String b,
    String c,
    String d,
  ) =>
      LayoutBuilder(
        builder: (_, box) {
          if (box.maxWidth < 420) {
            return Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: _info(a, b),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: _info(c, d),
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _info(a, b),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _info(c, d),
              ),
            ],
          );
        },
      );

  Widget _info(
    String a,
    String b,
  ) =>
      Container(
        padding: const EdgeInsets.all(13),
        decoration: panel(radius: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              a,
              style: white(
                9,
                c: Colors.white38,
              ),
            ),

            const SizedBox(height: 4),

            AppText(
              b,
              style: white(
                11,
                w: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
}