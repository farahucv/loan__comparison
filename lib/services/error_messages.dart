import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_settings.dart';

/// Turns an exception into a short message that is safe to show the user.
///
/// Messages raised by the database rules (for example "This application has
/// already been decided") are shown as they are, without the
/// "PostgrestException(message: ..., code: ...)" wrapper.
String friendlyError(Object error) {
  final message = _message(error);

  if (AppSettings.instance.isArabic) {
    for (final rule in _arabicTemplates) {
      final match = rule.$1.firstMatch(message);

      if (match != null) return rule.$2(match);
    }
  }

  return AppSettings.instance.tr(message);
}

/// Database messages that contain numbers or dates, so they cannot be
/// exact keys in the translation table.
final List<(RegExp, String Function(Match))> _arabicTemplates = [
  (
    RegExp(r'^The term must be between (\d+) and (\d+) months'),
    (m) =>
        'يجب أن تكون مدة التمويل بين ${m[1]} و${m[2]} شهرًا (الحد الأعلى للتمويل الاستهلاكي حسب البنك المركزي السعودي).',
  ),
  (
    RegExp(
      r'^The admin fee cannot be more than SAR ([\d.]+) for this amount \(([\d.]+) % of the amount, up to SAR ([\d.]+)\)',
    ),
    (m) =>
        'لا يمكن أن تزيد الرسوم الإدارية عن ${m[1]} ر.س لهذا المبلغ (${m[2]}٪ من المبلغ، بحد أقصى ${m[3]} ر.س).',
  ),
  (
    RegExp(r'^The offer must be valid for 1 to (\d+) days'),
    (m) => 'يجب أن تكون صلاحية العرض من يوم واحد إلى ${m[1]} يومًا.',
  ),
  (
    RegExp(
      r'^The amount cannot be more than the borrower requested \(SAR ([\d.]+)\)',
    ),
    (m) => 'لا يمكن أن يزيد المبلغ عما طلبه المقترض (${m[1]} ر.س).',
  ),
  (
    RegExp(
      r'^The amount cannot be more than the maximum of your loan offer \(SAR ([\d.]+)\)',
    ),
    (m) => 'لا يمكن أن يزيد المبلغ عن الحد الأقصى لعرض القرض (${m[1]} ر.س).',
  ),
  (
    RegExp(
      r'^Debt Burden Ratio check failed: the new installment \(SAR ([\d.]+)\) is ([\d.]+) % .* the limit is ([\d.]+) %',
    ),
    (m) =>
        'لم يجتز فحص نسبة عبء الدين: القسط الجديد (${m[1]} ر.س) يمثل ${m[2]}٪ من دخل المقترض، والحد المسموح ${m[3]}٪. خفّض المبلغ أو مدّد المدة.',
  ),
  (
    RegExp(
      r'^Debt Burden Ratio check failed: existing obligations plus the new installment are ([\d.]+) % .* the limit is ([\d.]+) %',
    ),
    (m) =>
        'لم يجتز فحص نسبة عبء الدين: الالتزامات الحالية مع القسط الجديد تمثل ${m[1]}٪ من دخل المقترض، والحد المسموح ${m[2]}٪. خفّض المبلغ أو مدّد المدة.',
  ),
  (
    RegExp(r'^The cooling-off period ended on (.+) \(Riyadh time\)'),
    (m) => 'انتهت فترة التراجع في ${m[1]} (بتوقيت الرياض).',
  ),
  (
    RegExp(
      r'^Funds can be released after the cooling-off period ends on (.+) \(Riyadh time\)',
    ),
    (m) =>
        'يمكن صرف المبلغ بعد انتهاء فترة التراجع في ${m[1]} (بتوقيت الرياض).',
  ),
  (
    RegExp(r'^Please accept all the required consents \(missing'),
    (_) => 'يرجى الموافقة على جميع الإقرارات المطلوبة.',
  ),
  (
    RegExp(r'^Only a borrower can do this'),
    (_) => 'هذا الإجراء متاح للمقترض فقط.',
  ),
  (
    RegExp(r'^Only a lender can do this'),
    (_) => 'هذا الإجراء متاح لجهة التمويل فقط.',
  ),
];

String _message(Object error) {
  if (error is PostgrestException) {
    switch (error.code) {
      // raise exception '...' in a trigger / function
      case 'P0001':
        return error.message;

      // Row level security rejected the insert / update
      case '42501':
        if (error.message.contains('loan_offers')) {
          return 'Your lender account is pending verification by Rushd.';
        }

        return 'You do not have permission to do this.';

      case '23505':
        return 'This record already exists.';

      case '23514':
        return 'Some of the values entered are not allowed.';

      // Column / function missing: a migration has not been run yet.
      case 'PGRST202':
      case 'PGRST204':
      case '42703':
      case '42883':
        return 'The database needs the latest Rushd update. Please run the newest migration.';
    }

    return error.message;
  }

  if (error is StorageException) {
    final status = error.statusCode ?? '';
    final message = error.message.toLowerCase();

    if (status == '413' || message.contains('maximum allowed size')) {
      return 'File is too large. The maximum size is 5 MB.';
    }

    if (status == '415' || message.contains('mime type')) {
      return 'Only PDF, JPG and PNG files are allowed.';
    }

    if (status == '403' || message.contains('row-level security')) {
      return 'You can only upload documents to your own loan requests.';
    }

    return error.message;
  }

  if (error is AuthException) {
    return error.message;
  }

  if (error is ArgumentError) {
    return error.message.toString();
  }

  final text = error.toString();

  if (text.contains('Failed to fetch') ||
      text.contains('SocketException') ||
      text.contains('ClientException')) {
    return 'Could not connect to the server. Check your internet connection.';
  }

  if (text.startsWith('Exception: ')) {
    return text.substring('Exception: '.length);
  }

  return text;
}
