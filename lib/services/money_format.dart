import '../models/app_settings.dart';

/// Formats an amount in Saudi riyals for the current language:
/// English "SAR 45,000.00", Arabic "45,000.00 ر.س".
String formatSar(num? value, {int decimals = 2}) {
  final amount = (value ?? 0).toDouble();
  final number = formatNumber(amount, decimals: decimals);

  return AppSettings.instance.isArabic ? '$number ر.س' : 'SAR $number';
}

/// 45000 -> "45,000.00"
String formatNumber(num value, {int decimals = 2}) {
  final fixed = value.abs().toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final whole = parts[0];

  final grouped = StringBuffer();

  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) grouped.write(',');
    grouped.write(whole[i]);
  }

  final sign = value < 0 ? '-' : '';
  final fraction = parts.length > 1 ? '.${parts[1]}' : '';

  return '$sign$grouped$fraction';
}

/// 5.25 -> "5.25%"
String formatPercent(num? value, {int decimals = 2}) {
  return '${(value ?? 0).toStringAsFixed(decimals)}%';
}
