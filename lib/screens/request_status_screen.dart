import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../services/loan_request_service.dart';

import 'borrower_ui.dart';

class RequestStatusScreen extends StatefulWidget {
  const RequestStatusScreen({super.key});

  @override
  State<RequestStatusScreen> createState() => _RequestStatusScreenState();
}

class _RequestStatusScreenState extends State<RequestStatusScreen> {
  final LoanRequestService _requestService = LoanRequestService();

  List<BorrowerRequestData> requests = [];

  bool isLoading = true;

  String? errorMessage;

  @override
  void initState() {
    super.initState();

    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final data = await _requestService.getBorrowerRequests();

      if (!mounted) return;

      setState(() {
        requests = data;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BorrowerShell(
      active: 2,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 38),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            'Request Status',
                            style: white(28, w: FontWeight.w900),
                          ),

                          const SizedBox(height: 5),

                          AppText(
                            'Track your submitted loan requests.',
                            style: white(12, c: Colors.white54),
                          ),
                        ],
                      ),
                    ),

                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: _loadRequests,
                      icon: const Icon(Icons.refresh, color: Colors.white),
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                _buildContent(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (errorMessage != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: panel(),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 45),

            const SizedBox(height: 12),

            AppText(
              'Unable to load requests.',
              style: white(17, w: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54),
            ),

            const SizedBox(height: 15),

            ElevatedButton(
              onPressed: _loadRequests,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (requests.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(34),
        decoration: panel(),
        child: Column(
          children: [
            const Icon(Icons.assignment_outlined, color: kCyan, size: 48),

            const SizedBox(height: 12),

            AppText(
              'No submitted requests yet.',
              style: white(17, w: FontWeight.bold),
            ),

            const SizedBox(height: 6),

            AppText(
              'Choose a loan offer and submit it through Rushd to track it here.',
              textAlign: TextAlign.center,
              style: white(11, c: Colors.white54),
            ),
          ],
        ),
      );
    }

    return Column(
      children: requests
          .map(
            (request) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _requestCard(request),
            ),
          )
          .toList(),
    );
  }

  Widget _requestCard(BorrowerRequestData request) {
    final status = request.status.toLowerCase();

    Color statusColor;

    IconData statusIcon;

    String statusTitle;

    if (status == 'approved') {
      statusColor = Colors.greenAccent;
      statusIcon = Icons.check_circle;
      statusTitle = 'APPROVED';
    } else if (status == 'rejected') {
      statusColor = Colors.redAccent;
      statusIcon = Icons.cancel;
      statusTitle = 'REJECTED';
    } else {
      statusColor = Colors.amberAccent;
      statusIcon = Icons.schedule;
      statusTitle = 'PENDING';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 55,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance, color: kBlue),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      request.bankName,
                      style: white(17, w: FontWeight.bold),
                    ),

                    const SizedBox(height: 4),

                    AppText(request.offerName, style: white(11, c: kCyan)),

                    const SizedBox(height: 3),

                    AppText(
                      '${request.loanType} • SAR ${request.requestedAmount.toStringAsFixed(0)}',
                      style: white(10, c: Colors.white54),
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
                  color: statusColor.withOpacity(.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 16),

                    const SizedBox(width: 6),

                    AppText(
                      statusTitle,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withOpacity(.25)),
            ),
            child: AppText(
              _statusMessage(request),
              style: white(11, c: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  String _statusMessage(BorrowerRequestData request) {
    final status = request.status.toLowerCase();

    if (status == 'approved') {
      return 'Your loan request has been approved by the lender.';
    }

    if (status == 'rejected') {
      final reason = request.rejectionReason?.trim() ?? '';

      if (reason.isNotEmpty) {
        return 'Your loan request was not approved by the lender.\nReason: $reason';
      }

      return 'Your loan request was not approved by the lender.';
    }

    return 'Your request is currently under review by the lender.';
  }
}
