import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/error_messages.dart';

import '../models/app_settings.dart';

import 'manage_offers_screen.dart';
import 'review_requests_screen.dart';
import 'home_screen.dart';
import 'add_offer_screen.dart';
import 'lender_pipeline.dart';

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

  bool isCheckingVerification = true;
  bool isVerified = false;

  @override
  void initState() {
    super.initState();

    _start();
  }

  Future<void> _start() async {
    await _checkVerification();

    if (isVerified) {
      await loadOffers();
    }
  }

  Future<void> _checkVerification() async {
    try {
      final verified = await service.isLenderVerified();

      if (!mounted) return;

      setState(() {
        isVerified = verified;
        isCheckingVerification = false;
      });
    } catch (_) {
      if (!mounted) return;

      // The database rules still block unverified lenders,
      // so keep the dashboard working if this check fails.
      setState(() {
        isVerified = true;
        isCheckingVerification = false;
      });
    }
  }

  Future<void> _checkAgain() async {
    setState(() {
      isCheckingVerification = true;
    });

    await _start();

    if (!mounted || isVerified) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppSettings.instance.tr(
            'Your account is still pending verification.',
          ),
        ),
      ),
    );
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
          content: Text(
            '${AppSettings.instance.tr('Error loading dashboard:')} ${friendlyError(error)}',
          ),
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
          content: Text(
            '${AppSettings.instance.tr('Error loading statistics:')} ${friendlyError(error)}',
          ),
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
          content: Text(
            '${AppSettings.instance.tr('Error signing out:')} ${friendlyError(error)}',
          ),
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

              LayoutBuilder(
                builder: (context, box) => box.maxWidth < 820
                    ? _compactTopBar(context)
                    : Padding(
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
                              errorBuilder: (context, error, stackTrace) =>
                                  AppText(
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

                                if (isVerified && !isCheckingVerification) ...[
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
              ),

              // =========================
              // MAIN CONTENT
              // =========================
              Expanded(
                child: isCheckingVerification
                    ? const Center(child: CircularProgressIndicator())
                    : !isVerified
                    ? _pendingVerification()
                    : SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: MediaQuery.sizeOf(context).width < 600
                              ? 16
                              : 40,
                          vertical: 20,
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            bool isMobile = constraints.maxWidth < 900;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Flex(
                                  direction: isMobile
                                      ? Axis.vertical
                                      : Axis.horizontal,
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
                                          color: Colors.white.withValues(
                                            alpha: 0.08,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            25,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(
                                                  alpha: 0.08,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(20),
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
                                                color: Colors.white.withValues(
                                                  alpha: 0.08,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                              ),
                                              child: Image.asset(
                                                getBankLogo(widget.bankName),
                                                fit: BoxFit.contain,
                                              ),
                                            ),

                                            const SizedBox(height: 35),

                                            if (isLoadingOffers)
                                              const Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              )
                                            else
                                              Column(
                                                children: [
                                                  Row(
                                                    children: [
                                                      _statCard(
                                                        "Active Offers",
                                                        stats?.activeOffers
                                                                .toString() ??
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
                                                  onTap: () =>
                                                      _openManageOffers(
                                                        context,
                                                      ),
                                                ),
                                              ),

                                              const SizedBox(width: 20),

                                              Expanded(
                                                child: _actionCard(
                                                  context,
                                                  title: "Review Requests",
                                                  description:
                                                      "Check borrower applications.",
                                                  icon: Icons
                                                      .check_circle_outline,
                                                  onTap: () =>
                                                      _openReviewRequests(
                                                        context,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),

                                          const SizedBox(height: 20),

                                          _actionCard(
                                            context,
                                            title: "Add New Offer",
                                            description:
                                                AppSettings.instance.isArabic
                                                ? "أنشئ عرض تمويل جديدًا لـ ${AppSettings.instance.tr(widget.bankName)}."
                                                : "Create a new financing offer for ${widget.bankName}.",
                                            icon: Icons.add,
                                            isFullWidth: true,
                                            onTap: () => _openAddOffer(context),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 25),

                                // Approved applications by financing stage.
                                const FinancingPipelineSection(),
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

  /// Phones and narrow windows: logo + menu.
  Widget _compactTopBar(BuildContext context) {
    final verified = isVerified && !isCheckingVerification;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Image.asset(
            'assets/images/rushd_log.png',
            width: 110,
            errorBuilder: (context, error, stackTrace) => AppText(
              'Rushd',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Spacer(),
          PopupMenuButton<int>(
            tooltip: AppSettings.instance.tr('Menu'),
            icon: const Icon(Icons.menu, color: Colors.white),
            color: const Color(0xff1E0B36),
            onSelected: (i) {
              if (i == 1) _openManageOffers(context);
              if (i == 2) _openReviewRequests(context);
              if (i == 3) _signOut();
            },
            itemBuilder: (_) => [
              if (verified) ...[
                PopupMenuItem(
                  value: 1,
                  child: Text(
                    AppSettings.instance.tr('Manage Offers'),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                PopupMenuItem(
                  value: 2,
                  child: Text(
                    AppSettings.instance.tr('Review Requests'),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const PopupMenuDivider(),
              ],
              PopupMenuItem(
                value: 3,
                child: Text(
                  AppSettings.instance.tr('Sign Out'),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pendingVerification() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            padding: const EdgeInsets.all(36),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.hourglass_top_rounded,
                  color: Colors.lightBlue,
                  size: 52,
                ),

                const SizedBox(height: 20),

                AppText(
                  "Welcome,\n${widget.lenderName}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 14),

                AppText(
                  "Your lender account is pending verification by Rushd",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                ),

                const SizedBox(height: 14),

                AppText(
                  "Thank you for registering. Before you can publish loan offers and review borrower requests, the Rushd team needs to confirm your account. You will get full access as soon as it is verified.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 28),

                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                  ),
                  onPressed: _checkAgain,
                  icon: const Icon(Icons.refresh),
                  label: AppText(
                    "Check Again",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
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
          color: Colors.white.withValues(alpha: 0.05),
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
          color: Colors.white.withValues(alpha: 0.08),
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
