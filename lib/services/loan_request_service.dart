import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/loan_offer.dart';

class LenderRequestData {
  final String id;
  final String borrowerId;
  final String borrowerName;
  final String borrowerPhone;

  final String loanType;
  final double requestedAmount;

  final double monthlyIncome;
  final double existingDebts;
  final double monthlyExpenses;

  final double? eligibilityScore;
  final double? monthlyInstallment;
  final double? installmentRatio;
  final double? dtiRatio;
  final String? eligibilityClassification;

  final String status;
  final String? rejectionReason;
  final DateTime? createdAt;

  LenderRequestData({
    required this.id,
    required this.borrowerId,
    required this.borrowerName,
    required this.borrowerPhone,
    required this.loanType,
    required this.requestedAmount,
    required this.monthlyIncome,
    required this.existingDebts,
    required this.monthlyExpenses,
    required this.eligibilityScore,
    required this.monthlyInstallment,
    required this.installmentRatio,
    required this.dtiRatio,
    required this.eligibilityClassification,
    required this.status,
    required this.rejectionReason,
    required this.createdAt,
  });
}

class BorrowerRequestData {
  final String id;

  final String bankName;
  final String offerName;

  final String loanType;
  final double requestedAmount;

  final double? eligibilityScore;
  final double? monthlyInstallment;
  final double? installmentRatio;
  final double? dtiRatio;
  final String? eligibilityClassification;

  final String status;
  final String? rejectionReason;

  final DateTime? createdAt;

  BorrowerRequestData({
    required this.id,
    required this.bankName,
    required this.offerName,
    required this.loanType,
    required this.requestedAmount,
    required this.eligibilityScore,
    required this.monthlyInstallment,
    required this.installmentRatio,
    required this.dtiRatio,
    required this.eligibilityClassification,
    required this.status,
    required this.rejectionReason,
    required this.createdAt,
  });
}

class LoanRequestService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // =========================
  // SUBMIT BORROWER REQUEST
  // =========================

  Future<void> submitRequest({
    required LoanOffer offer,
    required double requestedAmount,
    required String loanType,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Borrower is not signed in.');
    }

    if (offer.id.isEmpty || offer.lenderId.isEmpty) {
      throw Exception('Offer information is incomplete.');
    }

    // Eligibility values are calculated automatically
    // by the Supabase database trigger.
    await _supabase.from('loan_requests').insert({
      'borrower_id': user.id,
      'offer_id': offer.id,
      'lender_id': offer.lenderId,
      'loan_type': loanType,
      'requested_amount': requestedAmount,
      'status': 'pending',
    });
  }

  // =========================
  // BORROWER REQUESTS
  // =========================

  Future<List<BorrowerRequestData>> getBorrowerRequests() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Borrower is not signed in.');
    }

    final requestRows = await _supabase
        .from('loan_requests')
        .select()
        .eq('borrower_id', user.id)
        .order('created_at', ascending: false);

    final List<BorrowerRequestData> results = [];

    for (final row in requestRows) {
      final offerId = row['offer_id']?.toString() ?? '';

      String bankName = 'Bank';
      String offerName = 'Loan Offer';

      if (offerId.isNotEmpty) {
        final offer = await _supabase
            .from('loan_offers')
            .select('bank_name, offer_name')
            .eq('id', offerId)
            .maybeSingle();

        if (offer != null) {
          bankName = offer['bank_name']?.toString() ?? 'Bank';

          offerName = offer['offer_name']?.toString() ?? 'Loan Offer';
        }
      }

      results.add(
        BorrowerRequestData(
          id: row['id']?.toString() ?? '',
          bankName: bankName,
          offerName: offerName,
          loanType: row['loan_type']?.toString() ?? '',
          requestedAmount: _toDouble(row['requested_amount']),
          eligibilityScore: _toNullableDouble(row['eligibility_score']),
          monthlyInstallment: _toNullableDouble(row['monthly_installment']),
          installmentRatio: _toNullableDouble(row['installment_ratio']),
          dtiRatio: _toNullableDouble(row['dti_ratio']),
          eligibilityClassification: row['eligibility_classification']
              ?.toString(),
          status: row['status']?.toString() ?? 'pending',
          rejectionReason: row['rejection_reason']?.toString(),
          createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
        ),
      );
    }

    return results;
  }

  // =========================
  // LENDER REQUESTS
  // =========================

  Future<List<LenderRequestData>> getLenderRequests() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Lender is not signed in.');
    }

    final requestRows = await _supabase
        .from('loan_requests')
        .select()
        .eq('lender_id', user.id)
        .order('created_at', ascending: false);

    final List<LenderRequestData> results = [];

    for (final row in requestRows) {
      final borrowerId = row['borrower_id']?.toString() ?? '';

      final profile = await _supabase
          .from('profiles')
          .select('full_name, phone')
          .eq('id', borrowerId)
          .maybeSingle();

      final financial = await _supabase
          .from('borrower_profiles')
          .select('monthly_income, existing_debts, monthly_expenses')
          .eq('user_id', borrowerId)
          .maybeSingle();

      results.add(
        LenderRequestData(
          id: row['id']?.toString() ?? '',
          borrowerId: borrowerId,
          borrowerName: profile?['full_name']?.toString() ?? 'Borrower',
          borrowerPhone: profile?['phone']?.toString() ?? '',
          loanType: row['loan_type']?.toString() ?? '',
          requestedAmount: _toDouble(row['requested_amount']),
          monthlyIncome: _toDouble(financial?['monthly_income']),
          existingDebts: _toDouble(financial?['existing_debts']),
          monthlyExpenses: _toDouble(financial?['monthly_expenses']),
          eligibilityScore: _toNullableDouble(row['eligibility_score']),
          monthlyInstallment: _toNullableDouble(row['monthly_installment']),
          installmentRatio: _toNullableDouble(row['installment_ratio']),
          dtiRatio: _toNullableDouble(row['dti_ratio']),
          eligibilityClassification: row['eligibility_classification']
              ?.toString(),
          status: row['status']?.toString() ?? 'pending',
          rejectionReason: row['rejection_reason']?.toString(),
          createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
        ),
      );
    }

    return results;
  }

  // =========================
  // APPROVE / REJECT
  // =========================

  Future<void> updateRequestStatus({
    required String requestId,
    required String status,
    String? rejectionReason,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Lender is not signed in.');
    }

    if (status != 'approved' && status != 'rejected') {
      throw Exception('Invalid request status.');
    }

    await _supabase
        .from('loan_requests')
        .update({
          'status': status,
          'rejection_reason': status == 'rejected' ? rejectionReason : null,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', requestId)
        .eq('lender_id', user.id);
  }

  double _toDouble(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0;
  }

  double? _toNullableDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString());
  }
}
