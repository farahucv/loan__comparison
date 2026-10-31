import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/error_messages.dart';

import '../models/app_settings.dart';
import '../models/borrower_app_state.dart';
import 'borrower_dashboard_screen.dart';
import 'lender_dashboard_screen.dart';
import 'register_role_screen.dart';

/// Asks for the 6-digit code from the "Confirm signup" email.
///
/// Supabase sends the code when the account is created (or when the login
/// screen asks for a new one). Verifying it signs the user in.
class VerifyEmailScreen extends StatefulWidget {
  final String email;

  /// Shown above the code boxes, e.g. when the login screen sent a new code.
  final String? note;

  /// True when opened from a registration screen, so "Go back" returns to
  /// the filled-in form instead of starting a new registration.
  final bool fromRegistration;

  const VerifyEmailScreen({
    super.key,
    required this.email,
    this.note,
    this.fromRegistration = true,
  });

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  static const int _codeLength = 6;
  static const int _resendSeconds = 60;

  // Supabase's default lifetime of an email code (Auth -> Email OTP expiry).
  static const Duration _codeLifetime = Duration(hours: 1);

  final List<TextEditingController> _controllers = List.generate(
    _codeLength,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    _codeLength,
    (_) => FocusNode(),
  );

  bool isVerifying = false;
  bool isResending = false;
  int secondsLeft = _resendSeconds;
  Timer? _timer;

  // When the current code was sent: on this screen opening, or on resend.
  DateTime _codeSentAt = DateTime.now();

  String get _code => _controllers.map((c) => c.text).join();

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();

    for (final c in _controllers) {
      c.dispose();
    }

    for (final f in _focusNodes) {
      f.dispose();
    }

    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();

    setState(() {
      secondsLeft = _resendSeconds;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      setState(() {
        secondsLeft--;
      });

      if (secondsLeft <= 0) timer.cancel();
    });
  }

  void _onDigitChanged(int index, String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');

    // Pasting the whole code into any box fills all six.
    if (digits.length >= _codeLength) {
      for (var i = 0; i < _codeLength; i++) {
        _controllers[i].text = digits[i];
      }

      _focusNodes.last.requestFocus();
      setState(() {});
      _verify();
      return;
    }

    // Typing into a box that already has a digit: keep the new one.
    if (digits.length > 1) {
      _controllers[index].text = digits[digits.length - 1];
    }

    if (_controllers[index].text.length == 1 && index < _codeLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }

    setState(() {});

    if (_code.length == _codeLength) _verify();
  }

  KeyEventResult _onKey(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _controllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
      setState(() {});
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _clearCode() {
    for (final c in _controllers) {
      c.clear();
    }

    _focusNodes.first.requestFocus();
    setState(() {});
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppSettings.instance.tr(message)),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  /// Supabase answers a wrong code and an expired code with the same error
  /// ("Token has expired or is invalid"), so the time since the code was
  /// sent decides which message to show.
  String _authError(AuthException error) {
    final code = error.code ?? '';
    final message = error.message.toLowerCase();

    if (error.statusCode == '429' ||
        code == 'over_email_send_rate_limit' ||
        code == 'over_request_rate_limit' ||
        message.contains('rate limit') ||
        message.contains('security purposes')) {
      return 'Too many requests. Please wait a minute and try again.';
    }

    if (code == 'otp_expired' ||
        message.contains('expired') ||
        message.contains('invalid')) {
      if (DateTime.now().difference(_codeSentAt) >= _codeLifetime) {
        return 'This code has expired. Tap "Resend code" to get a new one.';
      }

      return 'The code is incorrect. Check the email and try again.';
    }

    return friendlyError(error);
  }

  Future<void> _verify() async {
    if (isVerifying) return;

    final code = _code;

    if (code.length != _codeLength) {
      _showError('Please enter the 6-digit code.');
      return;
    }

    setState(() {
      isVerifying = true;
    });

    try {
      final response = await Supabase.instance.client.auth.verifyOTP(
        type: OtpType.signup,
        email: widget.email,
        token: code,
      );

      final user = response.user;

      if (response.session == null || user == null) {
        throw Exception('Unable to sign in.');
      }

      await _openDashboard(user);
    } on AuthException catch (error) {
      if (!mounted) return;

      _showError(_authError(error));
      _clearCode();
    } catch (error) {
      if (!mounted) return;

      _showError(friendlyError(error));
    } finally {
      if (mounted) {
        setState(() {
          isVerifying = false;
        });
      }
    }
  }

  /// Same routing as the login screen.
  Future<void> _openDashboard(User user) async {
    final client = Supabase.instance.client;

    final profile = await client
        .from('profiles')
        .select('role, full_name, phone, bank_name')
        .eq('id', user.id)
        .maybeSingle();

    if (profile == null) {
      throw Exception('User profile was not found.');
    }

    final role = profile['role']?.toString();
    final fullName = profile['full_name']?.toString() ?? '';
    final phone = profile['phone']?.toString() ?? '';

    if (!mounted) return;

    if (role == 'borrower') {
      final financialProfile = await client
          .from('borrower_profiles')
          .select(
            'preferred_loan_type, monthly_income, existing_debts, monthly_expenses, desired_amount',
          )
          .eq('user_id', user.id)
          .maybeSingle();

      final state = BorrowerAppState.instance;

      state.register(
        name: fullName,
        emailAddress: user.email ?? widget.email,
        mobile: phone,
      );

      if (financialProfile != null) {
        state.selectLoanType(
          financialProfile['preferred_loan_type']?.toString() ??
              'Personal Loan',
        );

        state.saveAssessment(
          monthlyIncome: _toDouble(financialProfile['monthly_income']),
          existingDebts: _toDouble(financialProfile['existing_debts']),
          monthlyExpenses: _toDouble(financialProfile['monthly_expenses']),
          desiredAmount: _toDouble(financialProfile['desired_amount']),
        );
      }

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const BorrowerDashboardScreen()),
        (route) => false,
      );
    } else if (role == 'lender') {
      // An unverified lender sees the pending-verification screen there.
      final bankName = profile['bank_name']?.toString() ?? '';

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) =>
              LenderDashboardScreen(lenderName: fullName, bankName: bankName),
        ),
        (route) => false,
      );
    } else {
      throw Exception('Unknown account type.');
    }
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0;
  }

  Future<void> _resend() async {
    if (isResending || secondsLeft > 0) return;

    setState(() {
      isResending = true;
    });

    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: widget.email,
      );

      if (!mounted) return;

      _codeSentAt = DateTime.now();
      _clearCode();
      _startCountdown();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: AppText('We sent you a new code.')));
    } on AuthException catch (error) {
      if (!mounted) return;

      _showError(_authError(error));
    } catch (error) {
      if (!mounted) return;

      _showError(friendlyError(error));
    } finally {
      if (mounted) {
        setState(() {
          isResending = false;
        });
      }
    }
  }

  void _goBack() {
    if (widget.fromRegistration && Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const RegisterRoleScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canResend = secondsLeft <= 0 && !isResending;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppPalette.bg1, AppPalette.bg2, AppPalette.bg3],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Center(
              child: Column(
                children: [
                  const SizedBox(height: 30),

                  Image.asset('assets/images/rushd_log.png', width: 180),

                  const SizedBox(height: 20),

                  AppText(
                    "Verify your email",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  AppText(
                    "We sent a 6-digit code to",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                  ),

                  const SizedBox(height: 4),

                  // The address is shown as typed, left to right.
                  Text(
                    widget.email,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      color: AppSettings.instance.isDark
                          ? Colors.white
                          : Colors.black87,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 35),

                  Container(
                    constraints: const BoxConstraints(maxWidth: 480),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 32,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Column(
                      children: [
                        if (widget.note != null) ...[
                          _noteBox(widget.note!),
                          const SizedBox(height: 20),
                        ],

                        _codeBoxes(),

                        const SizedBox(height: 25),

                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xff00A8E8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: isVerifying ? null : _verify,
                            child: isVerifying
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : AppText(
                                    "Verify",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        TextButton(
                          onPressed: canResend ? _resend : null,
                          child: isResending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.lightBlue,
                                  ),
                                )
                              : AppText(
                                  secondsLeft <= 0
                                      ? "Resend code"
                                      : AppSettings.instance.isArabic
                                      ? 'إعادة إرسال الرمز بعد $secondsLeft ثانية'
                                      : 'Resend code in ${secondsLeft}s',
                                  style: TextStyle(
                                    color: canResend
                                        ? Colors.lightBlue
                                        : Colors.white54,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),

                        const SizedBox(height: 4),

                        AppText(
                          "Can't find it? Check your spam folder.",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  TextButton(
                    onPressed: isVerifying ? null : _goBack,
                    child: AppText(
                      "Wrong email? Go back",
                      style: const TextStyle(
                        color: Colors.lightBlue,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
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

  Widget _noteBox(String note) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Colors.amber, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: AppText(
              note,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _codeBoxes() {
    const gap = 8.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size =
            ((constraints.maxWidth - gap * (_codeLength - 1)) / _codeLength)
                .clamp(36.0, 54.0);

        // Codes are read left to right in Arabic too.
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _codeLength; i++) ...[
                if (i > 0) const SizedBox(width: gap),
                SizedBox(width: size, height: size + 6, child: _digitBox(i)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _digitBox(int index) {
    return Focus(
      onKeyEvent: (_, event) => _onKey(index, event),
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        autofocus: index == 0,
        enabled: !isVerifying,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        autofillHints: index == 0 ? const [AutofillHints.oneTimeCode] : null,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (value) => _onDigitChanged(index, value),
        onTap: () {
          final c = _controllers[index];
          c.selection = TextSelection(
            baseOffset: 0,
            extentOffset: c.text.length,
          );
        },
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.08),
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xff00A8E8), width: 2),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
        ),
      ),
    );
  }
}
