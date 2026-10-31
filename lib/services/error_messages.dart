import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_settings.dart';

/// Turns an exception into a short message that is safe to show the user.
///
/// Messages raised by the database rules (for example "This application has
/// already been decided") are shown as they are, without the
/// "PostgrestException(message: ..., code: ...)" wrapper.
String friendlyError(Object error) {
  return AppSettings.instance.tr(_message(error));
}

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

  final text = error.toString();

  if (text.startsWith('Exception: ')) {
    return text.substring('Exception: '.length);
  }

  return text;
}
