import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/dashboard_stats.dart';
import '../models/loan_offer.dart';

class DashboardService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<DashboardStats> getDashboardStats(List<LoanOffer> offers) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Lender is not signed in.');
    }

    // Active offers
    final int activeOffers = offers.length;

    // Average interest rate
    double totalRate = 0;

    for (final offer in offers) {
      totalRate += double.tryParse(offer.interestRate.replaceAll('%', '')) ?? 0;
    }

    final double averageRate = offers.isEmpty ? 0 : totalRate / offers.length;

    // Requests received by this lender
    final requestRows = await _supabase
        .from('loan_requests')
        .select('status')
        .eq('lender_id', user.id);

    final int submittedRequests = requestRows.length;

    final int pendingRequests = requestRows
        .where((row) => row['status']?.toString().toLowerCase() == 'pending')
        .length;

    return DashboardStats(
      activeOffers: activeOffers,
      submittedRequests: submittedRequests,
      pendingRequests: pendingRequests,
      averageRate: averageRate,
    );
  }
}
