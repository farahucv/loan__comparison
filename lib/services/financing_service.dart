import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/financing.dart';
import 'financing_math.dart';

/// Talks to the simulated financing journey in Supabase.
///
/// All writes go through the rushd_* database functions; the tables are
/// read-only for the app. Errors are left as exceptions so screens can show
/// them with friendlyError().
///
/// Privacy: this class never prints or logs anything. The national ID,
/// IBAN and signing code must never be written to logs or analytics.
class FinancingService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Map<String, dynamic> _row(dynamic result) {
    if (result is List && result.isNotEmpty) {
      return Map<String, dynamic>.from(result.first as Map);
    }

    if (result is Map) return Map<String, dynamic>.from(result);

    throw Exception('Unexpected response from the server.');
  }

  // =========================
  // LENDER
  // =========================

  Future<FinancingOffer> issueOffer({
    required String applicationId,
    required double principal,
    required double annualProfitRate,
    required String rateType,
    required int termMonths,
    required double adminFee,
    int validDays = 7,
  }) async {
    final result = await _supabase.rpc(
      'rushd_issue_offer',
      params: {
        'p_application_id': applicationId,
        'p_principal': principal,
        'p_annual_profit_rate': annualProfitRate,
        'p_rate_type': rateType,
        'p_term_months': termMonths,
        'p_admin_fee': adminFee,
        'p_valid_days': validDays,
      },
    );

    return FinancingOffer.fromMap(_row(result));
  }

  Future<FinancingAgreement> disburse(String agreementId) async {
    final result = await _supabase.rpc(
      'rushd_disburse',
      params: {'p_agreement_id': agreementId},
    );

    return FinancingAgreement.fromMap(_row(result));
  }

  // =========================
  // BORROWER
  // =========================

  /// [consents] needs credit_bureau_consent, terms_read, simulation_ack and
  /// data_sharing set to true; early_disbursement_waiver is optional.
  Future<FinancingAgreement> acceptOffer({
    required String offerId,
    required Map<String, bool> consents,
  }) async {
    final result = await _supabase.rpc(
      'rushd_accept_offer',
      params: {'p_offer_id': offerId, 'p_consents': consents},
    );

    return FinancingAgreement.fromMap(_row(result));
  }

  Future<void> declineOffer({required String offerId, String? reason}) async {
    await _supabase.rpc(
      'rushd_decline_offer',
      params: {'p_offer_id': offerId, 'p_reason': reason},
    );
  }

  /// Returns the simulated signing code (no SMS is sent).
  Future<String> requestSigningCode(String agreementId) async {
    final result = await _supabase.rpc(
      'rushd_request_signing_code',
      params: {'p_agreement_id': agreementId},
    );

    return result.toString();
  }

  /// A wrong code returns ok = false with attempts_left (not an exception).
  Future<SignResult> signAgreement({
    required String agreementId,
    required String code,
  }) async {
    final result = await _supabase.rpc(
      'rushd_sign_agreement',
      params: {'p_agreement_id': agreementId, 'p_otp_code': code},
    );

    return SignResult.fromMap(_row(result));
  }

  Future<void> withdraw(String agreementId) async {
    await _supabase.rpc(
      'rushd_withdraw',
      params: {'p_agreement_id': agreementId},
    );
  }

  /// Cancel an accepted offer that is not signed yet.
  Future<void> cancelUnsigned(String agreementId) async {
    await _supabase.rpc(
      'rushd_cancel_unsigned',
      params: {'p_agreement_id': agreementId},
    );
  }

  // =========================
  // READ
  // =========================

  Future<FinancingOffer?> getOffer(String offerId) async {
    final row = await _supabase
        .from('financing_offers')
        .select()
        .eq('id', offerId)
        .maybeSingle();

    return row == null ? null : FinancingOffer.fromMap(row);
  }

  Future<List<FinancingOffer>> getOffersForApplication(
    String applicationId,
  ) async {
    final rows = await _supabase
        .from('financing_offers')
        .select()
        .eq('application_id', applicationId)
        .order('version', ascending: false);

    return rows.map((r) => FinancingOffer.fromMap(r)).toList();
  }

  Future<FinancingAgreement?> getAgreement(String agreementId) async {
    final row = await _supabase
        .from('financing_agreements')
        .select()
        .eq('id', agreementId)
        .maybeSingle();

    return row == null ? null : FinancingAgreement.fromMap(row);
  }

  Future<FinancingAgreement?> getAgreementForOffer(String offerId) async {
    final row = await _supabase
        .from('financing_agreements')
        .select()
        .eq('offer_id', offerId)
        .maybeSingle();

    return row == null ? null : FinancingAgreement.fromMap(row);
  }

  Future<List<RepaymentInstallment>> getSchedule(String agreementId) async {
    final rows = await _supabase
        .from('repayment_schedule')
        .select()
        .eq('agreement_id', agreementId)
        .order('installment_no', ascending: true);

    return rows.map((r) => RepaymentInstallment.fromMap(r)).toList();
  }

  Future<List<FinancingEvent>> getEvents(List<String> offerIds) async {
    if (offerIds.isEmpty) return [];

    final rows = await _supabase
        .from('financing_events')
        .select()
        .inFilter('offer_id', offerIds)
        .order('created_at', ascending: true);

    return rows.map((r) => FinancingEvent.fromMap(r)).toList();
  }

  Future<FinancingSettings> getSettings() async {
    Map<String, dynamic>? row;

    try {
      row = await _supabase
          .from('rushd_settings')
          .select(FinancingSettings.columns)
          .maybeSingle();
    } on PostgrestException {
      // unsigned_lapse_days not there yet: read the rest, default the lapse.
      row = await _supabase
          .from('rushd_settings')
          .select(FinancingSettings.columnsWithoutLapse)
          .maybeSingle();
    }

    return row == null
        ? const FinancingSettings()
        : FinancingSettings.fromMap(row);
  }

  // =========================
  // LENDER: PREVIEW & PIPELINE
  // =========================

  /// rushd_calc_financing: the same numbers the database will save. Only a
  /// preview; rushd_issue_offer recalculates and checks everything.
  Future<FinancingQuote> previewOffer({
    required double principal,
    required double annualProfitRate,
    required String rateType,
    required int termMonths,
    required double adminFee,
  }) async {
    final row = _row(
      await _supabase.rpc(
        'rushd_calc_financing',
        params: {
          'p_principal': principal,
          'p_annual_profit_rate': annualProfitRate,
          'p_rate_type': rateType,
          'p_term_months': termMonths,
          'p_admin_fee': adminFee,
        },
      ),
    );

    double n(String k) => double.tryParse(row[k]?.toString() ?? '') ?? 0;

    return FinancingQuote(
      monthlyInstallment: n('monthly_installment'),
      totalProfit: n('total_profit'),
      totalRepayable: n('total_repayable'),
      apr: n('apr'),
    );
  }

  /// rushd_borrower_obligations: declared debts + active Rushd installments.
  /// [borrowerId] defaults to the signed-in borrower.
  Future<BorrowerObligations> getObligations([String? borrowerId]) async {
    final id = borrowerId ?? _supabase.auth.currentUser?.id;

    if (id == null) throw Exception('You must sign in first.');

    final result = await _supabase.rpc(
      'rushd_borrower_obligations',
      params: {'p_borrower_id': id},
    );

    return BorrowerObligations.fromMap(_row(result));
  }

  /// rushd_admin_fee_cap: least(1% of the amount, SAR 5,000) by default.
  Future<double> adminFeeCap(double principal) async {
    final result = await _supabase.rpc(
      'rushd_admin_fee_cap',
      params: {'p_principal': principal},
    );

    return double.tryParse(result.toString()) ?? 0;
  }

  /// The loan offer a request was made on: its rate, term and maximum.
  Future<LoanOfferTerms?> getLoanOfferTerms(String requestId) async {
    final request = await _supabase
        .from('loan_requests')
        .select('offer_id')
        .eq('id', requestId)
        .maybeSingle();

    final offerId = request?['offer_id']?.toString();

    if (offerId == null) return null;

    final offer = await _supabase
        .from('loan_offers')
        .select('interest_rate, max_term_months, max_amount')
        .eq('id', offerId)
        .maybeSingle();

    if (offer == null) return null;

    return LoanOfferTerms(
      interestRate:
          double.tryParse(offer['interest_rate']?.toString() ?? '') ?? 0,
      maxTermMonths:
          int.tryParse(offer['max_term_months']?.toString() ?? '') ?? 0,
      maxAmount: double.tryParse(offer['max_amount']?.toString() ?? '') ?? 0,
    );
  }

  /// Lender: approved applications with their latest offer and agreement,
  /// keyed by request id.
  Future<Map<String, ({FinancingOffer? offer, FinancingAgreement? agreement})>>
  getLenderPipeline() async {
    final user = _supabase.auth.currentUser;

    if (user == null) throw Exception('Lender is not signed in.');

    final applications = await _supabase
        .from('loan_applications')
        .select('id, request_id')
        .eq('lender_id', user.id)
        .eq('status', 'approved');

    final offerRows = await _supabase
        .from('financing_offers')
        .select()
        .eq('lender_id', user.id)
        .order('version', ascending: false);

    final agreementRows = await _supabase
        .from('financing_agreements')
        .select()
        .eq('lender_id', user.id);

    final latestOffer = <String, FinancingOffer>{};

    for (final row in offerRows) {
      final offer = FinancingOffer.fromMap(row);
      latestOffer.putIfAbsent(offer.applicationId, () => offer);
    }

    final agreementByOffer = {
      for (final row in agreementRows)
        row['offer_id'].toString(): FinancingAgreement.fromMap(row),
    };

    return {
      for (final app in applications)
        app['request_id'].toString(): () {
          final offer = latestOffer[app['id'].toString()];

          return (
            offer: offer,
            agreement: offer == null ? null : agreementByOffer[offer.id],
          );
        }(),
    };
  }

  /// Request id -> where that request is in the journey, for the
  /// Request Status screen. Uses the latest offer version per application.
  Future<Map<String, BorrowerJourney>> getBorrowerJourneys(
    Map<String, String> requestStatuses,
  ) async {
    final user = _supabase.auth.currentUser;

    if (user == null) throw Exception('You must sign in first.');

    final applications = await _supabase
        .from('loan_applications')
        .select('id, request_id, status')
        .eq('borrower_id', user.id);

    final offerRows = await _supabase
        .from('financing_offers')
        .select()
        .eq('borrower_id', user.id)
        .order('version', ascending: false);

    final agreementRows = await _supabase
        .from('financing_agreements')
        .select()
        .eq('borrower_id', user.id);

    final latestOffer = <String, FinancingOffer>{};

    for (final row in offerRows) {
      final offer = FinancingOffer.fromMap(row);
      latestOffer.putIfAbsent(offer.applicationId, () => offer);
    }

    final agreementByOffer = {
      for (final row in agreementRows)
        row['offer_id'].toString(): FinancingAgreement.fromMap(row),
    };

    final applicationByRequest = {
      for (final row in applications) row['request_id'].toString(): row,
    };

    return {
      for (final entry in requestStatuses.entries)
        entry.key: () {
          final app = applicationByRequest[entry.key];
          final appId = app?['id']?.toString();
          final offer = appId == null ? null : latestOffer[appId];

          return BorrowerJourney(
            requestStatus: entry.value,
            applicationId: appId,
            applicationStatus: app?['status']?.toString(),
            offer: offer,
            agreement: offer == null ? null : agreementByOffer[offer.id],
          );
        }(),
    };
  }
}
