import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../services/loan_request_service.dart';
import '../services/money_format.dart';
import 'borrower_ui.dart';
import 'journey_ui.dart';
import 'lender_application_panel.dart';

/// One borrower's application on its own page (opened from the lender's
/// financing pipeline).
class LenderApplicationScreen extends StatelessWidget {
  final LenderRequestData request;

  const LenderApplicationScreen({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: rushdBackground(),
        child: SafeArea(
          child: JourneyPage(
            maxWidth: 900,
            children: [
              JourneyHeader(
                title: request.borrowerName,
                subtitle:
                    '${AppSettings.instance.tr(request.loanType)} • ${formatSar(request.requestedAmount, decimals: 0)}',
              ),
              LenderApplicationPanel(request: request),
            ],
          ),
        ),
      ),
    );
  }
}
