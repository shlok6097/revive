import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revive/models/ai_decision.dart';
import 'package:revive/models/merchant_policy.dart';
import 'package:revive/models/recovery_attempt.dart';
import 'package:revive/models/transaction.dart';
import 'package:revive/services/recovery_strategy_service.dart';
import 'package:revive/widgets/recovery_strategy_card.dart';

void main() {
  group('Phase 6 — REVIVE Recovery Strategy Engine Tests', () {
    final strategyService = RecoveryStrategyService();

    final sampleTx = TransactionModel(
      id: 'tx_fail_9901',
      merchantId: 'merchant_alpha',
      amount: 2499.0,
      currency: 'INR',
      status: 'FAILED',
      paymentMethod: 'UPI',
      bank: 'HDFC',
      errorCode: 'BAD_REQUEST_ERROR',
      errorReason: 'Bank declined transaction',
      errorSource: 'bank',
      errorStep: 'payment_authorization',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final defaultPolicy = MerchantPolicy(
      id: 'pol_alpha',
      merchantId: 'merchant_alpha',
      autonomyMode: 'MANUAL',
      automaticRetryEnabled: false,
      maxAutomaticRetries: 1,
      allowNetworkRetry: true,
      allowBankDeclineRetry: true,
      allowAlternativeMethod: true,
      requireReviewForBankDecline: false,
      requireReviewForAuthenticationFailure: true,
      updatedAt: DateTime.now(),
    );

    test('Test 1 — Bank decline first attempt produces RETRY', () {
      const aiDecision = AIDecision(
        id: 'dec_01',
        merchantId: 'merchant_alpha',
        transactionId: 'tx_fail_9901',
        failureCategory: 'BANK_DECLINE',
        recommendedStrategy: 'RETRY',
      );

      final decision = strategyService.evaluateStrategy(
        transaction: sampleTx,
        aiDecision: aiDecision,
        policy: defaultPolicy,
        previousAttempts: [],
      );

      expect(decision.strategy, 'RETRY');
      expect(decision.policyStatus, 'ALLOWED');
      expect(decision.attemptNumber, 1);
      expect(decision.simulated, true);
    });

    test('Test 2 — Bank decline with prior attempt triggers WAIT_AND_RETRY or REQUIRES_REVIEW', () {
      const aiDecision = AIDecision(
        id: 'dec_02',
        merchantId: 'merchant_alpha',
        transactionId: 'tx_fail_9901',
        failureCategory: 'BANK_DECLINE',
        recommendedStrategy: 'RETRY',
      );

      final priorAttempt = RecoveryAttempt(
        id: 'rec_prior_1',
        merchantId: 'merchant_alpha',
        transactionId: 'tx_fail_9901',
        strategy: 'RETRY',
        status: 'SIMULATED',
        attemptNumber: 1,
        reason: 'First retry attempt failed',
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        updatedAt: DateTime.now(),
      );

      final decision = strategyService.evaluateStrategy(
        transaction: sampleTx,
        aiDecision: aiDecision,
        policy: defaultPolicy,
        previousAttempts: [priorAttempt],
      );

      expect(decision.strategy, 'WAIT_AND_RETRY');
      expect(decision.policyStatus, 'REQUIRES_REVIEW');
      expect(decision.requiresReview, true);
      expect(decision.attemptNumber, 2);
    });

    test('Test 3 — Network transient error produces RETRY', () {
      const aiDecision = AIDecision(
        id: 'dec_03',
        merchantId: 'merchant_alpha',
        transactionId: 'tx_fail_9901',
        failureCategory: 'NETWORK_ERROR',
        recommendedStrategy: 'RETRY',
      );

      final decision = strategyService.evaluateStrategy(
        transaction: sampleTx,
        aiDecision: aiDecision,
        policy: defaultPolicy,
        previousAttempts: [],
      );

      expect(decision.strategy, 'RETRY');
      expect(decision.policyStatus, 'ALLOWED');
      expect(decision.simulated, true);
    });

    test('Test 4 — Fraud risk is always BLOCKED with NO_ACTION', () {
      const aiDecision = AIDecision(
        id: 'dec_04',
        merchantId: 'merchant_alpha',
        transactionId: 'tx_fail_9901',
        failureCategory: 'FRAUD_RISK',
        recommendedStrategy: 'RETRY', // AI recommendation overruled!
      );

      final decision = strategyService.evaluateStrategy(
        transaction: sampleTx,
        aiDecision: aiDecision,
        policy: defaultPolicy,
        previousAttempts: [],
      );

      expect(decision.status, 'BLOCKED');
      expect(decision.strategy, 'NO_ACTION');
      expect(decision.policyStatus, 'BLOCKED');
      expect(decision.requiresReview, true);
    });

    test('Test 5 — Invalid details produces ALTERNATIVE_METHOD without blind retry', () {
      const aiDecision = AIDecision(
        id: 'dec_05',
        merchantId: 'merchant_alpha',
        transactionId: 'tx_fail_9901',
        failureCategory: 'INVALID_DETAILS',
        recommendedStrategy: 'ALTERNATIVE_METHOD',
      );

      final decision = strategyService.evaluateStrategy(
        transaction: sampleTx,
        aiDecision: aiDecision,
        policy: defaultPolicy,
        previousAttempts: [],
      );

      expect(decision.strategy, 'ALTERNATIVE_METHOD');
      expect(decision.policyStatus, 'ALLOWED');
      expect(decision.simulated, true);
    });

    test('Test 6 — Insufficient funds uses alternative payment method', () {
      const aiDecision = AIDecision(
        id: 'dec_06',
        merchantId: 'merchant_alpha',
        transactionId: 'tx_fail_9901',
        failureCategory: 'INSUFFICIENT_FUNDS',
        recommendedStrategy: 'WAIT_AND_RETRY',
      );

      final decision = strategyService.evaluateStrategy(
        transaction: sampleTx,
        aiDecision: aiDecision,
        policy: defaultPolicy,
        previousAttempts: [],
      );

      expect(decision.strategy, 'ALTERNATIVE_METHOD');
      expect(decision.policyStatus, 'ALLOWED');
    });

    test('Test 7 — Unknown failure telemetry routes to REQUIRES_REVIEW & ESCALATE', () {
      const aiDecision = AIDecision(
        id: 'dec_07',
        merchantId: 'merchant_alpha',
        transactionId: 'tx_fail_9901',
        failureCategory: 'UNKNOWN',
        recommendedStrategy: 'ESCALATE',
      );

      final decision = strategyService.evaluateStrategy(
        transaction: sampleTx,
        aiDecision: aiDecision,
        policy: defaultPolicy,
        previousAttempts: [],
      );

      expect(decision.strategy, 'ESCALATE');
      expect(decision.policyStatus, 'REQUIRES_REVIEW');
      expect(decision.requiresReview, true);
    });

    test('Test 8 — Retry limit enforcement stops automated retries', () {
      const aiDecision = AIDecision(
        id: 'dec_08',
        merchantId: 'merchant_alpha',
        transactionId: 'tx_fail_9901',
        failureCategory: 'NETWORK_ERROR',
        recommendedStrategy: 'RETRY',
      );

      final priorAttempt = RecoveryAttempt(
        id: 'rec_prior_1',
        merchantId: 'merchant_alpha',
        transactionId: 'tx_fail_9901',
        strategy: 'RETRY',
        status: 'SIMULATED',
        attemptNumber: 1,
        reason: 'First network retry',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final decision = strategyService.evaluateStrategy(
        transaction: sampleTx,
        aiDecision: aiDecision,
        policy: defaultPolicy.copyWith(maxAutomaticRetries: 1),
        previousAttempts: [priorAttempt],
      );

      expect(decision.strategy, 'WAIT_AND_RETRY');
      expect(decision.status, 'REQUIRES_REVIEW');
      expect(decision.requiresReview, true);
    });

    test('Test 9 — MANUAL autonomy mode requires human decision (PLANNED status)', () {
      const aiDecision = AIDecision(
        id: 'dec_09',
        merchantId: 'merchant_alpha',
        transactionId: 'tx_fail_9901',
        failureCategory: 'BANK_DECLINE',
        recommendedStrategy: 'RETRY',
      );

      final decision = strategyService.evaluateStrategy(
        transaction: sampleTx,
        aiDecision: aiDecision,
        policy: defaultPolicy.copyWith(autonomyMode: 'MANUAL'),
        previousAttempts: [],
      );

      expect(decision.status, 'PLANNED');
      expect(decision.requiresConfirmation, true);
    });

    test('Test 10 — ASSISTED mode approves strategy but requires operator confirmation', () {
      const aiDecision = AIDecision(
        id: 'dec_10',
        merchantId: 'merchant_alpha',
        transactionId: 'tx_fail_9901',
        failureCategory: 'BANK_DECLINE',
        recommendedStrategy: 'RETRY',
      );

      final decision = strategyService.evaluateStrategy(
        transaction: sampleTx,
        aiDecision: aiDecision,
        policy: defaultPolicy.copyWith(autonomyMode: 'ASSISTED'),
        previousAttempts: [],
      );

      expect(decision.status, 'APPROVED');
      expect(decision.requiresConfirmation, true);
      expect(decision.simulated, true);
    });

    test('Test 11 — AUTONOMOUS mode produces APPROVED in SIMULATION mode without live gateway execution', () {
      const aiDecision = AIDecision(
        id: 'dec_11',
        merchantId: 'merchant_alpha',
        transactionId: 'tx_fail_9901',
        failureCategory: 'BANK_DECLINE',
        recommendedStrategy: 'RETRY',
      );

      final decision = strategyService.evaluateStrategy(
        transaction: sampleTx,
        aiDecision: aiDecision,
        policy: defaultPolicy.copyWith(
          autonomyMode: 'AUTONOMOUS',
          automaticRetryEnabled: true,
        ),
        previousAttempts: [],
      );

      expect(decision.status, 'APPROVED');
      expect(decision.requiresConfirmation, false);
      expect(decision.simulated, true); // No live financial transaction!
    });

    test('Test 12 — RecoveryAttempt and MerchantPolicy Firestore serialization & merchant isolation', () {
      final now = DateTime.now();
      final attempt = RecoveryAttempt(
        id: 'rec_test_101',
        merchantId: 'merchant_alpha',
        transactionId: 'tx_fail_9901',
        strategy: 'RETRY',
        status: 'SIMULATED',
        attemptNumber: 1,
        trigger: 'AI_RECOMMENDATION',
        reason: 'Transient bank network retry',
        aiDecisionId: 'dec_01',
        policyStatus: 'ALLOWED',
        simulated: true,
        result: 'SIMULATION_SUCCESS',
        createdAt: now,
        completedAt: now,
        updatedAt: now,
      );

      final map = attempt.toFirestore();
      expect(map['merchantId'], 'merchant_alpha');
      expect(map['strategy'], 'RETRY');
      expect(map['status'], 'SIMULATED');
      expect(map['simulated'], true);

      final reconstructed = RecoveryAttempt.fromMap(map, 'rec_test_101');
      expect(reconstructed.id, 'rec_test_101');
      expect(reconstructed.merchantId, 'merchant_alpha');
      expect(reconstructed.simulated, true);
    });

    testWidgets('Test 13 — RecoveryStrategyCard renders policy metrics, timeline, and simulation button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecoveryStrategyCard(
              latestTransaction: sampleTx,
              aiDecision: const AIDecision(
                id: 'dec_widget_test',
                merchantId: 'merchant_alpha',
                transactionId: 'tx_fail_9901',
                failureCategory: 'BANK_DECLINE',
                recommendedStrategy: 'RETRY',
              ),
              merchantPolicy: defaultPolicy,
              previousAttempts: const [],
              merchantId: 'merchant_alpha',
            ),
          ),
        ),
      );

      expect(find.text('RECOVERY STRATEGY ENGINE'), findsOneWidget);
      expect(find.text('Governed Strategy & Simulation'), findsOneWidget);
      expect(find.text('Failure Category'), findsOneWidget);
      expect(find.text('AI Recommendation'), findsOneWidget);
      expect(find.text('Policy Decision'), findsOneWidget);
      expect(find.text('Retry Attempts'), findsOneWidget);
      expect(find.text('Simulate Strategy'), findsOneWidget);
      expect(find.text('RECOVERY LIFECYCLE PROGRESS'), findsOneWidget);
      expect(find.text('Payment Failed'), findsOneWidget);
      expect(find.text('AI Analysis'), findsOneWidget);
      expect(find.text('Policy Evaluation'), findsOneWidget);
      expect(find.text('Strategy Selected'), findsOneWidget);
      expect(find.text('Real Recovery (Phase 7)'), findsOneWidget);
    });
  });
}
