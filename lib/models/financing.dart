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

  /// Accepted, not signed, and cancelled (by the borrower or lapsed).
  bool get cancelledBeforeSigning => status == 'cancelled' && signedAt == null;

  /// When an unsigned acceptance lapses.
  DateTime? signDeadline(int lapseDays) =>
      kfsAcceptedAt?.add(Duration(days: lapseDays));

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

/// The next installment to pay: the lowest-numbered installment whose due
/// date is today or later. Null when every installment is in the past.
/// Does not rely on the order of [schedule].
RepaymentInstallment? nextInstallment(
  List<RepaymentInstallment> schedule,
  DateTime today,
) {
  final startOfToday = DateTime(today.year, today.month, today.day);

  final sorted = [...schedule]
    ..sort((a, b) => a.installmentNo.compareTo(b.installmentNo));

  for (final row in sorted) {
    final due = DateTime(row.dueDate.year, row.dueDate.month, row.dueDate.day);

    if (!due.isBefore(startOfToday)) return row;
  }

  return null;
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

  /// The acceptance was not signed in time and is now cancelled.
  final bool lapsed;

  SignResult({
    required this.ok,
    this.error,
    this.attemptsLeft,
    this.referenceNo,
    this.coolingOffEndsAt,
    this.lapsed = false,
  });

  factory SignResult.fromMap(Map<String, dynamic> row) => SignResult(
    ok: row['ok'] == true,
    lapsed: row['lapsed'] == true,
    error: row['error']?.toString(),
    attemptsLeft: row['attempts_left'] == null
        ? null
        : _toInt(row['attempts_left']),
    referenceNo: row['reference_no']?.toString(),
    coolingOffEndsAt: _toDate(row['cooling_off_ends_at']),
  );
}

/// The rows of rushd_settings the app shows (never the demo signing code).
/// Defaults match the migration, for when the settings cannot be read.
class FinancingSettings {
  final int coolingOffBusinessDays;
  final bool demoFastCoolingOff;
  final int demoFastCoolingOffMinutes;

  final int minTermMonths;
  final int maxTermMonths;
  final int maxOfferValidDays;

  final double adminFeePct;
  final double adminFeeMaxSar;

  final double dbrSalaryDeductionCapPct;
  final double dbrTotalCapPct;
  final double dbrIncomeLimitSar;
  final double dbrTotalCapAboveLimitPct;

  /// An accepted offer not signed within this many days lapses.
  final int unsignedLapseDays;

  const FinancingSettings({
    this.coolingOffBusinessDays = 10,
    this.demoFastCoolingOff = false,
    this.demoFastCoolingOffMinutes = 2,
    this.minTermMonths = 6,
    this.maxTermMonths = 60,
    this.maxOfferValidDays = 30,
    this.adminFeePct = 1,
    this.adminFeeMaxSar = 5000,
    this.dbrSalaryDeductionCapPct = 33.33,
    this.dbrTotalCapPct = 45,
    this.dbrIncomeLimitSar = 25000,
    this.dbrTotalCapAboveLimitPct = 45,
    this.unsignedLapseDays = 3,
  });

  /// Columns to select from rushd_settings.
  static const String columns = '$columnsWithoutLapse, unsigned_lapse_days';

  /// Before 20261031170000_cancel_unsigned.sql there is no
  /// unsigned_lapse_days column.
  static const String columnsWithoutLapse =
      'cooling_off_business_days, demo_fast_cooling_off, demo_fast_cooling_off_minutes, '
      'min_term_months, max_term_months, max_offer_valid_days, '
      'admin_fee_pct, admin_fee_max_sar, '
      'dbr_salary_deduction_cap_pct, dbr_total_cap_pct, dbr_income_limit_sar, dbr_total_cap_above_limit_pct';

  factory FinancingSettings.fromMap(Map<String, dynamic> row) {
    const d = FinancingSettings();

    int i(String k, int fallback) => row[k] == null ? fallback : _toInt(row[k]);
    double n(String k, double fallback) =>
        row[k] == null ? fallback : _toDouble(row[k]);

    return FinancingSettings(
      coolingOffBusinessDays: i(
        'cooling_off_business_days',
        d.coolingOffBusinessDays,
      ),
      demoFastCoolingOff: row['demo_fast_cooling_off'] == true,
      demoFastCoolingOffMinutes: i(
        'demo_fast_cooling_off_minutes',
        d.demoFastCoolingOffMinutes,
      ),
      minTermMonths: i('min_term_months', d.minTermMonths),
      maxTermMonths: i('max_term_months', d.maxTermMonths),
      maxOfferValidDays: i('max_offer_valid_days', d.maxOfferValidDays),
      adminFeePct: n('admin_fee_pct', d.adminFeePct),
      adminFeeMaxSar: n('admin_fee_max_sar', d.adminFeeMaxSar),
      dbrSalaryDeductionCapPct: n(
        'dbr_salary_deduction_cap_pct',
        d.dbrSalaryDeductionCapPct,
      ),
      dbrTotalCapPct: n('dbr_total_cap_pct', d.dbrTotalCapPct),
      dbrIncomeLimitSar: n('dbr_income_limit_sar', d.dbrIncomeLimitSar),
      dbrTotalCapAboveLimitPct: n(
        'dbr_total_cap_above_limit_pct',
        d.dbrTotalCapAboveLimitPct,
      ),
      unsignedLapseDays: i('unsigned_lapse_days', d.unsignedLapseDays),
    );
  }

  /// Total-obligations cap for a borrower with this monthly income.
  double totalDbrCapFor(double income) =>
      income <= dbrIncomeLimitSar ? dbrTotalCapPct : dbrTotalCapAboveLimitPct;
}

/// A borrower's monthly obligations as the simulated credit bureau sees
/// them (rushd_borrower_obligations): declared debts plus the installments
/// of their accepted / cooling-off / active Rushd financings.
class BorrowerObligations {
  final double declaredDebts;
  final double rushdInstallments;
  final int rushdCount;
  final double totalObligations;

  const BorrowerObligations({
    required this.declaredDebts,
    required this.rushdInstallments,
    required this.rushdCount,
    required this.totalObligations,
  });

  /// Used when the database function is not reachable: declared debts only.
  factory BorrowerObligations.declaredOnly(double declaredDebts) =>
      BorrowerObligations(
        declaredDebts: declaredDebts,
        rushdInstallments: 0,
        rushdCount: 0,
        totalObligations: declaredDebts,
      );

  factory BorrowerObligations.fromMap(Map<String, dynamic> row) {
    final declared = _toDouble(row['declared_debts']);
    final rushd = _toDouble(row['rushd_installments']);

    return BorrowerObligations(
      declaredDebts: declared,
      rushdInstallments: rushd,
      rushdCount: _toInt(row['rushd_count']),
      totalObligations: row['total_obligations'] == null
          ? declared + rushd
          : _toDouble(row['total_obligations']),
    );
  }
}

/// The loan offer a request was made on (defaults for a new financing offer).
class LoanOfferTerms {
  final double interestRate;
  final int maxTermMonths;
  final double maxAmount;

  const LoanOfferTerms({
    required this.interestRate,
    required this.maxTermMonths,
    required this.maxAmount,
  });
}

/// Lender pipeline stages for approved applications.
enum LenderStage {
  awaitingOffer,
  offerIssued,
  awaitingSignature,
  coolingOff,
  readyToRelease,
  active,
}

LenderStage lenderStageFor(FinancingOffer? offer, FinancingAgreement? a) {
  if (a != null) {
    switch (a.status) {
      case 'offer_accepted':
        return LenderStage.awaitingSignature;
      case 'contract_signed':
      case 'cooling_off':
        final ended =
            a.coolingOffEndsAt != null &&
            !DateTime.now().isBefore(a.coolingOffEndsAt!);
        return ended || a.earlyDisbursementWaiver
            ? LenderStage.readyToRelease
            : LenderStage.coolingOff;
      case 'disbursed':
      case 'active':
        return LenderStage.active;
    }

    // withdrawn / cancelled: the lender may issue a new offer.
    return LenderStage.awaitingOffer;
  }

  if (offer != null && offer.effectiveStatus == 'offer_issued') {
    return LenderStage.offerIssued;
  }

  return LenderStage.awaitingOffer;
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

  /// Cooling-off has ended; the bank has not released the funds yet.
  awaitingRelease,
  active,
  withdrawn,

  /// Accepted but cancelled before signing (by the borrower, or lapsed).
  acceptanceCancelled,
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
          return a.inCoolingOff
              ? JourneyStage.coolingOff
              : JourneyStage.awaitingRelease;
        case 'disbursed':
        case 'active':
          return JourneyStage.active;
        case 'withdrawn':
          return JourneyStage.withdrawn;
        case 'cancelled':
          return a.cancelledBeforeSigning
              ? JourneyStage.acceptanceCancelled
              : JourneyStage.withdrawn;
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
