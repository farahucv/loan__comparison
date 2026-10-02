import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_settings.dart';
import '../models/borrower_app_state.dart';

import 'home_screen.dart';
import 'borrower_dashboard_screen.dart';
import 'lender_dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();

    _checkSession();
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0;
  }

  Future<void> _checkSession() async {
    // Keep the splash screen visible
    // for the same 4 seconds as before.
    await Future.delayed(const Duration(seconds: 4));

    if (!mounted) return;

    try {
      final user = _supabase.auth.currentUser;

      // No saved login session
      if (user == null) {
        _goToHome();
        return;
      }

      final profile = await _supabase
          .from('profiles')
          .select('role, full_name, phone, bank_name')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      if (profile == null) {
        _goToHome();
        return;
      }

      final role = profile['role']?.toString().toLowerCase();

      // =========================
      // BORROWER
      // =========================
      if (role == 'borrower') {
        final financial = await _supabase
            .from('borrower_profiles')
            .select(
              'preferred_loan_type, monthly_income, existing_debts, monthly_expenses, desired_amount',
            )
            .eq('user_id', user.id)
            .maybeSingle();

        final borrowerState = BorrowerAppState.instance;

        borrowerState.register(
          name: profile['full_name']?.toString() ?? 'Borrower',
          emailAddress: user.email ?? '',
          mobile: profile['phone']?.toString() ?? '',
        );

        if (financial != null) {
          borrowerState.selectLoanType(
            financial['preferred_loan_type']?.toString() ?? 'Personal Loan',
          );

          borrowerState.saveAssessment(
            monthlyIncome: _toDouble(financial['monthly_income']),
            existingDebts: _toDouble(financial['existing_debts']),
            monthlyExpenses: _toDouble(financial['monthly_expenses']),
            desiredAmount: _toDouble(financial['desired_amount']),
          );
        }

        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const BorrowerDashboardScreen()),
        );

        return;
      }

      // =========================
      // LENDER
      // =========================
      if (role == 'lender') {
        final lenderName = profile['full_name']?.toString() ?? 'Lender';

        final bankName = profile['bank_name']?.toString() ?? '';

        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => LenderDashboardScreen(
              lenderName: lenderName,
              bankName: bankName,
            ),
          ),
        );

        return;
      }

      // Unknown role
      _goToHome();
    } catch (error) {
      if (!mounted) return;

      // If anything goes wrong while
      // checking the saved session,
      // safely return to Home.
      _goToHome();
    }
  }

  void _goToHome() {
    if (!mounted) return;

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppPalette.bg1, AppPalette.bg2, AppPalette.bg3],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Rushd Logo
              Image.asset(
                'assets/images/rushd_log.png',
                width: 240,
                fit: BoxFit.contain,
              ),

              const SizedBox(height: 30),

              AppText(
                "A Smarter way to find suitable loan offers.",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  letterSpacing: 1.5,
                ),
              ),

              const SizedBox(height: 40),

              // Loading bar
              Container(
                width: 120,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.lightBlue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
