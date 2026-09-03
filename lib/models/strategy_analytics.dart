/// Metric breakdown of recovery strategy performance and effectiveness.
class StrategyPerformanceAnalytics {
  const StrategyPerformanceAnalytics({
    required this.strategy,
    required this.attempts,
    required this.successful,
    required this.failed,
    required this.successRate,
    required this.recoveredAmount,
    this.primaryReason,
  });

  final String strategy;
  final int attempts;
  final int successful;
  final int failed;
  final double successRate;
  final double recoveredAmount;
  final String? primaryReason;

  Map<String, dynamic> toMap() {
    return {
      'strategy': strategy,
      'attempts': attempts,
      'successful': successful,
      'failed': failed,
      'successRate': successRate,
      'recoveredAmount': recoveredAmount,
      'primaryReason': primaryReason,
    };
  }
}
