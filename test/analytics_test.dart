import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revive/models/ai_decision.dart';
import 'package:revive/models/analytics_summary.dart';
import 'package:revive/models/failure_analytics.dart';
import 'package:revive/models/recovery_analytics.dart';
import 'package:revive/models/recovery_attempt.dart';
import 'package:revive/models/recovery_session.dart';
import 'package:revive/models/strategy_analytics.dart';
import 'package:revive/models/transaction.dart';
import 'package:revive/services/analytics_service.dart';
import 'package:revive/widgets/bank_failure_card.dart';
import 'package:revive/widgets/failure_analytics_card.dart';
import 'package:revive/widgets/payment_method_card.dart';
import 'package:revive/widgets/recovery_funnel_card.dart';
import 'package:revive/widgets/recovery_trend_card.dart';
import 'package:revive/widgets/strategy_performance_card.dart';
import 'package:revive/features/dashboard/dashboard_screen.dart';

void main() {
  group('AnalyticsService - Pure Deterministic Calculations', () {
    const service = AnalyticsService();
    final now = DateTime.now();

    final List<TransactionModel> testTransactions = [
      TransactionModel(
        id: 'tx_01',
        merchantId: 'm_01',
        amount: 1000.0,
        currency: 'INR',
        status: 'SUCCESS',
        paymentMethod: 'UPI',
        bank: 'HDFC',
        createdAt: now,
        updatedAt: now,
      ),
      TransactionModel(
        id: 'tx_02',
        merchantId: 'm_01',
        amount: 2000.0,
        currency: 'INR',
        status: 'FAILED',
        paymentMethod: 'UPI',
        bank: 'HDFC',
        errorCode: 'BAD_REQUEST_ERROR',
        errorReason: 'Payment declined by bank',
        createdAt: now,
        updatedAt: now,
      ),
      TransactionModel(
        id: 'tx_03',
        merchantId: 'm_01',
        amount: 1500.0,
        currency: 'INR',
        status: 'RECOVERED',
        paymentMethod: 'CARD',
        bank: 'ICICI',
        errorCode: 'GATEWAY_TIMEOUT',
        errorReason: 'Gateway timed out',
        recoveredAt: now,
        createdAt: now,
        updatedAt: now,
      ),
      TransactionModel(
        id: 'tx_04',
        merchantId: 'm_01',
        amount: 3000.0,
        currency: 'INR',
        status: 'FAILED',
        paymentMethod: 'NETBANKING',
        bank: 'SBI',
        errorCode: 'INSUFFICIENT_FUNDS',
        errorReason: 'Account balance insufficient',
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
    ];

    test('calculateSummary handles full dataset with correct arithmetic', () {
      final List<RecoveryAttempt> attempts = [
        RecoveryAttempt(
          id: 'att_01',
          transactionId: 'tx_02',
          merchantId: 'm_01',
          strategy: 'RETRY',
          status: 'PENDING',
          policyStatus: 'ALLOWED',
          reason: 'Network retry',
          attemptNumber: 1,
          createdAt: now,
          updatedAt: now,
        ),
        RecoveryAttempt(
          id: 'att_02',
          transactionId: 'tx_03',
          merchantId: 'm_01',
          strategy: 'RETRY',
          status: 'COMPLETED',
          policyStatus: 'ALLOWED',
          reason: 'Auto retry success',
          attemptNumber: 1,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final List<RecoverySession> sessions = [
        RecoverySession(
          id: 'ses_01',
          transactionId: 'tx_02',
          merchantId: 'm_01',
          tokenHash: 'hash_01',
          strategy: 'RETRY',
          status: 'ACTIVE',
          expiresAt: now.add(const Duration(minutes: 30)),
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final AnalyticsSummary summary = service.calculateSummary(
        transactions: testTransactions,
        attempts: attempts,
        sessions: sessions,
      );

      expect(summary.totalTransactions, 4);
      expect(summary.successfulTransactions, 1);
      expect(summary.failedTransactions, 2);
      expect(summary.recoveredTransactions, 1);
      expect(summary.recoveredAmount, 1500.0);
      expect(summary.totalFailedAmount, 6500.0);
      expect(summary.recoveryRate, 33.3);
      expect(summary.failureRate, 75.0);
      expect(summary.activeRecoverySessions, 1);
      expect(summary.recoveryAttempts, 2);
    });

    test('calculateSummary handles empty dataset safely with zero division protection', () {
      final AnalyticsSummary summary = service.calculateSummary(transactions: const []);
      expect(summary.totalTransactions, 0);
      expect(summary.successfulTransactions, 0);
      expect(summary.failedTransactions, 0);
      expect(summary.recoveredTransactions, 0);
      expect(summary.recoveryRate, 0.0);
      expect(summary.failureRate, 0.0);
      expect(summary.totalFailedAmount, 0.0);
      expect(summary.recoveredAmount, 0.0);
    });

    test('calculateFailureBreakdown groups categories correctly', () {
      final breakdown = service.calculateFailureBreakdown(testTransactions);
      expect(breakdown.isNotEmpty, isTrue);

      final categories = breakdown.map((b) => b.category).toList();
      expect(categories.contains('BANK_DECLINE'), isTrue);
      expect(categories.contains('NETWORK_ERROR'), isTrue);
      expect(categories.contains('INSUFFICIENT_FUNDS'), isTrue);

      final totalPercentage = breakdown.fold<double>(0.0, (sum, b) => sum + b.percentage);
      expect(totalPercentage, closeTo(100.0, 1.0));
    });

    test('calculateBankBreakdown aggregates by issuing bank', () {
      final bankBreakdown = service.calculateBankBreakdown(testTransactions);
      expect(bankBreakdown.isNotEmpty, isTrue);

      final banks = bankBreakdown.map((b) => b.bank).toList();
      expect(banks.contains('HDFC'), isTrue);
      expect(banks.contains('ICICI'), isTrue);
      expect(banks.contains('SBI'), isTrue);
    });

    test('calculatePaymentMethodBreakdown computes shares and amounts', () {
      final methodBreakdown = service.calculatePaymentMethodBreakdown(testTransactions);
      expect(methodBreakdown.length, 3);

      final upi = methodBreakdown.firstWhere((m) => m.paymentMethod == 'UPI');
      expect(upi.totalCount, 2);
      expect(upi.sharePercentage, 50.0);
    });

    test('calculateStrategyPerformance computes success and failure rates', () {
      final List<RecoveryAttempt> attempts = [
        RecoveryAttempt(
          id: 'att_01',
          transactionId: 'tx_03',
          merchantId: 'm_01',
          strategy: 'RETRY',
          status: 'COMPLETED',
          policyStatus: 'ALLOWED',
          reason: 'Retry succeeded',
          attemptNumber: 1,
          createdAt: now,
          updatedAt: now,
        ),
        RecoveryAttempt(
          id: 'att_02',
          transactionId: 'tx_02',
          merchantId: 'm_01',
          strategy: 'RETRY',
          status: 'FAILED',
          policyStatus: 'ALLOWED',
          reason: 'Retry failed',
          attemptNumber: 1,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final performance = service.calculateStrategyPerformance(attempts, testTransactions);
      final retry = performance.firstWhere((p) => p.strategy == 'RETRY');

      expect(retry.attempts, 2);
      expect(retry.successful, 1);
      expect(retry.failed, 1);
      expect(retry.successRate, 50.0);
      expect(retry.recoveredAmount, 1500.0);
    });

    test('calculateRecoveryTrend creates 7-day time series', () {
      final trends = service.calculateRecoveryTrend(testTransactions, days: 7);
      expect(trends.length, 7);
      expect(trends.last.label.isNotEmpty, isTrue);
    });

    test('calculateRecoveryFunnel calculates stages accurately', () {
      final List<AIDecision> decisions = [
        AIDecision(
          id: 'dec_01',
          transactionId: 'tx_02',
          merchantId: 'm_01',
          failureCategory: 'BANK_DECLINE',
          confidence: 0.95,
          recommendedStrategy: 'RETRY',
          reasoning: 'Transient decline',
          modelVersion: 'Phi-3 Mini',
          createdAt: now,
        ),
      ];

      final funnel = service.calculateRecoveryFunnel(
        transactions: testTransactions,
        aiDecisions: decisions,
      );

      expect(funnel.failedPayments, 3);
      expect(funnel.recovered, 1);
      expect(funnel.recoveryRate, greaterThan(0));
    });

    test('Simulator-generated transaction updates analytics', () {
      final simTx = TransactionModel(
        id: 'sim_tx_99',
        merchantId: 'm_01',
        amount: 5000.0,
        currency: 'INR',
        status: 'RECOVERED',
        paymentMethod: 'UPI',
        bank: 'HDFC',
        simulated: true,
        recoveredAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final List<TransactionModel> combined = [...testTransactions, simTx];
      final summary = service.calculateSummary(transactions: combined);

      expect(summary.totalTransactions, 5);
      expect(summary.recoveredTransactions, 2);
      expect(summary.recoveredAmount, 6500.0);
    });
  });

  group('Analytics Widgets Rendering', () {
    testWidgets('FailureAnalyticsCard renders breakdown bars', (tester) async {
      final breakdown = [
        const FailureCategoryAnalytics(category: 'BANK_DECLINE', count: 12, percentage: 60.0, amount: 15000),
        const FailureCategoryAnalytics(category: 'NETWORK_ERROR', count: 8, percentage: 40.0, amount: 10000),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FailureAnalyticsCard(breakdown: breakdown, totalFailures: 20),
          ),
        ),
      );

      expect(find.text('Failure Breakdown'), findsOneWidget);
      expect(find.text('20 Failures'), findsOneWidget);
      expect(find.text('BANK DECLINE'), findsOneWidget);
      expect(find.text('NETWORK ERROR'), findsOneWidget);
    });

    testWidgets('RecoveryTrendCard renders 7-day chart', (tester) async {
      final trends = [
        DailyRecoveryTrend(
          date: DateTime.now(),
          label: '04 Sep',
          failedCount: 5,
          recoveredCount: 3,
          recoveryRate: 37.5,
          recoveredAmount: 4500,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecoveryTrendCard(trends: trends),
          ),
        ),
      );

      expect(find.text('7-Day Recovery Trend'), findsOneWidget);
      expect(find.text('04 Sep'), findsOneWidget);
      expect(find.text('Failed'), findsOneWidget);
      expect(find.text('Recovered'), findsOneWidget);
    });

    testWidgets('BankFailureCard renders issuing banks', (tester) async {
      final banks = [
        const BankFailureAnalytics(
          bank: 'HDFC',
          failureCount: 10,
          recoveredCount: 6,
          failurePercentage: 62.5,
          amount: 25000,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BankFailureCard(bankAnalytics: banks),
          ),
        ),
      );

      expect(find.text('Bank Failures'), findsOneWidget);
      expect(find.text('HDFC'), findsOneWidget);
      expect(find.text('62.5%'), findsOneWidget);
    });

    testWidgets('PaymentMethodCard renders instruments and shares', (tester) async {
      final methods = [
        const PaymentMethodAnalytics(
          paymentMethod: 'UPI',
          totalCount: 30,
          failedCount: 8,
          recoveredCount: 5,
          sharePercentage: 75.0,
          amount: 45000,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaymentMethodCard(methodAnalytics: methods),
          ),
        ),
      );

      expect(find.text('Payment Methods'), findsOneWidget);
      expect(find.text('UPI'), findsOneWidget);
      expect(find.text('75.0% Share'), findsOneWidget);
    });

    testWidgets('StrategyPerformanceCard renders governance flow and win rates', (tester) async {
      final strategies = [
        const StrategyPerformanceAnalytics(
          strategy: 'RETRY',
          attempts: 10,
          successful: 7,
          failed: 3,
          successRate: 70.0,
          recoveredAmount: 14000,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StrategyPerformanceCard(strategyAnalytics: strategies),
          ),
        ),
      );

      expect(find.text('Strategy Win Rates'), findsOneWidget);
      expect(find.textContaining('AI Recommendation (Advisory) ➔ Policy Engine (Enforced)'), findsOneWidget);
      expect(find.text('70.0% Win Rate'), findsOneWidget);
    });

    testWidgets('RecoveryFunnelCard renders 5 conversion stages', (tester) async {
      const funnel = RecoveryFunnelData(
        failedPayments: 100,
        aiClassified: 98,
        recoveryEligible: 85,
        recoveryAttempted: 75,
        recovered: 55,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecoveryFunnelCard(funnelData: funnel),
          ),
        ),
      );

      expect(find.text('Recovery Funnel'), findsOneWidget);
      expect(find.text('Failed Payments'), findsOneWidget);
      expect(find.text('AI Classified'), findsOneWidget);
      expect(find.text('Recovery Eligible'), findsOneWidget);
      expect(find.text('Recovery Attempted'), findsOneWidget);
      expect(find.text('Recovered & Reconciled'), findsOneWidget);
    });

    testWidgets('DashboardScreen renders refreshed analytics and DEMO pill', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('DEMO ENVIRONMENT'), findsOneWidget);
      expect(find.text('Refresh'), findsOneWidget);
      expect(find.text('REVIVE ENGINE: ACTIVE'), findsOneWidget);
      expect(find.text('Failure Breakdown'), findsOneWidget);
      expect(find.text('7-Day Recovery Trend'), findsOneWidget);
    });
  });
}
