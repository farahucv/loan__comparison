import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_settings.dart';
import 'borrower_ui.dart';

// Shared pieces for the financing-journey screens.

String tr(String text) => AppSettings.instance.tr(text);

Color get journeyText =>
    AppSettings.instance.isDark ? Colors.white : const Color(0xff202033);

/// 31/10/2026
String formatDate(DateTime? date) {
  if (date == null) return '-';

  final d = date.toLocal();

  return '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';
}

/// 31/10/2026 14:05
String formatDateTime(DateTime? date) {
  if (date == null) return '-';

  final d = date.toLocal();

  return '${formatDate(d)} '
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
}

/// Saudi IBAN: SA + 22 digits (24 characters).
final RegExp saudiIban = RegExp(r'^SA\d{22}$');

String normalizeIban(String value) =>
    value.replaceAll(RegExp(r'\s'), '').toUpperCase();

/// SA** **** **** **** **** 1234
String maskIban(String iban) {
  final clean = normalizeIban(iban);
  final last4 = clean.length >= 4 ? clean.substring(clean.length - 4) : clean;

  return 'SA** **** **** **** **** $last4';
}

String? bankLogoFor(String bankName) {
  final name = bankName.toLowerCase().trim();

  if (name.contains('rajhi')) return 'assets/images/Alrajhi-Bank-Logo.png';
  if (name.contains('riyad')) return 'assets/images/Riyad-Bank-Logo.png';
  if (name.contains('bilad')) return 'assets/images/Albilad-Bank-Logo.png';

  if (name.contains('national') ||
      name.contains('snb') ||
      name.contains('ahli')) {
    return 'assets/images/Saudi_National_Bank_Logo.png';
  }

  return null;
}

/// Scrollable, centred page body with a 16px gutter on phones.
class JourneyPage extends StatelessWidget {
  final List<Widget> children;
  final double maxWidth;

  const JourneyPage({super.key, required this.children, this.maxWidth = 820});

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 600;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: narrow ? 16 : 24,
        vertical: narrow ? 20 : 34,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// Page title with a back button.
class JourneyHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onRefresh;

  const JourneyHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 600;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (Navigator.canPop(context))
            IconButton(
              tooltip: tr('Back'),
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.arrow_back, color: journeyText),
            ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  title,
                  style: white(narrow ? 22 : 28, w: FontWeight.w900),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 5),
                  AppText(subtitle!, style: white(12, c: Colors.white54)),
                ],
              ],
            ),
          ),
          if (onRefresh != null)
            IconButton(
              tooltip: tr('Refresh'),
              onPressed: onRefresh,
              icon: Icon(Icons.refresh, color: journeyText),
            ),
        ],
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(48),
    child: Center(child: CircularProgressIndicator()),
  );
}

class ErrorView extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;

  const ErrorView({
    super.key,
    this.title = 'Something went wrong.',
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(26),
    decoration: panel(),
    child: Column(
      children: [
        const Icon(Icons.error_outline, color: Colors.redAccent, size: 42),
        const SizedBox(height: 10),
        AppText(
          title,
          textAlign: TextAlign.center,
          style: white(16, w: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        AppText(
          message,
          textAlign: TextAlign.center,
          style: white(12, c: Colors.white54),
        ),
        const SizedBox(height: 14),
        ElevatedButton(onPressed: onRetry, child: AppText('Try Again')),
      ],
    ),
  );
}

class EmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(30),
    decoration: panel(),
    child: Column(
      children: [
        Icon(icon, color: kCyan, size: 46),
        const SizedBox(height: 12),
        AppText(
          title,
          textAlign: TextAlign.center,
          style: white(17, w: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        AppText(
          message,
          textAlign: TextAlign.center,
          style: white(11, c: Colors.white54),
        ),
        if (action != null) ...[const SizedBox(height: 16), action!],
      ],
    ),
  );
}

class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .15),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
        ],
        AppText(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

/// A titled panel.
class SectionCard extends StatelessWidget {
  final String? title;
  final Widget child;
  final EdgeInsets padding;
  final Color? accent;

  const SectionCard({
    super.key,
    this.title,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.accent,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: accent == null
        ? panel()
        : BoxDecoration(
            color: accent!.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: accent!.withValues(alpha: .3)),
          ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) ...[
          AppText(title!, style: white(16, w: FontWeight.bold)),
          const SizedBox(height: 14),
        ],
        child,
      ],
    ),
  );
}

/// Label on the left, value on the right (wraps on phones).
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;
  final bool translateValue;

  const InfoRow(
    this.label,
    this.value, {
    super.key,
    this.strong = false,
    this.translateValue = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: AppText(label, style: white(12, c: Colors.white60)),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 5,
          child: translateValue
              ? AppText(
                  value,
                  textAlign: TextAlign.end,
                  style: white(
                    strong ? 14 : 12,
                    w: strong ? FontWeight.w800 : FontWeight.w600,
                  ),
                )
              : Text(
                  value,
                  textAlign: TextAlign.end,
                  style: white(
                    strong ? 14 : 12,
                    w: strong ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
        ),
      ],
    ),
  );
}

/// Yellow "Demo only" box.
class DemoNote extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const DemoNote(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.amber.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.amber.withValues(alpha: .45)),
    ),
    child: Row(
      children: [
        const Icon(Icons.science_outlined, color: Colors.amber, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                'Demo only',
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              AppText(text, style: white(11, c: Colors.white70)),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Live "2d 04:13:09" countdown to [target].
class CountdownText extends StatefulWidget {
  final DateTime target;
  final TextStyle? style;
  final VoidCallback? onFinished;
  final String finishedText;

  const CountdownText({
    super.key,
    required this.target,
    this.style,
    this.onFinished,
    this.finishedText = 'Ended',
  });

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  Timer? _timer;
  bool _notified = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});

      if (!_notified && !DateTime.now().isBefore(widget.target)) {
        _notified = true;
        widget.onFinished?.call();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.target.difference(DateTime.now());

    if (left.isNegative) {
      return AppText(widget.finishedText, style: widget.style);
    }

    String two(int n) => n.toString().padLeft(2, '0');

    final days = left.inDays;
    final clock =
        '${two(left.inHours % 24)}:${two(left.inMinutes % 60)}:${two(left.inSeconds % 60)}';

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(
        days > 0 ? '$days${tr('d')} $clock' : clock,
        style: widget.style,
      ),
    );
  }
}

/// Six boxes for the signing code. One hidden text field underneath, so
/// typing, deleting and pasting all work.
class OtpInput extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onCompleted;
  final bool enabled;
  final bool hasError;

  const OtpInput({
    super.key,
    required this.onChanged,
    this.onCompleted,
    this.enabled = true,
    this.hasError = false,
  });

  @override
  State<OtpInput> createState() => OtpInputState();
}

class OtpInputState extends State<OtpInput> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  void clear() {
    _controller.clear();
    widget.onChanged('');
    setState(() {});
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final code = _controller.text;
    final narrow = MediaQuery.sizeOf(context).width < 420;
    final size = narrow ? 44.0 : 52.0;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: GestureDetector(
        onTap: widget.enabled ? _focus.requestFocus : null,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 6; i++)
                  Container(
                    width: size,
                    height: size + 6,
                    margin: EdgeInsets.symmetric(horizontal: narrow ? 3 : 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        width: 1.6,
                        color: widget.hasError
                            ? Colors.redAccent
                            : (i == code.length && _focus.hasFocus)
                            ? kCyan
                            : Colors.white24,
                      ),
                    ),
                    child: Text(
                      i < code.length ? code[i] : '',
                      style: TextStyle(
                        color: journeyText,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  enabled: widget.enabled,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  showCursor: false,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(counterText: ''),
                  onChanged: (value) {
                    setState(() {});
                    widget.onChanged(value);

                    if (value.length == 6) widget.onCompleted?.call(value);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Snackbars that go through the translation table.
void showInfo(BuildContext context, String message) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(tr(message))));
}

void showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(tr(message)), backgroundColor: Colors.redAccent),
  );
}
