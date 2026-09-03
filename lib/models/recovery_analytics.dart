/// Daily snapshot of payment failures, recoveries, and recovery rate.
class DailyRecoveryTrend {
  const DailyRecoveryTrend({
    required this.date,
    required this.label,
    required this.failedCount,
    required this.recoveredCount,
    required this.recoveryRate,
    required this.recoveredAmount,
  });

  final DateTime date;
  final String label;
  final int failedCount;
  final int recoveredCount;
  final double recoveryRate;
  final double recoveredAmount;

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'label': label,
      'failedCount': failedCount,
      'recoveredCount': recoveredCount,
      'recoveryRate': recoveryRate,
      'recoveredAmount': recoveredAmount,
    };
  }
}

/// Structured 5-stage conversion funnel data for autonomous recovery.
class RecoveryFunnelData {
  const RecoveryFunnelData({
    required this.failedPayments,
    required this.aiClassified,
    required this.recoveryEligible,
    required this.recoveryAttempted,
    required this.recovered,
  });

  final int failedPayments;
  final int aiClassified;
  final int recoveryEligible;
  final int recoveryAttempted;
  final int recovered;

  double get classificationRate => failedPayments > 0 ? (aiClassified / failedPayments) * 100 : 0.0;
  double get eligibilityRate => aiClassified > 0 ? (recoveryEligible / aiClassified) * 100 : 0.0;
  double get attemptRate => recoveryEligible > 0 ? (recoveryAttempted / recoveryEligible) * 100 : 0.0;
  double get recoveryRate => recoveryAttempted > 0 ? (recovered / recoveryAttempted) * 100 : (failedPayments > 0 ? (recovered / failedPayments) * 100 : 0.0);

  Map<String, dynamic> toMap() {
    return {
      'failedPayments': failedPayments,
      'aiClassified': aiClassified,
      'recoveryEligible': recoveryEligible,
      'recoveryAttempted': recoveryAttempted,
      'recovered': recovered,
    };
  }
}
