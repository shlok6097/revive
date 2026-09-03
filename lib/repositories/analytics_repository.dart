import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ai_decision.dart';
import '../models/analytics_summary.dart';
import '../models/failure_analytics.dart';
import '../models/recovery_analytics.dart';
import '../models/recovery_attempt.dart';
import '../models/recovery_session.dart';
import '../models/strategy_analytics.dart';
import '../models/transaction.dart';
import '../services/analytics_service.dart';

/// Repository providing merchant-isolated analytics from Cloud Firestore collections.
class AnalyticsRepository {
  AnalyticsRepository({
    FirebaseFirestore? firestore,
    AnalyticsService? analyticsService,
  })  : _firestore = firestore,
        _analyticsService = analyticsService ?? const AnalyticsService();

  final FirebaseFirestore? _firestore;
  final AnalyticsService _analyticsService;

  FirebaseFirestore get _db {
    try {
      return _firestore ?? FirebaseFirestore.instance;
    } catch (_) {
      return FirebaseFirestore.instance;
    }
  }

  /// Fetches all transactions for a specific merchant.
  Future<List<TransactionModel>> getMerchantTransactions(String merchantId) async {
    if (merchantId.isEmpty) return const [];

    try {
      final snapshot = await _db
          .collection('transactions')
          .where('merchantId', isEqualTo: merchantId)
          .get();

      return snapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Fetches all recovery attempts for a specific merchant.
  Future<List<RecoveryAttempt>> getMerchantRecoveryAttempts(String merchantId) async {
    if (merchantId.isEmpty) return const [];

    try {
      final snapshot = await _db
          .collection('recovery_attempts')
          .where('merchantId', isEqualTo: merchantId)
          .get();

      return snapshot.docs
          .map((doc) => RecoveryAttempt.fromFirestore(doc))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Fetches all recovery sessions for a specific merchant.
  Future<List<RecoverySession>> getMerchantRecoverySessions(String merchantId) async {
    if (merchantId.isEmpty) return const [];

    try {
      final snapshot = await _db
          .collection('recovery_sessions')
          .where('merchantId', isEqualTo: merchantId)
          .get();

      return snapshot.docs
          .map((doc) => RecoverySession.fromFirestore(doc))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Fetches all AI decisions for a specific merchant.
  Future<List<AIDecision>> getMerchantAIDecisions(String merchantId) async {
    if (merchantId.isEmpty) return const [];

    try {
      final snapshot = await _db
          .collection('ai_decisions')
          .where('merchantId', isEqualTo: merchantId)
          .get();

      return snapshot.docs
          .map((doc) => AIDecision.fromFirestore(doc))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Returns aggregated KPI summary for the merchant.
  Future<AnalyticsSummary> getSummary(String merchantId) async {
    final transactions = await getMerchantTransactions(merchantId);
    final attempts = await getMerchantRecoveryAttempts(merchantId);
    final sessions = await getMerchantRecoverySessions(merchantId);

    return _analyticsService.calculateSummary(
      transactions: transactions,
      attempts: attempts,
      sessions: sessions,
    );
  }

  /// Returns failure breakdown grouped by category for the merchant.
  Future<List<FailureCategoryAnalytics>> getFailureBreakdown(String merchantId) async {
    final transactions = await getMerchantTransactions(merchantId);
    return _analyticsService.calculateFailureBreakdown(transactions);
  }

  /// Returns bank failure intelligence breakdown for the merchant.
  Future<List<BankFailureAnalytics>> getBankFailureBreakdown(String merchantId) async {
    final transactions = await getMerchantTransactions(merchantId);
    return _analyticsService.calculateBankBreakdown(transactions);
  }

  /// Returns payment method distribution and failure share for the merchant.
  Future<List<PaymentMethodAnalytics>> getPaymentMethodBreakdown(String merchantId) async {
    final transactions = await getMerchantTransactions(merchantId);
    return _analyticsService.calculatePaymentMethodBreakdown(transactions);
  }

  /// Returns recovery strategy effectiveness and success rates for the merchant.
  Future<List<StrategyPerformanceAnalytics>> getStrategyPerformance(String merchantId) async {
    final attempts = await getMerchantRecoveryAttempts(merchantId);
    final transactions = await getMerchantTransactions(merchantId);
    return _analyticsService.calculateStrategyPerformance(attempts, transactions);
  }

  /// Returns 7-day daily recovery time series for the merchant.
  Future<List<DailyRecoveryTrend>> getRecoveryTrend(String merchantId, {int days = 7}) async {
    final transactions = await getMerchantTransactions(merchantId);
    return _analyticsService.calculateRecoveryTrend(transactions, days: days);
  }

  /// Returns recovery conversion funnel stages for the merchant.
  Future<RecoveryFunnelData> getRecoveryFunnel(String merchantId) async {
    final transactions = await getMerchantTransactions(merchantId);
    final decisions = await getMerchantAIDecisions(merchantId);
    final attempts = await getMerchantRecoveryAttempts(merchantId);

    return _analyticsService.calculateRecoveryFunnel(
      transactions: transactions,
      aiDecisions: decisions,
      attempts: attempts,
    );
  }
}
