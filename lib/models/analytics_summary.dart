/// Aggregated top-level KPI metrics for the REVIVE merchant analytics dashboard.
class AnalyticsSummary {
  const AnalyticsSummary({
    this.totalTransactions = 0,
    this.successfulTransactions = 0,
    this.failedTransactions = 0,
    this.recoveredTransactions = 0,
    this.totalFailedAmount = 0.0,
    this.recoveredAmount = 0.0,
    this.recoveryRate = 0.0,
    this.failureRate = 0.0,
    this.activeRecoverySessions = 0,
    this.recoveryAttempts = 0,
  });

  final int totalTransactions;
  final int successfulTransactions;
  final int failedTransactions;
  final int recoveredTransactions;
  final double totalFailedAmount;
  final double recoveredAmount;
  final double recoveryRate;
  final double failureRate;
  final int activeRecoverySessions;
  final int recoveryAttempts;

  /// Returns an empty summary instance for new merchants or zero transactions.
  static const empty = AnalyticsSummary();

  Map<String, dynamic> toMap() {
    return {
      'totalTransactions': totalTransactions,
      'successfulTransactions': successfulTransactions,
      'failedTransactions': failedTransactions,
      'recoveredTransactions': recoveredTransactions,
      'totalFailedAmount': totalFailedAmount,
      'recoveredAmount': recoveredAmount,
      'recoveryRate': recoveryRate,
      'failureRate': failureRate,
      'activeRecoverySessions': activeRecoverySessions,
      'recoveryAttempts': recoveryAttempts,
    };
  }

  factory AnalyticsSummary.fromMap(Map<String, dynamic> map) {
    return AnalyticsSummary(
      totalTransactions: map['totalTransactions'] as int? ?? 0,
      successfulTransactions: map['successfulTransactions'] as int? ?? 0,
      failedTransactions: map['failedTransactions'] as int? ?? 0,
      recoveredTransactions: map['recoveredTransactions'] as int? ?? 0,
      totalFailedAmount: (map['totalFailedAmount'] as num?)?.toDouble() ?? 0.0,
      recoveredAmount: (map['recoveredAmount'] as num?)?.toDouble() ?? 0.0,
      recoveryRate: (map['recoveryRate'] as num?)?.toDouble() ?? 0.0,
      failureRate: (map['failureRate'] as num?)?.toDouble() ?? 0.0,
      activeRecoverySessions: map['activeRecoverySessions'] as int? ?? 0,
      recoveryAttempts: map['recoveryAttempts'] as int? ?? 0,
    );
  }
}
