import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_settings.dart';
import 'borrower_ui.dart';
import '../models/borrower_app_state.dart';

class SecureLoanAssessmentScreen extends StatefulWidget {
  const SecureLoanAssessmentScreen({super.key});

  @override
  State<SecureLoanAssessmentScreen> createState() =>
      _SecureLoanAssessmentScreenState();
}

class _SecureLoanAssessmentScreenState
    extends State<SecureLoanAssessmentScreen> {
  late final TextEditingController incomeController;
  late final TextEditingController debtController;
  late final TextEditingController expensesController;
  late final TextEditingController amountController;

  bool isSaving = false;

  @override
  void initState() {
    super.initState();

    final state = BorrowerAppState.instance;

    incomeController = TextEditingController(
      text: state.income == 0 ? '' : state.income.toStringAsFixed(0),
    );

    debtController = TextEditingController(
      text: state.debts == 0 ? '' : state.debts.toStringAsFixed(0),
    );

    expensesController = TextEditingController(
      text: state.expenses == 0 ? '' : state.expenses.toStringAsFixed(0),
    );

    amountController = TextEditingController(
      text: state.amount == 0 ? '' : state.amount.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    incomeController.dispose();
    debtController.dispose();
    expensesController.dispose();
    amountController.dispose();
    super.dispose();
  }

  Future<void> _saveAssessment() async {
    final income = double.tryParse(incomeController.text.trim());

    final debts = double.tryParse(debtController.text.trim());

    final expenses = double.tryParse(expensesController.text.trim());

    final amount = double.tryParse(amountController.text.trim());

    if (income == null || income <= 0) {
      _showError('Please enter a valid monthly income.');
      return;
    }

    if (debts == null || debts < 0) {
      _showError('Please enter valid existing debts.');
      return;
    }

    if (expenses == null || expenses < 0) {
      _showError('Please enter valid monthly expenses.');
      return;
    }

    if (amount == null || amount <= 0) {
      _showError('Please enter a valid desired loan amount.');
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      _showError('You must sign in before saving the assessment.');
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final state = BorrowerAppState.instance;

      await Supabase.instance.client.from('borrower_profiles').upsert({
        'user_id': user.id,
        'preferred_loan_type': state.loanType,
        'monthly_income': income,
        'existing_debts': debts,
        'monthly_expenses': expenses,
        'desired_amount': amount,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      // Keep the existing UI state updated too.
      state.saveAssessment(
        monthlyIncome: income,
        existingDebts: debts,
        monthlyExpenses: expenses,
        desiredAmount: amount,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Financial information saved successfully.'),
        ),
      );

      Navigator.pushNamed(context, '/loanAnalysis');
    } on PostgrestException catch (error) {
      if (!mounted) return;

      _showError(error.message);
    } catch (error) {
      if (!mounted) return;

      _showError('Error: $error');
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = BorrowerAppState.instance;

    return BorrowerShell(
      active: 1,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(26),
              decoration: panel(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppText(
                    'Secure Loan Assessment',
                    style: white(25, w: FontWeight.w900),
                  ),

                  const SizedBox(height: 7),

                  AppText(
                    'Selected type: ${state.loanType}',
                    style: white(12, c: Colors.white54),
                  ),

                  const SizedBox(height: 25),

                  LayoutBuilder(
                    builder: (_, box) {
                      final a = _read('Full Name', state.fullName);

                      final b = _field(
                        'Monthly Income (SAR)',
                        incomeController,
                      );

                      if (box.maxWidth < 520) {
                        return Column(
                          children: [a, const SizedBox(height: 12), b],
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
                  ),

                  const SizedBox(height: 12),

                  LayoutBuilder(
                    builder: (_, box) {
                      final a = _field(
                        'Existing Loans / Debts (SAR)',
                        debtController,
                      );

                      final b = _field(
                        'Monthly Expenses (SAR)',
                        expensesController,
                      );

                      if (box.maxWidth < 520) {
                        return Column(
                          children: [a, const SizedBox(height: 12), b],
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
                  ),

                  const SizedBox(height: 12),

                  _field('Desired Loan Amount (SAR)', amountController),

                  const SizedBox(height: 18),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.amberAccent.withOpacity(.10),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.amberAccent.withOpacity(.35),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.amberAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText(
                                'Make sure your information is accurate to get accurate offers.',
                                style: white(11, w: FontWeight.bold),
                              ),
                              const SizedBox(height: 5),
                              AppText(
                                'Requesting a loan with incorrect information may put your account at risk of being banned.',
                                style: white(10, c: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: isSaving ? null : _saveAssessment,
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
                              'Check My Loan Options',
                              style: white(13, w: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _read(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          label,
          style: white(11, w: FontWeight.bold, c: Colors.white70),
        ),

        const SizedBox(height: 7),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: panel(radius: 9),
          child: AppText(value, style: white(13)),
        ),
      ],
    );
  }

  Widget _field(String label, TextEditingController controller) {
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
          style: white(13),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(.10),
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
}
