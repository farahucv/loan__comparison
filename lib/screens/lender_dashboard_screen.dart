import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_settings.dart';

import 'manage_offers_screen.dart';
import 'review_requests_screen.dart';
import 'home_screen.dart';
import 'add_offer_screen.dart';

import '../models/loan_offer.dart';
import '../models/dashboard_stats.dart';

import '../services/dashboard_service.dart';
import '../services/loan_offer_service.dart';

class LenderDashboardScreen extends StatefulWidget {
  final String lenderName;
  final String bankName;

  const LenderDashboardScreen({
    super.key,
    required this.lenderName,
    required this.bankName,
  });

  @override
  State<LenderDashboardScreen> createState() => _LenderDashboardScreenState();
}

class _LenderDashboardScreenState extends State<LenderDashboardScreen> {
  String getBankLogo(String bankName) {
    switch (bankName) {
      case "Al Rajhi Bank":
        return "assets/images/Alrajhi-Bank-Logo.png";

      case "Riyad Bank":
        return "assets/images/Riyad-Bank-Logo.png";

      case "Saudi National Bank":
        return "assets/images/Saudi_National_Bank_Logo.png";

      case "Bank Albilad":
        return "assets/images/Albilad-Bank-Logo.png";

      default:
        return "assets/images/rushd_log.png";
    }
  }

  List<LoanOffer> offersList = [];

  final DashboardService service = DashboardService();

  final LoanOfferService offerService = LoanOfferService();

  DashboardStats? stats;

  bool isLoadingOffers = true;

  @override
  void initState() {
    super.initState();

    loadOffers();
  }

  Future<void> loadOffers() async {
    try {
      if (mounted) {
        setState(() {
          isLoadingOffers = true;
        });
      }

      final offers = await offerService.getMyOffers();

      final dashboardStats = await service.getDashboardStats(offers);

      if (!mounted) return;

      setState(() {
        offersList = offers;
        stats = dashboardStats;
        isLoadingOffers = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoadingOffers = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading dashboard: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> loadStats() async {
    try {
      final result = await service.getDashboardStats(offersList);

      if (!mounted) return;

      setState(() {
        stats = result;
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading statistics: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // REAL SUPABASE SIGN OUT
  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error signing out: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _openManageOffers(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ManageOffersScreen(offers: offersList),
      ),
    );

    // Refresh offers and dashboard statistics
    await loadOffers();
  }

  Future<void> _openAddOffer(BuildContext context) async {
    final newOffer = await Navigator.push<LoanOffer>(
      context,
      MaterialPageRoute(builder: (context) => const AddOfferScreen()),
    );

    if (newOffer != null) {
      await loadOffers();
    }
  }

  Future<void> _openReviewRequests(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ReviewRequestsScreen()),
    );

    // Refresh request numbers after returning
    // from Review Requests.
    await loadOffers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppPalette.bg1, AppPalette.bg2, AppPalette.bg3],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // =========================
              // TOP BAR
              // =========================

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 20,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // LOGO
                    Image.asset(
                      'assets/images/rushd_log.png',
                      width: 180,
                      errorBuilder: (context, error, stackTrace) => AppText(
                        'Rushd',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    // NAVIGATION
                    Row(
                      children: [
                        _navItem("Home", active: true),

                        const SizedBox(width: 35),

                        GestureDetector(
                          onTap: () => _openManageOffers(context),
                          child: _navItem("Manage Offers"),
                        ),

                        const SizedBox(width: 35),

                        GestureDetector(
                          onTap: () => _openReviewRequests(context),
                          child: _navItem("Review Requests"),
                        ),
                      ],
                    ),

                    // SIGN OUT
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.lightBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),

                      // Supabase sign out
                      onPressed: _signOut,

                      child: AppText(
                        "Sign Out",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // =========================
              // MAIN CONTENT
              // =========================
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 20,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      bool isMobile = constraints.maxWidth < 900;

                      return Flex(
                        direction: isMobile ? Axis.vertical : Axis.horizontal,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // =========================
                          // LEFT PANEL
                          // =========================

                          Flexible(
                            flex: isMobile ? 0 : 5,
                            child: Container(
                              padding: const EdgeInsets.all(30),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.lock_outline,
                                          color: Colors.white60,
                                          size: 14,
                                        ),

                                        const SizedBox(width: 6),

                                        AppText(
                                          "Lender Representative Dashboard",
                                          style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 25),

                                  AppText(
                                    "Welcome,\n${widget.lenderName}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 34,
                                      fontWeight: FontWeight.bold,
                                      height: 1.2,
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  Container(
                                    width: 170,
                                    height: 85,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: Image.asset(
                                      getBankLogo(widget.bankName),
                                      fit: BoxFit.contain,
                                    ),
                                  ),

                                  const SizedBox(height: 35),

                                  if (isLoadingOffers)
                                    const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  else
                                    Column(
                                      children: [
                                        Row(
                                          children: [
                                            _statCard(
                                              "Active Offers",
                                              stats?.activeOffers.toString() ??
                                                  "0",
                                            ),

                                            const SizedBox(width: 10),

                                            _statCard(
                                              "Bank Requests",
                                              stats?.submittedRequests
                                                      .toString() ??
                                                  "0",
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 10),

                                        Row(
                                          children: [
                                            _statCard(
                                              "Pending Requests",
                                              stats?.pendingRequests
                                                      .toString() ??
                                                  "0",
                                            ),

                                            const SizedBox(width: 10),

                                            _statCard(
                                              "Average Rate",
                                              "${stats?.averageRate.toStringAsFixed(2) ?? '0'}%",
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),

                          SizedBox(
                            width: isMobile ? 0 : 25,
                            height: isMobile ? 25 : 0,
                          ),

                          // =========================
                          // RIGHT PANEL
                          // =========================
                          Flexible(
                            flex: isMobile ? 0 : 6,
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _actionCard(
                                        context,
                                        title: "Manage Offers",
                                        description:
                                            "Edit, update, or delete your bank's offers.",
                                        icon: Icons.grid_view_rounded,
                                        onTap: () => _openManageOffers(context),
                                      ),
                                    ),

                                    const SizedBox(width: 20),

                                    Expanded(
                                      child: _actionCard(
                                        context,
                                        title: "Review Requests",
                                        description:
                                            "Check borrower applications.",
                                        icon: Icons.check_circle_outline,
                                        onTap: () =>
                                            _openReviewRequests(context),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 20),

                                _actionCard(
                                  context,
                                  title: "Add New Offer",
                                  description:
                                      "Create a new financing offer for ${widget.bankName}.",
                                  icon: Icons.add,
                                  isFullWidth: true,
                                  onTap: () => _openAddOffer(context),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(String title, {bool active = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppText(
          title,
          style: TextStyle(
            color: active ? Colors.lightBlue : Colors.white60,
            fontSize: 14,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),

        if (active) ...[
          const SizedBox(height: 4),
          Container(width: 25, height: 2, color: Colors.lightBlue),
        ],
      ],
    );
  }

  Widget _statCard(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              label,
              style: const TextStyle(color: Colors.white60, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 6),

            AppText(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
    bool isFullWidth = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(25),
      child: Container(
        width: isFullWidth ? double.infinity : null,
        height: isFullWidth ? 160 : 180,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.lightBlue, size: 32),

            const SizedBox(height: 16),

            AppText(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            AppText(
              description,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
