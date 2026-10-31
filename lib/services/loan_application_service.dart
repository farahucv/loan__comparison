import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class LoanDocument {
  final String name;
  final String path;
  final String category;

  LoanDocument({
    required this.name,
    required this.path,
    required this.category,
  });

  factory LoanDocument.fromMap(Map<String, dynamic> map) => LoanDocument(
    name: map['name']?.toString() ?? 'Document',
    path: map['path']?.toString() ?? '',
    category: map['category']?.toString() ?? 'Other',
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'path': path,
    'category': category,
  };
}

/// A document the borrower picked but that is not uploaded yet.
class PendingDocument {
  final String name;
  final String category;
  final Uint8List bytes;

  PendingDocument({
    required this.name,
    required this.category,
    required this.bytes,
  });
}

class LoanApplicationData {
  final String id;
  final String requestId;
  final String borrowerId;
  final String lenderId;

  final String fullName;
  final String nationalId;
  final String city;
  final String address;
  final String employer;
  final String jobTitle;
  final double? yearsAtJob;
  final String iban;
  final String notes;
  final DateTime? dateOfBirth;

  /// government | private | military | retired
  final String employmentSector;

  /// credit_bureau_check, info_accurate, simulation_ack,
  /// identity_verified_simulated, accepted_at
  final Map<String, dynamic> consents;

  final List<LoanDocument> documents;

  /// submitted | more_info_required | approved | rejected
  final String status;
  final String lenderMessage;
  final DateTime? updatedAt;

  LoanApplicationData({
    required this.id,
    required this.requestId,
    required this.borrowerId,
    required this.lenderId,
    required this.fullName,
    required this.nationalId,
    required this.city,
    required this.address,
    required this.employer,
    required this.jobTitle,
    required this.yearsAtJob,
    required this.iban,
    required this.notes,
    required this.dateOfBirth,
    required this.employmentSector,
    required this.consents,
    required this.documents,
    required this.status,
    required this.lenderMessage,
    required this.updatedAt,
  });

  factory LoanApplicationData.fromMap(Map<String, dynamic> row) {
    final rawDocs = row['documents'];

    final docs = <LoanDocument>[];

    if (rawDocs is List) {
      for (final d in rawDocs) {
        if (d is Map) {
          docs.add(LoanDocument.fromMap(Map<String, dynamic>.from(d)));
        }
      }
    }

    return LoanApplicationData(
      id: row['id']?.toString() ?? '',
      requestId: row['request_id']?.toString() ?? '',
      borrowerId: row['borrower_id']?.toString() ?? '',
      lenderId: row['lender_id']?.toString() ?? '',
      fullName: row['full_name']?.toString() ?? '',
      nationalId: row['national_id']?.toString() ?? '',
      city: row['city']?.toString() ?? '',
      address: row['address']?.toString() ?? '',
      employer: row['employer']?.toString() ?? '',
      jobTitle: row['job_title']?.toString() ?? '',
      yearsAtJob: row['years_at_job'] == null
          ? null
          : double.tryParse(row['years_at_job'].toString()),
      iban: row['iban']?.toString() ?? '',
      notes: row['notes']?.toString() ?? '',
      dateOfBirth: DateTime.tryParse(row['date_of_birth']?.toString() ?? ''),
      employmentSector: row['employment_sector']?.toString() ?? '',
      consents: row['consents'] is Map
          ? Map<String, dynamic>.from(row['consents'] as Map)
          : <String, dynamic>{},
      documents: docs,
      status: row['status']?.toString() ?? 'submitted',
      lenderMessage: row['lender_message']?.toString() ?? '',
      updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? ''),
    );
  }
}

class BankContact {
  final String bankName;
  final String lenderName;
  final String phone;

  BankContact({
    required this.bankName,
    required this.lenderName,
    required this.phone,
  });
}

class LoanApplicationService {
  static const String bucket = 'loan-documents';

  final SupabaseClient _supabase = Supabase.instance.client;

  String get _uid {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('You must sign in first.');
    }

    return user.id;
  }

  // =========================
  // READ
  // =========================

  Future<LoanApplicationData?> getForRequest(String requestId) async {
    final row = await _supabase
        .from('loan_applications')
        .select()
        .eq('request_id', requestId)
        .maybeSingle();

    if (row == null) return null;

    return LoanApplicationData.fromMap(row);
  }

  /// Borrower's monthly income from the financial profile (step 2 of the
  /// application shows it read-only).
  Future<double?> getMonthlyIncome() async {
    final row = await _supabase
        .from('borrower_profiles')
        .select('monthly_income')
        .eq('user_id', _uid)
        .maybeSingle();

    final value = row?['monthly_income'];

    if (value == null) return null;
    if (value is num) return value.toDouble();

    return double.tryParse(value.toString());
  }

  /// Borrower: request id -> application status (for the Request Status list).
  Future<Map<String, String>> getBorrowerStatuses() async {
    final rows = await _supabase
        .from('loan_applications')
        .select('request_id, status')
        .eq('borrower_id', _uid);

    return {
      for (final r in rows) r['request_id'].toString(): r['status'].toString(),
    };
  }

  Future<BankContact?> getBankContact(String requestId) async {
    final result = await _supabase.rpc(
      'get_bank_contact',
      params: {'p_request_id': requestId},
    );

    if (result is List && result.isNotEmpty) {
      final row = Map<String, dynamic>.from(result.first as Map);

      return BankContact(
        bankName: row['bank_name']?.toString() ?? 'Bank',
        lenderName: row['lender_name']?.toString() ?? '',
        phone: row['lender_phone']?.toString() ?? '',
      );
    }

    return null;
  }

  // =========================
  // BORROWER: SUBMIT / RESUBMIT
  // =========================

  Future<void> submit({
    required String requestId,
    required String lenderId,
    required Map<String, dynamic> fields,
    required List<PendingDocument> newDocuments,
    LoanApplicationData? existing,
  }) async {
    final uid = _uid;

    final docs = <LoanDocument>[...?existing?.documents];

    for (final file in newDocuments) {
      final safeName = file.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

      final path =
          '$uid/$requestId/${DateTime.now().millisecondsSinceEpoch}_$safeName';

      await _supabase.storage
          .from(bucket)
          .uploadBinary(
            path,
            file.bytes,
            fileOptions: FileOptions(contentType: _contentType(file.name)),
          );

      docs.add(
        LoanDocument(name: file.name, path: path, category: file.category),
      );
    }

    final payload = {
      ...fields,
      'documents': docs.map((d) => d.toMap()).toList(),
      'status': 'submitted',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (existing == null) {
      await _supabase.from('loan_applications').insert({
        ...payload,
        'request_id': requestId,
        'borrower_id': uid,
        'lender_id': lenderId,
      });
    } else {
      await _supabase
          .from('loan_applications')
          .update({...payload, 'lender_message': null})
          .eq('id', existing.id)
          .eq('borrower_id', uid);
    }
  }

  // =========================
  // LENDER: DECISION
  // =========================

  Future<void> setStatus({
    required String applicationId,
    required String status,
    String? message,
  }) async {
    if (!{'more_info_required', 'approved', 'rejected'}.contains(status)) {
      throw Exception('Invalid application status.');
    }

    await _supabase
        .from('loan_applications')
        .update({
          'status': status,
          'lender_message': message,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', applicationId)
        .eq('lender_id', _uid);
  }

  // =========================
  // FILES
  // =========================

  /// The picker only allows pdf, jpg, jpeg and png.
  String _contentType(String fileName) {
    final name = fileName.toLowerCase();

    if (name.endsWith('.pdf')) return 'application/pdf';
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';

    return 'application/octet-stream';
  }

  Future<String> signedUrl(String path) {
    return _supabase.storage.from(bucket).createSignedUrl(path, 3600);
  }
}
