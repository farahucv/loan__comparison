// Models for the simulated financing journey
// (supabase/migrations/20261031120000_financing_journey.sql).

double _toDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}

DateTime? _toDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}

class FinancingOffer {
  final String id;
  final String applicationId;
  final String borrowerId;
  final String lenderId;

  final double principal;
  final double annualProfitRate;

  /// flat | reducing
  final String rateType;
  final int termMonths;
  final double adminFee;

  final double monthlyInstallment;
  final double totalProfit;
  final double totalRepayable;
  final double apr;
  final double salaryDbr;
  final double totalDbr;

  final DateTime validUntil;
  final int version;

  /// offer_issued | offer_accepted | offer_declined | offer_expired | cancelled
  final String status;
  final DateTime? createdAt;

  FinancingOffer({
    required this.id,
    required this.applicationId,
    required this.borrowerId,
    required this.lenderId,
    required this.principal,
    required this.annualProfitRate,
    required this.rateType,
    required this.termMonths,
    required this.adminFee,
    required this.monthlyInstallment,
    required this.totalProfit,
    required this.totalRepayable,
    required this.apr,
    required this.salaryDbr,
    required this.totalDbr,
    required this.validUntil,
    required this.version,
    required this.status,
    required this.createdAt,
  });

  factory FinancingOffer.fromMap(Map<String, dynamic> row) => FinancingOffer(
    id: row['id']?.toString() ?? '',
    applicationId: row['application_id']?.toString() ?? '',
    borrowerId: row['borrower_id']?.toString() ?? '',
    lenderId: row['lender_id']?.toString() ?? '',
    principal: _toDouble(row['principal']),
    annualProfitRate: _toDouble(row['annual_profit_rate']),
    rateType: row['rate_type']?.toString() ?? 'reducing',
    termMonths: _toInt(row['term_months']),
    adminFee: _toDouble(row['admin_fee']),
    monthlyInstallment: _toDouble(row['monthly_installment']),
    totalProfit: _toDouble(row['total_profit']),
    totalRepayable: _toDouble(row['total_repayable']),
    apr: _toDouble(row['apr']),
    salaryDbr: _toDouble(row['salary_dbr']),
    totalDbr: _toDouble(row['total_dbr']),
    validUntil: _toDate(row['valid_until']) ?? DateTime.now(),
    version: _toInt(row['version']),
    status: row['status']?.toString() ?? 'offer_issued',
    createdAt: _toDate(row['created_at']),
  );

  /// An issued offer past its valid-until date is expired even if the
  /// database has not marked it yet (the SQL marks it lazily).
  String get effectiveStatus {
    if (status == 'offer_issued' && DateTime.now().isAfter(validUntil)) {
      return 'offer_expired';
    }

    return status;
  }

  bool get isOpen => effectiveStatus == 'offer_issued';
}

class FinancingAgreement {
  final String id;
  final String offerId;
  final String borrowerId;
  final String lenderId;
  final String referenceNo;
  final DateTime? kfsAcceptedAt;
  final Map<String, dynamic> consents;
  final DateTime? signedAt;
  final String? signatureMethod;
  final DateTime? coolingOffEndsAt;
  final DateTime? withdrawnAt;
  final DateTime? disbursedAt;
  final String? disbursementIbanLast4;

  /// offer_accepted | contract_signed | cooling_off | disbursed | active |
  /// withdrawn | cancelled
  final String status;

  FinancingAgreement({
    required this.id,
    required this.offerId,
    required this.borrowerId,
    required this.lenderId,
    required this.referenceNo,
    required this.kfsAcceptedAt,
    required this.consents,
    required this.signedAt,
    required this.signatureMethod,
    required this.coolingOffEndsAt,
    required this.withdrawnAt,
    required this.disbursedAt,
    required this.disbursementIbanLast4,
    required this.status,
  });

  factory FinancingAgreement.fromMap(Map<String, dynamic> row) =>
      FinancingAgreement(
        id: row['id']?.toString() ?? '',
        offerId: row['offer_id']?.toString() ?? '',
        borrowerId: row['borrower_id']?.toString() ?? '',
        lenderId: row['lender_id']?.toString() ?? '',
        referenceNo: row['reference_no']?.toString() ?? '',
        kfsAcceptedAt: _toDate(row['kfs_accepted_at']),
        consents: row['consents'] is Map
            ? Map<String, dynamic>.from(row['consents'] as Map)
            : <String, dynamic>{},
        signedAt: _toDate(row['signed_at']),
        signatureMethod: row['signature_method']?.toString(),
        coolingOffEndsAt: _toDate(row['cooling_off_ends_at']),
        withdrawnAt: _toDate(row['withdrawn_at']),
        disbursedAt: _toDate(row['disbursed_at']),
        disbursementIbanLast4: row['disbursement_iban_last4']?.toString(),
        status: row['status']?.toString() ?? 'offer_accepted',
      );

  bool get earlyDisbursementWaiver =>
      consents['early_disbursement_waiver'] == true;

  bool get inCoolingOff =>
      status == 'cooling_off' &&
      coolingOffEndsAt != null &&
      DateTime.now().isBefore(coolingOffEndsAt!);
}

class RepaymentInstallment {
  final int installmentNo;
  final DateTime dueDate;
  final double principalPart;
  final double profitPart;
  final double installment;
  final double remainingBalance;

  RepaymentInstallment({
    required this.installmentNo,
    required this.dueDate,
    required this.principalPart,
    required this.profitPart,
    required this.installment,
    required this.remainingBalance,
  });

  factory RepaymentInstallment.fromMap(Map<String, dynamic> row) =>
      RepaymentInstallment(
        installmentNo: _toInt(row['installment_no']),
        dueDate:
            DateTime.tryParse(row['due_date']?.toString() ?? '') ??
            DateTime.now(),
        principalPart: _toDouble(row['principal_part']),
        profitPart: _toDouble(row['profit_part']),
        installment: _toDouble(row['installment']),
        remainingBalance: _toDouble(row['remaining_balance']),
      );
}

class FinancingEvent {
  final int id;
  final String offerId;
  final String? agreementId;
  final String actorRole;
  final String eventType;
  final Map<String, dynamic> details;
  final DateTime createdAt;

  FinancingEvent({
    required this.id,
    required this.offerId,
    required this.agreementId,
    required this.actorRole,
    required this.eventType,
    required this.details,
    required this.createdAt,
  });

  factory FinancingEvent.fromMap(Map<String, dynamic> row) => FinancingEvent(
    id: _toInt(row['id']),
    offerId: row['offer_id']?.toString() ?? '',
    agreementId: row['agreement_id']?.toString(),
    actorRole: row['actor_role']?.toString() ?? 'system',
    eventType: row['event_type']?.toString() ?? '',
    details: row['details'] is Map
        ? Map<String, dynamic>.from(row['details'] as Map)
        : <String, dynamic>{},
    createdAt: _toDate(row['created_at']) ?? DateTime.now(),
  );
}

/// Result of rushd_sign_agreement (a wrong code is not an error).
class SignResult {
  final bool ok;
  final String? error;
  final int? attemptsLeft;
  final String? referenceNo;
  final DateTime? coolingOffEndsAt;

  SignResult({
    required this.ok,
    this.error,
    this.attemptsLeft,
    this.referenceNo,
    this.coolingOffEndsAt,
  });

  factory SignResult.fromMap(Map<String, dynamic> row) => SignResult(
    ok: row['ok'] == true,
    error: row['error']?.toString(),
    attemptsLeft: row['attempts_left'] == null
        ? null
        : _toInt(row['attempts_left']),
    referenceNo: row['reference_no']?.toString(),
    coolingOffEndsAt: _toDate(row['cooling_off_ends_at']),
  );
}

/// The rows of rushd_settings the app shows to borrowers.
class FinancingSettings {
  final int coolingOffBusinessDays;
  final bool demoFastCoolingOff;
  final int demoFastCoolingOffMinutes;

  const FinancingSettings({
    this.coolingOffBusinessDays = 10,
    this.demoFastCoolingOff = false,
    this.demoFastCoolingOffMinutes = 2,
  });

  factory FinancingSettings.fromMap(Map<String, dynamic> row) =>
      FinancingSettings(
        coolingOffBusinessDays: _toInt(row['cooling_off_business_days']),
        demoFastCoolingOff: row['demo_fast_cooling_off'] == true,
        demoFastCoolingOffMinutes: _toInt(row['demo_fast_cooling_off_minutes']),
      );
}

/// Where a borrower's request is in the whole journey.
enum JourneyStage {
  requestPending,
  requestRejected,
  applicationNeeded,
  applicationUnderReview,
  applicationNeedsInfo,
  applicationRejected,
  waitingForOffer,
  offerReady,
  offerDeclined,
  offerExpired,
  awaitingSignature,
  coolingOff,
  active,
  withdrawn,
}

/// Everything about one loan request after it was submitted.
class BorrowerJourney {
  final String requestStatus;
  final String? applicationId;
  final String? applicationStatus;
  final FinancingOffer? offer;
  final FinancingAgreement? agreement;

  BorrowerJourney({
    required this.requestStatus,
    this.applicationId,
    this.applicationStatus,
    this.offer,
    this.agreement,
  });

  JourneyStage get stage {
    if (requestStatus == 'rejected') return JourneyStage.requestRejected;
    if (requestStatus != 'approved') return JourneyStage.requestPending;

    if (applicationStatus == null) return JourneyStage.applicationNeeded;
    if (applicationStatus == 'rejected') {
      return JourneyStage.applicationRejected;
    }

    if (applicationStatus == 'more_info_required') {
      return JourneyStage.applicationNeedsInfo;
    }

    if (applicationStatus != 'approved') {
      return JourneyStage.applicationUnderReview;
    }

    final a = agreement;

    if (a != null) {
      switch (a.status) {
        case 'offer_accepted':
          return JourneyStage.awaitingSignature;
        case 'contract_signed':
        case 'cooling_off':
          return JourneyStage.coolingOff;
        case 'disbursed':
        case 'active':
          return JourneyStage.active;
        case 'withdrawn':
        case 'cancelled':
          return JourneyStage.withdrawn;
      }
    }

    final o = offer;

    if (o == null) return JourneyStage.waitingForOffer;

    switch (o.effectiveStatus) {
      case 'offer_issued':
        return JourneyStage.offerReady;
      case 'offer_declined':
        return JourneyStage.offerDeclined;
      case 'offer_expired':
        return JourneyStage.offerExpired;
      case 'cancelled':
        return JourneyStage.withdrawn;
      default:
        return JourneyStage.waitingForOffer;
    }
  }
}
