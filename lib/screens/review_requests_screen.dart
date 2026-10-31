import 'package:flutter/material.dart';
import '../services/error_messages.dart';
import '../services/money_format.dart';

import '../models/app_settings.dart';
import '../services/loan_request_service.dart';

import 'lender_application_panel.dart';
import 'manage_offers_screen.dart';

class ReviewRequestsScreen extends StatefulWidget {
  const ReviewRequestsScreen({super.key});

  @override
  State<ReviewRequestsScreen> createState() => _ReviewRequestsScreenState();
}

class _ReviewRequestsScreenState extends State<ReviewRequestsScreen> {
  final LoanRequestService _requestService = LoanRequestService();

  List<LenderRequestData> requests = [];

  bool isLoading = true;

  String? errorMessage;

  @override
  void initState() {
    super.initState();

    _loadRequests();
  }

  Future<void> _loadRequests() async {
    try {
      final data = await _requestService.getLenderRequests();

      if (!mounted) return;

      setState(() {
        requests = data;
        isLoading = false;
        errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = friendlyError(error);
      });
    }
  }

  Future<void> _changeStatus(
    LenderRequestData request,
    String newStatus, {
    String? rejectionReason,
  }) async {
    try {
      await _requestService.updateRequestStatus(
        requestId: request.id,
        status: newStatus,
        rejectionReason: rejectionReason,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText(
            newStatus == 'approved'
                ? 'Request approved successfully.'
                : 'Request rejected.',
          ),
        ),
      );

      await _loadRequests();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(friendlyError(error)),
        ),
      );
    }
  }

  void _navigateToHome() {
    Navigator.pop(context);
  }

  void _openManageOffers() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ManageOffersScreen()),
    );
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
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 20,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
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

                    Row(
                      children: [
                        GestureDetector(
                          onTap: _navigateToHome,
                          child: _navItem('Home'),
                        ),

                        const SizedBox(width: 35),

                        GestureDetector(
                          onTap: _openManageOffers,
                          child: _navItem('Manage Offers'),
                        ),

                        const SizedBox(width: 35),

                        _navItem('Review Requests', active: true),
                      ],
                    ),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.lightBlue.withValues(alpha: .2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: AppText(
                        'New Requests: ${requests.where((r) => r.status == 'pending').length}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                            onPressed: _navigateToHome,
                          ),

                          const SizedBox(width: 10),

                          AppText(
                            'Review Requests',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const Spacer(),

                          IconButton(
                            tooltip: AppSettings.instance.tr('Refresh'),
                            onPressed: _loadRequests,
                            icon: const Icon(
                              Icons.refresh,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      Expanded(child: _buildContent()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),

            const SizedBox(height: 12),

            AppText(
              'Unable to load requests.',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60),
            ),

            const SizedBox(height: 15),

            ElevatedButton(
              onPressed: _loadRequests,
              child: AppText('Try Again'),
            ),
          ],
        ),
      );
    }

    if (requests.isEmpty) {
      return _empty();
    }

    return ListView.builder(
      itemCount: requests.length,
      itemBuilder: (context, index) {
        return _requestCard(requests[index]);
      },
    );
  }

  Widget _requestCard(LenderRequestData request) {
    final statusColor = request.status == 'approved'
        ? Colors.greenAccent
        : request.status == 'rejected'
        ? Colors.redAccent
        : Colors.amberAccent;

    final hasEligibility =
        request.eligibilityScore != null &&
        request.monthlyInstallment != null &&
        request.installmentRatio != null &&
        request.dtiRatio != null &&
        request.eligibilityClassification != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.person_outline,
                color: Colors.lightBlue,
                size: 34,
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      request.borrowerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 5),

                    AppText(
                      '${request.loanType} • ${formatSar(request.requestedAmount, decimals: 0)}',
                      style: const TextStyle(color: Colors.white70),
                    ),

                    if (request.borrowerPhone.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: AppText(
                          'Phone: ${request.borrowerPhone}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: AppText(
                  request.status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          AppText(
            'Borrower Financial Information',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _infoBox(
                'Monthly Income',
                formatSar(request.monthlyIncome, decimals: 0),
              ),
              _infoBox(
                'Current Monthly Obligations',
                formatSar(request.existingDebts, decimals: 0),
              ),
              _infoBox(
                'Monthly Expenses',
                formatSar(request.monthlyExpenses, decimals: 0),
              ),
              _infoBox(
                'Requested Amount',
                formatSar(request.requestedAmount, decimals: 0),
              ),
            ],
          ),

          if (hasEligibility) ...[
            const SizedBox(height: 22),

            AppText(
              'Eligibility Analysis',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: .08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _infoBox(
                        'Eligibility Score',
                        '${request.eligibilityScore!.toStringAsFixed(0)}%',
                      ),
                      _infoBox(
                        'Classification',
                        request.eligibilityClassification!,
                      ),
                      _infoBox(
                        'Monthly Installment',
                        formatSar(request.monthlyInstallment!, decimals: 2),
                      ),
                      _infoBox(
                        'DTI',
                        '${request.dtiRatio!.toStringAsFixed(2)}%',
                      ),
                      _infoBox(
                        'Installment Ratio',
                        '${request.installmentRatio!.toStringAsFixed(2)}%',
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  AppText(
                    'The eligibility result is a preliminary decision-support indicator and does not represent final loan approval.',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],

          if (request.status == 'approved')
            LenderApplicationPanel(
              key: ValueKey('application_${request.id}'),
              request: request,
            ),

          if (request.status == 'pending') ...[
            const SizedBox(height: 20),

            Row(
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  onPressed: () => _showApproveDialog(request),
                  icon: const Icon(Icons.check, color: Colors.white),
                  label: AppText(
                    'Approve',
                    style: TextStyle(color: Colors.white),
                  ),
                ),

                const SizedBox(width: 12),

                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                  ),
                  onPressed: () => _showRejectDialog(request),
                  icon: const Icon(Icons.close, color: Colors.white),
                  label: AppText(
                    'Reject',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showApproveDialog(LenderRequestData request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: AppText('Approve Request'),
          content: AppText('Are you sure you want to approve this request?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: AppText('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: AppText('Yes, Approve'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _changeStatus(request, 'approved');
    }
  }

  Future<void> _showRejectDialog(LenderRequestData request) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: AppText('Reject Request'),
          content: TextField(
            controller: reasonController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: AppSettings.instance.tr('Rejection Reason'),
              hintText: AppSettings.instance.tr(
                'Enter the reason for rejection',
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: AppText('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: AppText('Yes, Reject'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final reason = reasonController.text.trim();

      if (reason.isEmpty) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: AppText('Please enter a rejection reason.')),
        );

        reasonController.dispose();
        return;
      }

      await _changeStatus(request, 'rejected', rejectionReason: reason);
    }

    reasonController.dispose();
  }

  Widget _infoBox(String label, String value) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),

          const SizedBox(height: 5),

          AppText(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.assignment_outlined,
            color: Colors.lightBlue,
            size: 55,
          ),

          const SizedBox(height: 20),

          AppText(
            'No Borrower Requests',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          AppText(
            'Borrower loan applications will appear here.',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
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

        if (active)
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 25,
            height: 2,
            color: Colors.lightBlue,
          ),
      ],
    );
  }
}
