import 'package:flutter/material.dart';

import '../models/financing.dart';
import '../services/loan_request_service.dart';
import 'financing_offer_screen.dart';
import 'financing_status_screen.dart';
import 'loan_application_screen.dart';
import 'sign_agreement_screen.dart';

/// How a journey stage is shown on the Request Status cards.
class StageInfo {
  final String label;
  final Color color;
  final IconData icon;

  /// 1..6: Request, Application, Offer, Signing, Cooling-off, Active
  final int step;

  const StageInfo(this.label, this.color, this.icon, this.step);
}

const List<String> journeySteps = [
  'Request',
  'Application',
  'Offer',
  'Signing',
  'Cooling-off',
  'Active',
];

StageInfo stageInfo(JourneyStage stage) {
  switch (stage) {
    case JourneyStage.requestPending:
      return const StageInfo(
        'Waiting for the lender to review your request',
        Colors.amberAccent,
        Icons.schedule,
        1,
      );
    case JourneyStage.requestRejected:
      return const StageInfo(
        'Request not approved',
        Colors.redAccent,
        Icons.cancel,
        1,
      );
    case JourneyStage.applicationNeeded:
      return const StageInfo(
        'Request approved — complete your application',
        Colors.lightBlueAccent,
        Icons.edit_document,
        2,
      );
    case JourneyStage.applicationUnderReview:
      return const StageInfo(
        'Application under review by the bank',
        Colors.amberAccent,
        Icons.hourglass_top,
        2,
      );
    case JourneyStage.applicationNeedsInfo:
      return const StageInfo(
        'The bank needs more information',
        Colors.orangeAccent,
        Icons.error_outline,
        2,
      );
    case JourneyStage.applicationRejected:
      return const StageInfo(
        'Application not approved',
        Colors.redAccent,
        Icons.cancel,
        2,
      );
    case JourneyStage.waitingForOffer:
      return const StageInfo(
        'Application approved — waiting for the final offer',
        Colors.lightBlueAccent,
        Icons.hourglass_top,
        3,
      );
    case JourneyStage.offerReady:
      return const StageInfo(
        'Your final offer is ready',
        Colors.greenAccent,
        Icons.local_offer_outlined,
        3,
      );
    case JourneyStage.offerDeclined:
      return const StageInfo(
        'You declined the offer',
        Colors.white54,
        Icons.do_not_disturb_on_outlined,
        3,
      );
    case JourneyStage.offerExpired:
      return const StageInfo(
        'The offer expired',
        Colors.white54,
        Icons.timer_off_outlined,
        3,
      );
    case JourneyStage.awaitingSignature:
      return const StageInfo(
        'Offer accepted — sign the agreement',
        Colors.lightBlueAccent,
        Icons.draw_outlined,
        4,
      );
    case JourneyStage.coolingOff:
      return const StageInfo(
        'Agreement signed — cooling-off period',
        Colors.amberAccent,
        Icons.shield_outlined,
        5,
      );
    case JourneyStage.active:
      return const StageInfo(
        'Financing active',
        Colors.greenAccent,
        Icons.verified,
        6,
      );
    case JourneyStage.withdrawn:
      return const StageInfo(
        'Withdrawn from the agreement',
        Colors.white54,
        Icons.undo,
        5,
      );
  }
}

/// The screen that continues the journey, or null when the borrower has
/// nothing to do (request still pending or rejected).
Widget? journeyScreen(BorrowerRequestData request, BorrowerJourney journey) {
  switch (journey.stage) {
    case JourneyStage.requestPending:
    case JourneyStage.requestRejected:
      return null;

    case JourneyStage.applicationNeeded:
    case JourneyStage.applicationUnderReview:
    case JourneyStage.applicationNeedsInfo:
    case JourneyStage.applicationRejected:
      return LoanApplicationScreen(request: request);

    case JourneyStage.offerReady:
      return FinancingOfferScreen(request: request, offerId: journey.offer!.id);

    case JourneyStage.awaitingSignature:
    case JourneyStage.coolingOff:
      return SignAgreementScreen(
        request: request,
        agreementId: journey.agreement!.id,
      );

    case JourneyStage.waitingForOffer:
    case JourneyStage.offerDeclined:
    case JourneyStage.offerExpired:
    case JourneyStage.active:
    case JourneyStage.withdrawn:
      return FinancingStatusScreen(request: request);
  }
}

Future<void> openJourney(
  BuildContext context,
  BorrowerRequestData request,
  BorrowerJourney journey,
) async {
  final screen = journeyScreen(request, journey);

  if (screen == null) return;

  await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
}
