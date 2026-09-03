import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revive/models/ai_decision.dart';
import 'package:revive/models/merchant_policy.dart';
import 'package:revive/models/recovery_attempt.dart';
import 'package:revive/models/recovery_execution_result.dart';
import 'package:revive/models/transaction.dart';
import 'package:revive/services/recovery_executor.dart';
import 'package:revive/widgets/recovery_strategy_card.dart';

void main() {
  group('Phase 7 — REVIVE Recovery Execution & Simulator Tests', () {
    final executor = FirebaseRecoveryExecutor();

    final testTx = TransactionModel(
      id: 'tx_exec_01',
      merchantId: 'merchant_bravo',
      amount: 4999.0,
      currency: 'INR',
      status: 'FAILED',
      paymentMethod: 'UPI',
      bank: 'HDFC',
      errorCode: 'GATEWAY_TIMEOUT',
      errorReason: 'Gateway timeout contacting issuing bank',
      errorSource: 'gateway',
      errorStep: 'payment_authorization',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final standardPolicy = MerchantPolicy(
      id: 'pol_bravo',
      merchantId: 'merchant_bravo',
      autonomyMode: 'MANUAL',
      automaticRetryEnabled: false,
      maxAutomaticRetries: 1,
      allowNetworkRetry: true,
      allowBankDeclineRetry: true,
      allowAlternativeMethod: true,
      updatedAt: DateTime.now(),
    );

    final standardAttempt = RecoveryAttempt(
      id: 'rec_exec_01_1',
      merchantId: 'merchant_bravo',
      transactionId: 'tx_exec_01',
      strategy: 'RETRY',
      status: 'APPROVED',
      attemptNumber: 1,
      reason: 'Transient gateway timeout eligible for retry',
      policyStatus: 'ALLOWED',
      simulated: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    test('Test 1 — Simulation Mode completes cleanly without live calls', () async {
      final result = await executor.executeRecovery(
        merchantId: 'merchant_bravo',
        transactionId: 'tx_exec_01',
        recoveryAttemptId: 'rec_exec_01_1',
        simulation: true,
        transaction: testTx,
        recoveryAttempt: standardAttempt,
        merchantPolicy: standardPolicy,
      );

      expect(result.success, true);
      expect(result.status, 'SIMULATED_SUCCESS');
      expect(result.simulated, true);
      expect(result.isSimulatedSuccess, true);
    });

    test('Test 2 — MANUAL autonomy mode requires confirmation for live execution', () async {
      final result = await executor.executeRecovery(
        merchantId: 'merchant_bravo',
        transactionId: 'tx_exec_01',
        recoveryAttemptId: 'rec_exec_01_1',
        simulation: false, // Live execution
        confirmed: false, // Unconfirmed
        transaction: testTx,
        recoveryAttempt: standardAttempt,
        merchantPolicy: standardPolicy.copyWith(autonomyMode: 'MANUAL'),
      );

      expect(result.success, false);
      expect(result.status, 'REQUIRES_CONFIRMATION');
      expect(result.requiresConfirmation, true);
    });

    test('Test 3 — ASSISTED autonomy mode requires confirmation before live execution', () async {
      final result = await executor.executeRecovery(
        merchantId: 'merchant_bravo',
        transactionId: 'tx_exec_01',
        recoveryAttemptId: 'rec_exec_01_1',
        simulation: false,
        confirmed: false,
        transaction: testTx,
        recoveryAttempt: standardAttempt,
        merchantPolicy: standardPolicy.copyWith(autonomyMode: 'ASSISTED'),
      );

      expect(result.success, false);
      expect(result.status, 'REQUIRES_CONFIRMATION');
    });

    test('Test 4 — AUTONOMOUS mode allows execution when policy enabled', () async {
      final result = await executor.executeRecovery(
        merchantId: 'merchant_bravo',
        transactionId: 'tx_exec_01',
        recoveryAttemptId: 'rec_exec_01_1',
        simulation: false,
        confirmed: false,
        transaction: testTx,
        recoveryAttempt: standardAttempt,
        merchantPolicy: standardPolicy.copyWith(
          autonomyMode: 'AUTONOMOUS',
          automaticRetryEnabled: true,
        ),
      );

      expect(result.success, true);
      expect(result.status, 'EXECUTING');
    });

    test('Test 5 — Fraud Risk prevents recovery execution', () async {
      final fraudTx = testTx.copyWith(errorCode: 'SUSPECTED_FRAUD');
      final fraudAttempt = standardAttempt.copyWith(policyStatus: 'BLOCKED');

      final result = await executor.executeRecovery(
        merchantId: 'merchant_bravo',
        transactionId: 'tx_exec_01',
        recoveryAttemptId: 'rec_exec_01_1',
        simulation: true,
        transaction: fraudTx,
        recoveryAttempt: fraudAttempt,
        merchantPolicy: standardPolicy,
      );

      expect(result.success, false);
      expect(result.status, 'BLOCKED');
      expect(result.isBlocked, true);
    });

    test('Test 6 — Retry limit enforcement blocks execution if retries exceeded', () async {
      final priorAttempt = standardAttempt.copyWith(id: 'rec_prior_1');

      final result = await executor.executeRecovery(
        merchantId: 'merchant_bravo',
        transactionId: 'tx_exec_01',
        recoveryAttemptId: 'rec_exec_01_2',
        simulation: true,
        transaction: testTx,
        recoveryAttempt: standardAttempt.copyWith(id: 'rec_exec_01_2', attemptNumber: 2),
        merchantPolicy: standardPolicy.copyWith(maxAutomaticRetries: 1),
        previousAttempts: [priorAttempt],
      );

      expect(result.success, false);
      expect(result.status, 'BLOCKED');
    });

    test('Test 7 — Non-executable strategies (ALTERNATIVE_METHOD / ESCALATE) are rejected', () async {
      final altAttempt = standardAttempt.copyWith(strategy: 'ALTERNATIVE_METHOD');

      final result = await executor.executeRecovery(
        merchantId: 'merchant_bravo',
        transactionId: 'tx_exec_01',
        recoveryAttemptId: 'rec_exec_01_1',
        simulation: true,
        transaction: testTx,
        recoveryAttempt: altAttempt,
        merchantPolicy: standardPolicy,
      );

      expect(result.success, false);
      expect(result.status, 'NOT_EXECUTABLE');
    });

    test('Test 8 — Merchant Isolation rejects unauthenticated execution', () async {
      final result = await executor.executeRecovery(
        merchantId: '', // Empty merchant ID
        transactionId: 'tx_exec_01',
        recoveryAttemptId: 'rec_exec_01_1',
        simulation: true,
      );

      expect(result.success, false);
      expect(result.status, 'BLOCKED');
    });

    test('Test 9 — RecoveryExecutionResult model serialization', () {
      final now = DateTime.now();
      final result = RecoveryExecutionResult(
        success: true,
        status: 'SIMULATED_SUCCESS',
        message: 'Simulated retry finished.',
        simulated: true,
        executedAt: now,
        externalReference: 'sim_123',
        executionId: 'exec_01',
        transactionId: 'tx_01',
        recoveryAttemptId: 'rec_01',
        isDuplicate: false,
      );

      final map = result.toMap();
      expect(map['success'], true);
      expect(map['status'], 'SIMULATED_SUCCESS');
      expect(map['simulated'], true);

      final reconstructed = RecoveryExecutionResult.fromMap(map);
      expect(reconstructed.success, true);
      expect(reconstructed.status, 'SIMULATED_SUCCESS');
      expect(reconstructed.externalReference, 'sim_123');
    });

    testWidgets('Test 10 — RecoveryStrategyCard opens Confirmation Dialog on execution request', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecoveryStrategyCard(
              latestTransaction: testTx,
              aiDecision: const AIDecision(
                id: 'dec_exec_test',
                merchantId: 'merchant_bravo',
                transactionId: 'tx_exec_01',
                failureCategory: 'NETWORK_ERROR',
                recommendedStrategy: 'RETRY',
              ),
              merchantPolicy: standardPolicy.copyWith(autonomyMode: 'ASSISTED'),
              previousAttempts: const [],
              merchantId: 'merchant_bravo',
            ),
          ),
        ),
      );

      expect(find.text('RECOVERY STRATEGY ENGINE'), findsOneWidget);
      expect(find.text('Simulate Recovery'), findsOneWidget);
      expect(find.text('Confirm Recovery'), findsOneWidget);

      // Tap Simulate Recovery -> confirmation dialog opens
      await tester.tap(find.text('Simulate Recovery'));
      await tester.pumpAndSettle();

      expect(find.text('Run Recovery Simulation'), findsOneWidget);
      expect(find.text('Execute Simulation'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Tap Cancel to dismiss
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Run Recovery Simulation'), findsNothing);
    });
  });
}
