import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/loan_offer.dart';

class LoanOfferService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<LoanOffer>> getMyOffers() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User is not signed in.');
    }

    final data = await _supabase
        .from('loan_offers')
        .select()
        .eq('lender_id', user.id)
        .order('created_at', ascending: false);

    return (data as List)
        .map((item) => LoanOffer.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  Future<LoanOffer> addOffer({
    required String bankName,
    required String offerName,
    required String loanType,
    required double interestRate,
    required int term,
    required double amount,
    required String email,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User is not signed in.');
    }

    final profile = await _supabase
        .from('profiles')
        .select('bank_name')
        .eq('id', user.id)
        .maybeSingle();

    final lenderBankName = profile?['bank_name']?.toString().trim() ?? '';

    if (lenderBankName.isEmpty) {
      throw Exception('Bank name was not found for this lender.');
    }

    final data = await _supabase
        .from('loan_offers')
        .insert({
          'lender_id': user.id,
          'bank_name': lenderBankName,
          'offer_name': offerName,
          'loan_type': loanType,
          'interest_rate': interestRate,
          'max_term_months': term,
          'max_amount': amount,
          'contact_email': email,
          'is_active': true,
        })
        .select()
        .single();

    return LoanOffer.fromMap(data);
  }

  Future<LoanOffer> updateOffer({
    required String id,
    required String bankName,
    required String offerName,
    required String loanType,
    required double interestRate,
    required int term,
    required double amount,
    required String email,
  }) async {
    final data = await _supabase
        .from('loan_offers')
        .update({
          'bank_name': bankName,
          'offer_name': offerName,
          'loan_type': loanType,
          'interest_rate': interestRate,
          'max_term_months': term,
          'max_amount': amount,
          'contact_email': email,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .select()
        .single();

    return LoanOffer.fromMap(data);
  }

  Future<void> deleteOffer(String id) async {
    await _supabase.from('loan_offers').delete().eq('id', id);
  }

  Future<List<LoanOffer>> getActiveOffers() async {
    final data = await _supabase
        .from('loan_offers')
        .select()
        .eq('is_active', true)
        .order('interest_rate', ascending: true);

    return (data as List)
        .map((item) => LoanOffer.fromMap(item as Map<String, dynamic>))
        .toList();
  }
}
