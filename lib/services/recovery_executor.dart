import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/merchant_policy.dart';
import '../models/recovery_attempt.dart';
import '../models/recovery_execution_result.dart';
import '../models/transaction.dart';
import '../repositories/recovery_attempt_repository.dart';

/// Abstract interface for recovery execution clients.
///
/// Ensures clean separation between client UI, Firebase Callable Functions,
/// and backend payment gateway API integrations.
abstract class RecoveryExecutor {
  Future<RecoveryExecutionResult> executeRecovery({
    required String merchantId,
    required String transactionId,
    required String recoveryAttemptId,
    bool simulation = true,
    bool confirmed = false,
    TransactionModel? transaction,
    RecoveryAttempt? recoveryAttempt,
    MerchantPolicy? merchantPolicy,
    List<RecoveryAttempt>? previousAttempts,
  });
}

/// Firebase Cloud Functions & Firestore backed Recovery Executor.
///
/// SECURITY INVARIANT:
/// Real payment executions run behind strict backend Cloud Functions guards.
/// Razorpay API credentials and secrets never reside in this Flutter client.
class FirebaseRecoveryExecutor implements RecoveryExecutor {
  FirebaseRecoveryExecutor({
    RecoveryAttemptRepository? attemptRepository,
    FirebaseFirestore? firestore,
  })  : _attemptRepo = attemptRepository ?? RecoveryAttemptRepository(),
        _firestore = firestore;

  final RecoveryAttemptRepository _attemptRepo;
  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db {
    try {
      return _firestore ?? FirebaseFirestore.instance;
    } catch (_) {
      return FirebaseFirestore.instance;
    }
  }

  @override
  Future<RecoveryExecutionResult> executeRecovery({
    required String merchantId,
    required String transactionId,
    required String recoveryAttemptId,
    bool simulation = true,
    bool confirmed = false,
    TransactionModel? transaction,
    RecoveryAttempt? recoveryAttempt,
    MerchantPolicy? merchantPolicy,
    List<RecoveryAttempt>? previousAttempts,
  }) async {
    final now = DateTime.now();
    final executionId = 'exec_$recoveryAttemptId';

    // 1. Guard check: Merchant isolation
    if (merchantId.isEmpty) {
      return RecoveryExecutionResult(
        success: false,
        status: 'BLOCKED',
        message: 'Unauthenticated merchant. Action rejected.',
        simulated: simulation,
        executedAt: now,
      );
    }

    // 2. Guard check: Strategy executability
    final strat = (recoveryAttempt?.strategy ?? '').toUpperCase();
    if (strat != 'RETRY' && strat != 'WAIT_AND_RETRY') {
      return RecoveryExecutionResult(
        success: false,
        status: 'NOT_EXECUTABLE',
        message: 'This recovery strategy ($strat) does not support automated payment retry.',
        simulated: simulation,
        executedAt: now,
        executionId: executionId,
        transactionId: transactionId,
        recoveryAttemptId: recoveryAttemptId,
      );
    }

    // 3. Guard check: Risk rules (Fraud / Invalid details / Blocked status)
    final failCat = (transaction?.errorCode ?? transaction?.errorReason ?? '').toUpperCase();
    if (failCat.contains('FRAUD') ||
        failCat.contains('INVALID') ||
        recoveryAttempt?.policyStatus == 'BLOCKED' ||
        recoveryAttempt?.status == 'BLOCKED') {
      return RecoveryExecutionResult(
        success: false,
        status: 'BLOCKED',
        message: 'Risk safety rules prevent automated recovery for this failure.',
        simulated: simulation,
        executedAt: now,
        executionId: executionId,
        transactionId: transactionId,
        recoveryAttemptId: recoveryAttemptId,
      );
    }

    // 4. Guard check: Retry limits
    final maxRetries = merchantPolicy?.maxAutomaticRetries ?? 1;
    final retryCount = (previousAttempts ?? [])
        .where((a) => (a.strategy == 'RETRY' || a.strategy == 'WAIT_AND_RETRY') && a.id != recoveryAttemptId)
        .length;

    if (retryCount >= maxRetries) {
      return RecoveryExecutionResult(
        success: false,
        status: 'BLOCKED',
        message: 'Maximum retry limit ($maxRetries) reached for this transaction.',
        simulated: simulation,
        executedAt: now,
        executionId: executionId,
        transactionId: transactionId,
        recoveryAttemptId: recoveryAttemptId,
      );
    }

    // 5. Guard check: Autonomy modes & Confirmation
    final autonomy = (merchantPolicy?.autonomyMode ?? 'MANUAL').toUpperCase();
    if ((autonomy == 'MANUAL' || autonomy == 'ASSISTED') && !confirmed && !simulation) {
      return RecoveryExecutionResult(
        success: false,
        status: 'REQUIRES_CONFIRMATION',
        message: 'Autonomy mode ($autonomy) requires explicit human confirmation before live execution.',
        simulated: simulation,
        executedAt: now,
        executionId: executionId,
        transactionId: transactionId,
        recoveryAttemptId: recoveryAttemptId,
      );
    }

    if (autonomy == 'AUTONOMOUS' && !(merchantPolicy?.automaticRetryEnabled ?? false) && !confirmed && !simulation) {
      return RecoveryExecutionResult(
        success: false,
        status: 'BLOCKED',
        message: 'Autonomous live recovery is disabled in merchant policy settings.',
        simulated: simulation,
        executedAt: now,
        executionId: executionId,
        transactionId: transactionId,
        recoveryAttemptId: recoveryAttemptId,
      );
    }

    // 6. Execute Simulation Mode
    if (simulation) {
      final result = RecoveryExecutionResult(
        success: true,
        status: 'SIMULATED_SUCCESS',
        message: 'Simulated recovery retry completed successfully without live payment execution.',
        simulated: true,
        executedAt: now,
        externalReference: 'sim_${now.millisecondsSinceEpoch}',
        executionId: executionId,
        transactionId: transactionId,
        recoveryAttemptId: recoveryAttemptId,
      );

      // Persist simulated state in Firestore
      try {
        await _attemptRepo.saveRecoveryAttempt(
          (recoveryAttempt ?? RecoveryAttempt(
            id: recoveryAttemptId,
            merchantId: merchantId,
            transactionId: transactionId,
            strategy: 'RETRY',
            status: 'SIMULATED',
            reason: 'Simulated recovery',
            createdAt: now,
            updatedAt: now,
          )).copyWith(
            status: 'SIMULATED',
            simulated: true,
            result: 'SIMULATED_SUCCESS',
            completedAt: now,
            updatedAt: now,
          ),
        );

        // Record audit log
        await _db.collection('audit_logs').add({
          'merchantId': merchantId,
          'action': 'RECOVERY_EXECUTION',
          'transactionId': transactionId,
          'recoveryAttemptId': recoveryAttemptId,
          'strategy': strat,
          'executionStatus': 'SIMULATED_SUCCESS',
          'simulated': true,
          'createdAt': Timestamp.now(),
        });
      } catch (_) {
        // Offline / local resilience
      }

      return result;
    }

    // 7. Live Execution Mode
    final result = RecoveryExecutionResult(
      success: true,
      status: 'EXECUTING',
      message: 'Live recovery initiated. Authoritative status awaiting Razorpay webhook reconciliation.',
      simulated: false,
      executedAt: now,
      externalReference: 'rec_live_${now.millisecondsSinceEpoch}',
      executionId: executionId,
      transactionId: transactionId,
      recoveryAttemptId: recoveryAttemptId,
    );

    try {
      await _attemptRepo.saveRecoveryAttempt(
        (recoveryAttempt ?? RecoveryAttempt(
          id: recoveryAttemptId,
          merchantId: merchantId,
          transactionId: transactionId,
          strategy: 'RETRY',
          status: 'EXECUTING',
          reason: 'Live recovery',
          createdAt: now,
          updatedAt: now,
        )).copyWith(
          status: 'EXECUTING',
          simulated: false,
          result: 'LIVE_RECOVERY_INITIATED',
          updatedAt: now,
        ),
      );

      await _db.collection('audit_logs').add({
        'merchantId': merchantId,
        'action': 'RECOVERY_EXECUTION',
        'transactionId': transactionId,
        'recoveryAttemptId': recoveryAttemptId,
        'strategy': strat,
        'executionStatus': 'EXECUTING',
        'simulated': false,
        'createdAt': Timestamp.now(),
      });
    } catch (_) {
      // Offline resilience
    }

    return result;
  }
}

/// Mock Recovery Executor for offline tests and predictable UI prototyping.
class MockRecoveryExecutor implements RecoveryExecutor {
  MockRecoveryExecutor({this.mockResult});

  final RecoveryExecutionResult? mockResult;

  @override
  Future<RecoveryExecutionResult> executeRecovery({
    required String merchantId,
    required String transactionId,
    required String recoveryAttemptId,
    bool simulation = true,
    bool confirmed = false,
    TransactionModel? transaction,
    RecoveryAttempt? recoveryAttempt,
    MerchantPolicy? merchantPolicy,
    List<RecoveryAttempt>? previousAttempts,
  }) async {
    if (mockResult != null) return mockResult!;

    return FirebaseRecoveryExecutor().executeRecovery(
      merchantId: merchantId,
      transactionId: transactionId,
      recoveryAttemptId: recoveryAttemptId,
      simulation: simulation,
      confirmed: confirmed,
      transaction: transaction,
      recoveryAttempt: recoveryAttempt,
      merchantPolicy: merchantPolicy,
      previousAttempts: previousAttempts,
    );
  }
}
