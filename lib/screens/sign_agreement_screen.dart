import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/financing.dart';
import '../services/error_messages.dart';
import '../services/financing_service.dart';
import '../services/loan_request_service.dart';
import '../services/money_format.dart';
import 'borrower_ui.dart';
import 'financing_status_screen.dart';
import 'journey_ui.dart';

/// Simulated e-signing with a one-time code, then the cooling-off period
/// with the right to withdraw.
class SignAgreementScreen extends StatefulWidget {
  final BorrowerRequestData request;
  final String agreementId;

  const SignAgreementScreen({
    super.key,
    required this.request,
    required this.agreementId,
  });

  @override
  State<SignAgreementScreen> createState() => _SignAgreementScreenState();
}

class _SignAgreementScreenState extends State<SignAgreementScreen> {
  final FinancingService _service = FinancingService();
  final GlobalKey<OtpInputState> _otpKey = GlobalKey<OtpInputState>();

  FinancingAgreement? agreement;
  FinancingOffer? offer;
  FinancingSettings settings = const FinancingSettings();

  bool isLoading = true;
  bool isBusy = false;
  String? errorMessage;

  // Signing
  String? demoCode; // only kept in memory, never logged
  String code = '';
  String? codeError;
  bool codeLocked = false;
  bool justSigned = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final loadedAgreement = await _service.getAgreement(widget.agreementId);
      final loadedOffer = loadedAgreement == null
          ? null
          : await _service.getOffer(loadedAgreement.offerId);

      FinancingSettings loadedSettings = const FinancingSettings();

      try {
        loadedSettings = await _service.getSettings();
      } catch (_) {
        // Defaults are fine for display.
      }

      if (!mounted) return;

      setState(() {
        agreement = loadedAgreement;
        offer = loadedOffer;
        settings = loadedSettings;
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

  // =========================
  // ACTIONS
  // =========================

  Future<void> _sendCode() async {
    setState(() {
      isBusy = true;
      codeError = null;
      codeLocked = false;
    });

    try {
      final sent = await _service.requestSigningCode(widget.agreementId);

      if (!mounted) return;

      setState(() {
        demoCode = sent;
        code = '';
      });

      _otpKey.currentState?.clear();
    } catch (error) {
      if (mounted) showError(context, friendlyError(error));
    } finally {
      if (mounted) setState(() => isBusy = false);
    }
  }

  Future<void> _sign() async {
    if (code.length != 6) return;

    setState(() {
      isBusy = true;
      codeError = null;
    });

    try {
      final result = await _service.signAgreement(
        agreementId: widget.agreementId,
        code: code,
      );

      if (!mounted) return;

      if (!result.ok) {
        final left = result.attemptsLeft ?? 0;

        setState(() {
          codeLocked = left <= 0;
          codeError = left <= 0
              ? tr('Too many incorrect attempts. Please request a new code.')
              : '${tr('Incorrect code.')} ${tr('Attempts left:')} $left';
        });

        _otpKey.currentState?.clear();
        return;
      }

      setState(() {
        justSigned = true;
        demoCode = null;
      });

      await _load();
    } catch (error) {
      if (mounted) {
        setState(() => codeError = friendlyError(error));
      }
    } finally {
      if (mounted) setState(() => isBusy = false);
    }
  }

  Future<void> _withdraw() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: AppText('Withdraw from agreement'),
        content: AppText(
          'You are within the cooling-off period, so you can withdraw without penalty. The agreement will be cancelled and no funds will be released. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: AppText('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: AppText('Yes, withdraw'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => isBusy = true);

    try {
      await _service.withdraw(widget.agreementId);

      if (!mounted) return;

      showInfo(context, 'You withdrew from the agreement.');
      await _load();
    } catch (error) {
      if (mounted) showError(context, friendlyError(error));
    } finally {
      if (mounted) setState(() => isBusy = false);
    }
  }

  void _openStatus() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => FinancingStatusScreen(request: widget.request),
      ),
    );
  }

  // =========================
  // UI
  // =========================

  @override
  Widget build(BuildContext context) {
    return BorrowerShell(
      active: 2,
      child: JourneyPage(
        maxWidth: 720,
        children: [
          JourneyHeader(
            title: 'Sign your agreement',
            subtitle:
                '${tr(widget.request.bankName)} • ${widget.request.offerName}',
            onRefresh: isBusy ? null : _load,
          ),
          if (isLoading)
            const LoadingView()
          else if (errorMessage != null)
            ErrorView(
              title: 'Unable to load the agreement.',
              message: errorMessage!,
              onRetry: _load,
            )
          else if (agreement == null || offer == null)
            const EmptyView(
              icon: Icons.description_outlined,
              title: 'Agreement not found.',
              message: 'Accept an offer first to create your agreement.',
            )
          else
            ..._content(agreement!, offer!),
        ],
      ),
    );
  }

  List<Widget> _content(FinancingAgreement a, FinancingOffer o) {
    return [
      if (justSigned) ...[const _SignedAnimation(), const SizedBox(height: 16)],
      _summary(a, o),
      const SizedBox(height: 16),
      switch (a.status) {
        'offer_accepted' => _signingCard(),
        'contract_signed' || 'cooling_off' => _coolingOffCard(a),
        'withdrawn' || 'cancelled' => _endCard(
          Colors.white54,
          Icons.undo,
          'You withdrew from this agreement',
          'The agreement was cancelled during the cooling-off period. No funds were released.',
        ),
        _ => _endCard(
          Colors.greenAccent,
          Icons.verified,
          'Financing active',
          'The funds were released (simulated). See your repayment schedule in the progress page.',
        ),
      },
      const SizedBox(height: 16),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: _openStatus,
          icon: const Icon(Icons.timeline, color: kCyan),
          label: AppText('View progress', style: const TextStyle(color: kCyan)),
        ),
      ),
    ];
  }

  Widget _summary(FinancingAgreement a, FinancingOffer o) {
    return SectionCard(
      title: 'Agreement summary',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InfoRow('Reference number', a.referenceNo, strong: true),
          InfoRow('Bank', widget.request.bankName, translateValue: true),
          InfoRow('Financed amount', formatSar(o.principal)),
          InfoRow(
            'Monthly installment',
            formatSar(o.monthlyInstallment),
            strong: true,
          ),
          InfoRow('Term', '${o.termMonths} ${tr('months')}'),
          InfoRow('Annual percentage rate (APR)', formatPercent(o.apr)),
          InfoRow('Total repayable', formatSar(o.totalRepayable)),
          InfoRow('Offer accepted on', formatDateTime(a.kfsAcceptedAt)),
          if (a.signedAt != null)
            InfoRow('Signed on', formatDateTime(a.signedAt)),
          InfoRow(
            'Early release of funds',
            a.earlyDisbursementWaiver ? 'Allowed by you' : 'Not allowed',
            translateValue: true,
          ),
        ],
      ),
    );
  }

  Widget _signingCard() {
    final sent = demoCode != null;

    return SectionCard(
      title: 'Sign with a one-time code',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppText(
            'We send a 6-digit code to the phone number in your profile. Enter it to sign the agreement electronically.',
            style: white(12, c: Colors.white60),
          ),
          const SizedBox(height: 16),
          if (!sent)
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kBlue,
                  foregroundColor: Colors.white,
                ),
                onPressed: isBusy ? null : _sendCode,
                icon: isBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.sms_outlined),
                label: AppText(
                  'Send signing code',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            )
          else ...[
            DemoNote(
              '${tr('Your signing code is')} $demoCode. ${tr('In a live service it is sent by SMS and valid for 5 minutes.')}',
            ),
            const SizedBox(height: 18),
            OtpInput(
              key: _otpKey,
              enabled: !isBusy && !codeLocked,
              hasError: codeError != null,
              onChanged: (value) => setState(() {
                code = value;
                if (value.isNotEmpty) codeError = null;
              }),
              onCompleted: (_) => _sign(),
            ),
            if (codeError != null) ...[
              const SizedBox(height: 10),
              Text(
                codeError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kBlue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.white12,
                ),
                onPressed: isBusy || codeLocked || code.length != 6
                    ? null
                    : _sign,
                child: isBusy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : AppText(
                        'Sign agreement',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: isBusy ? null : _sendCode,
              child: AppText(
                'Send a new code',
                style: const TextStyle(color: kCyan),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _coolingOffCard(FinancingAgreement a) {
    final ends = a.coolingOffEndsAt;
    final open = a.inCoolingOff;

    return SectionCard(
      accent: Colors.amberAccent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, color: Colors.amberAccent),
              const SizedBox(width: 10),
              Expanded(
                child: AppText(
                  'Cooling-off period',
                  style: white(16, w: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AppText(
            open
                ? 'You can withdraw from this agreement without any penalty until the time below. After that, the bank can release the funds.'
                : 'The cooling-off period has ended. The bank can now release the funds to your account.',
            style: white(12, c: Colors.white70),
          ),
          if (settings.demoFastCoolingOff) ...[
            const SizedBox(height: 10),
            DemoNote(
              '${tr('Demo mode: the cooling-off period is shortened to')} ${settings.demoFastCoolingOffMinutes} ${tr('minutes')}.',
            ),
          ],
          if (a.earlyDisbursementWaiver) ...[
            const SizedBox(height: 10),
            AppText(
              'You allowed early release, so the bank may release the funds before this period ends.',
              style: white(11, c: Colors.orangeAccent),
            ),
          ],
          const SizedBox(height: 16),
          if (ends != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  AppText(
                    open ? 'Time left to withdraw' : 'Ended on',
                    style: white(11, c: Colors.white54),
                  ),
                  const SizedBox(height: 6),
                  if (open)
                    CountdownText(
                      target: ends,
                      onFinished: () => setState(() {}),
                      style: TextStyle(
                        color: journeyText,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    formatDateTime(ends),
                    style: white(12, c: Colors.white70),
                  ),
                ],
              ),
            ),
          if (open) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                ),
                onPressed: isBusy ? null : _withdraw,
                icon: const Icon(Icons.undo),
                label: AppText(
                  'Withdraw from agreement',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _endCard(Color color, IconData icon, String title, String message) {
    return SectionCard(
      accent: color,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(title, style: white(15, w: FontWeight.bold)),
                const SizedBox(height: 6),
                AppText(message, style: white(12, c: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Green check that pops in after signing.
class _SignedAnimation extends StatelessWidget {
  const _SignedAnimation();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.elasticOut,
      builder: (_, value, child) => Transform.scale(scale: value, child: child),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.greenAccent.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.greenAccent.withValues(alpha: .4)),
        ),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 44),
            ),
            const SizedBox(height: 12),
            AppText('Agreement signed', style: white(18, w: FontWeight.w900)),
            const SizedBox(height: 4),
            AppText(
              'Signed electronically with a one-time code (simulated).',
              textAlign: TextAlign.center,
              style: white(12, c: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }
}
