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

/// One item the lender asks for with "Request more information".
class InfoRequestItem {
  final String id;

  /// document | field | other
  final String type;

  /// Document category, for type = document (e.g. 'Salary Certificate').
  final String category;

  /// Column name, for type = field (e.g. 'employer').
  final String field;

  final String note;

  const InfoRequestItem({
    required this.id,
    required this.type,
    this.category = '',
    this.field = '',
    this.note = '',
  });

  factory InfoRequestItem.fromMap(Map<String, dynamic> map) => InfoRequestItem(
    id: map['id']?.toString() ?? '',
    type: map['type']?.toString() ?? 'other',
    category: map['category']?.toString() ?? '',
    field: map['field']?.toString() ?? '',
    note: map['note']?.toString() ?? '',
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type,
    if (type == 'document') 'category': category,
    if (type == 'field') 'field': field,
    if (note.trim().isNotEmpty) 'note': note.trim(),
  };
}

/// Fields the lender can ask the borrower to correct: column -> label.
const Map<String, String> infoRequestFields = {
  'full_name': 'Full name',
  'national_id': 'National ID',
  'date_of_birth': 'Date of birth',
  'address': 'Address',
  'employer': 'Employer',
  'job_title': 'Job title',
  'employment_sector': 'Sector',
  'years_at_job': 'Years at job',
  'iban': 'IBAN',
};

/// Document categories the lender can ask for.
const List<String> infoRequestDocuments = [
  'National ID',
  'Salary Certificate',
  'Bank Statement',
  'Other',
];

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

  /// What the lender asked for in the last "more information" request.
  final List<InfoRequestItem> infoRequests;
  final String borrowerResponse;

  /// 1 for the first submission, +1 per resubmission (set by the database).
  final int reviewRound;

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
    this.infoRequests = const [],
    this.borrowerResponse = '',
    this.reviewRound = 1,
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
      infoRequests: [
        if (row['info_requests'] is List)
          for (final item in row['info_requests'] as List)
            if (item is Map)
              InfoRequestItem.fromMap(Map<String, dynamic>.from(item)),
      ],
      borrowerResponse: row['borrower_response']?.toString() ?? '',
      reviewRound: int.tryParse(row['review_round']?.toString() ?? '') ?? 1,
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
    String? borrowerResponse,
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
      // review_round is increased by the database, not here.
      await _supabase
          .from('loan_applications')
          .update({
            ...payload,
            'lender_message': null,
            if (borrowerResponse != null)
              'borrower_response': borrowerResponse.trim(),
          })
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
    List<InfoRequestItem> infoRequests = const [],
  }) async {
    if (!{'more_info_required', 'approved', 'rejected'}.contains(status)) {
      throw Exception('Invalid application status.');
    }

    if (status == 'more_info_required' && infoRequests.isEmpty) {
      throw Exception('Request at least one item from the borrower');
    }

    await _supabase
        .from('loan_applications')
        .update({
          'status': status,
          'lender_message': message,
          if (status == 'more_info_required')
            'info_requests': infoRequests.map((i) => i.toMap()).toList(),
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
