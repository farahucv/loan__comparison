import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/financing.dart';
import 'borrower_ui.dart';
import 'journey_ui.dart';

/// Vertical timeline of one financing journey, built from financing_events.
/// Used by the borrower's progress screen and the lender's Financing card.
class FinancingTimeline extends StatelessWidget {
  final bool applicationApproved;
  final DateTime? approvedAt;
  final FinancingOffer? offer;
  final FinancingAgreement? agreement;
  final List<FinancingEvent> events;

  /// Note under "Offer issued" while there is no offer yet.
  final String waitingForOfferNote;

  /// The lender sees "Ready to release" where the borrower sees
  /// "Waiting for the bank".
  final bool forLender;

  const FinancingTimeline({
    super.key,
    required this.applicationApproved,
    required this.approvedAt,
    required this.offer,
    required this.agreement,
    required this.events,
    this.waitingForOfferNote = 'Waiting for the bank to send your final offer.',
    this.forLender = false,
  });

  DateTime? _eventAt(String type) {
    for (final e in events.reversed) {
      if (e.eventType == type) return e.createdAt;
    }

    return null;
  }

  List<_TimelineStep> _steps() {
    final o = offer;
    final a = agreement;

    final steps = <_TimelineStep>[
      _TimelineStep(
        'Application approved',
        at: applicationApproved ? approvedAt : null,
        done: applicationApproved,
      ),
    ];

    if (o == null) {
      steps.add(_TimelineStep('Offer issued', note: waitingForOfferNote));
    } else {
      steps.add(
        _TimelineStep(
          'Offer issued',
          at: _eventAt('offer_issued') ?? o.createdAt,
          note: o.version > 1 ? '${tr('Offer version')} ${o.version}' : null,
          done: true,
        ),
      );

      switch (o.effectiveStatus) {
        case 'offer_declined':
          final reason = _reason('offer_declined');
          steps.add(
            _TimelineStep(
              'Offer declined',
              at: _eventAt('offer_declined'),
              note: reason == null ? null : '${tr('Reason:')} $reason',
              failed: true,
              done: true,
            ),
          );
          return steps;
        case 'offer_expired':
          steps.add(
            _TimelineStep(
              'Offer expired',
              at: _eventAt('offer_expired') ?? o.validUntil,
              failed: true,
              done: true,
            ),
          );
          return steps;
      }
    }

    steps.add(
      _TimelineStep(
        'Accepted',
        at: _eventAt('offer_accepted') ?? a?.kfsAcceptedAt,
        note: a == null ? null : '${tr('Reference')} ${a.referenceNo}',
        done: a != null,
      ),
    );

    // Accepted, then cancelled by the borrower or lapsed before signing.
    if (a != null && a.cancelledBeforeSigning) {
      final lapsed = events.any((e) => e.eventType == 'agreement_lapsed');

      steps.add(
        _TimelineStep(
          lapsed ? 'Acceptance lapsed' : 'Acceptance cancelled',
          at: _eventAt(lapsed ? 'agreement_lapsed' : 'agreement_cancelled'),
          failed: true,
          done: true,
        ),
      );
      return steps;
    }

    steps.add(
      _TimelineStep(
        'Signed',
        at: _eventAt('contract_signed') ?? a?.signedAt,
        done: a?.signedAt != null,
      ),
    );

    steps.add(
      _TimelineStep(
        'Cooling-off',
        at: _eventAt('cooling_off_started') ?? a?.signedAt,
        note: a?.coolingOffEndsAt == null
            ? null
            : '${tr('Ends')} ${formatDateTime(a!.coolingOffEndsAt)}',
        done: a?.signedAt != null,
      ),
    );

    if (a?.status == 'withdrawn' || a?.status == 'cancelled') {
      steps.add(
        _TimelineStep(
          'Withdrawn from the agreement',
          at: _eventAt('withdrawn') ?? a?.withdrawnAt,
          failed: true,
          done: true,
        ),
      );
      return steps;
    }

    // Signed, cooling-off over, funds not released yet.
    final awaitingRelease = a?.status == 'cooling_off' && !a!.inCoolingOff;

    steps.add(
      _TimelineStep(
        'Disbursed',
        at: _eventAt('disbursed') ?? a?.disbursedAt,
        done: a?.disbursedAt != null,
        pending: awaitingRelease
            ? (forLender ? 'Ready to release' : 'Waiting for the bank')
            : null,
      ),
    );

    steps.add(
      _TimelineStep(
        'Active',
        at: _eventAt('activated') ?? a?.disbursedAt,
        done: a?.status == 'active',
        pending: 'Starts when the funds are released',
      ),
    );

    return steps;
  }

  String? _reason(String type) {
    for (final e in events.reversed) {
      if (e.eventType == type) {
        final r = e.details['reason']?.toString().trim() ?? '';
        return r.isEmpty ? null : r;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps();

    // The first step that is not done is the current one.
    final current = steps.indexWhere((s) => !s.done);

    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 30,
                  child: Column(
                    children: [
                      _dot(steps[i], isCurrent: i == current),
                      if (i < steps.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: steps[i].done && !steps[i].failed
                                ? Colors.greenAccent.withValues(alpha: .6)
                                : Colors.white24,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          steps[i].title,
                          style: white(
                            13,
                            w: FontWeight.bold,
                            c: steps[i].failed
                                ? Colors.redAccent
                                : steps[i].done || i == current
                                ? Colors.white
                                : Colors.white38,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          steps[i].done
                              ? formatDateTime(steps[i].at)
                              : steps[i].pending != null
                              ? tr(steps[i].pending!)
                              : i == current
                              ? tr('In progress')
                              : tr('Not started'),
                          style: white(11, c: Colors.white54),
                        ),
                        if (steps[i].note != null) ...[
                          const SizedBox(height: 2),
                          AppText(
                            steps[i].note!,
                            style: white(11, c: Colors.white54),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _dot(_TimelineStep step, {required bool isCurrent}) {
    final color = step.failed
        ? Colors.redAccent
        : step.done
        ? Colors.greenAccent
        : isCurrent
        ? kCyan
        : Colors.white24;

    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: step.done ? color : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: step.done
          ? Icon(
              step.failed ? Icons.close : Icons.check,
              size: 14,
              color: Colors.black,
            )
          : null,
    );
  }
}

class _TimelineStep {
  final String title;
  final DateTime? at;
  final String? note;
  final bool done;
  final bool failed;

  /// Shown instead of "In progress" / "Not started" while not done.
  final String? pending;

  const _TimelineStep(
    this.title, {
    this.at,
    this.note,
    this.done = false,
    this.failed = false,
    this.pending,
  });
}
