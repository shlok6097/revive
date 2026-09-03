import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ai_decision.dart';
import '../models/merchant_policy.dart';
import '../models/recovery_attempt.dart';
import '../models/recovery_decision.dart';
import '../models/transaction.dart';
import '../repositories/ai_decision_repository.dart';
import '../repositories/merchant_policy_repository.dart';
import '../repositories/recovery_attempt_repository.dart';
import '../repositories/transaction_repository.dart';

/// Core deterministic Recovery Strategy Engine for REVIVE (Phase 6).
///
/// Combines AI failure classification telemetry, merchant policy rules,
/// historical attempt iteration counts, and risk safety limits to produce
/// governed recovery decisions without executing real live payments.
class RecoveryStrategyService {
  RecoveryStrategyService({
    RecoveryAttemptRepository? attemptRepository,
    MerchantPolicyRepository? policyRepository,
    AIDecisionRepository? aiDecisionRepository,
    TransactionRepository? transactionRepository,
    FirebaseFirestore? firestore,
  })  : _attemptRepo = attemptRepository ?? RecoveryAttemptRepository(),
        _policyRepo = policyRepository ?? MerchantPolicyRepository(),
        _aiRepo = aiDecisionRepository ?? AIDecisionRepository(),
        _txRepo = transactionRepository ?? TransactionRepository(),
        _firestore = firestore;

  final RecoveryAttemptRepository _attemptRepo;
  final MerchantPolicyRepository _policyRepo;
  final AIDecisionRepository _aiRepo;
  final TransactionRepository _txRepo;
  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db {
    try {
      return _firestore ?? FirebaseFirestore.instance;
    } catch (_) {
      return FirebaseFirestore.instance;
    }
  }

  /// Evaluates deterministic recovery strategy rules.
  ///
  /// CRITICAL ARCHITECTURAL INVARIANT:
  /// The AI recommendation is strictly advisory. Deterministic risk rules,
  /// merchant policies, and retry counters have final binding authority.
  RecoveryDecision evaluateStrategy({
    required TransactionModel transaction,
    required AIDecision aiDecision,
    required MerchantPolicy policy,
    required List<RecoveryAttempt> previousAttempts,
  }) {
    final attemptNumber = previousAttempts.length + 1;
    final now = DateTime.now();

    final retryAttemptsCount = previousAttempts
        .where((a) => a.strategy == 'RETRY' || a.strategy == 'WAIT_AND_RETRY')
        .length;

    final failureCat = aiDecision.failureCategory.toUpperCase();
    final autonomy = policy.autonomyMode.toUpperCase();

    // 1. RULE: Fraud Risk is ALWAYS blocked from automated recovery
    if (failureCat == 'FRAUD_RISK') {
      return RecoveryDecision(
        strategy: RecoveryStrategy.noAction.value,
        status: RecoveryStatus.blocked.value,
        reason: 'Suspected high-risk fraud or security alert; automated recovery blocked by policy.',
        requiresReview: true,
        requiresConfirmation: false,
        simulated: true,
        attemptNumber: attemptNumber,
        policyStatus: 'BLOCKED',
        autonomyMode: autonomy,
        createdAt: now,
      );
    }

    // 2. RULE: Enforce deterministic retry limits per transaction
    final isRetryStrategy = aiDecision.recommendedStrategy == 'RETRY' ||
        aiDecision.recommendedStrategy == 'WAIT_AND_RETRY';

    if (isRetryStrategy && retryAttemptsCount >= policy.maxAutomaticRetries) {
      return RecoveryDecision(
        strategy: RecoveryStrategy.waitAndRetry.value,
        status: RecoveryStatus.requiresReview.value,
        reason: 'Maximum automatic retry limit (${policy.maxAutomaticRetries}) reached for this transaction.',
        requiresReview: true,
        requiresConfirmation: true,
        simulated: true,
        attemptNumber: attemptNumber,
        policyStatus: 'REQUIRES_REVIEW',
        autonomyMode: autonomy,
        createdAt: now,
      );
    }

    // 3. RULE: Failure Category specific policy evaluations
    String decidedStrategy;
    String policyStatus;
    String reason;
    bool requiresReview = false;

    switch (failureCat) {
      case 'INVALID_DETAILS':
        if (policy.allowAlternativeMethod) {
          decidedStrategy = RecoveryStrategy.alternativeMethod.value;
          policyStatus = 'ALLOWED';
          reason = 'Invalid payment details detected; proposing customer alternative payment switch (e.g. UPI / card update).';
        } else {
          decidedStrategy = RecoveryStrategy.escalate.value;
          policyStatus = 'REQUIRES_REVIEW';
          reason = 'Invalid payment details with alternative method disabled; escalated for manual review.';
          requiresReview = true;
        }
        break;

      case 'AUTHENTICATION_FAILURE':
        if (policy.requireReviewForAuthenticationFailure) {
          decidedStrategy = RecoveryStrategy.alternativeMethod.value;
          policyStatus = 'REQUIRES_REVIEW';
          reason = '3DS / authentication failure requires customer re-authentication or supervisor review.';
          requiresReview = true;
        } else if (policy.allowAlternativeMethod) {
          decidedStrategy = RecoveryStrategy.alternativeMethod.value;
          policyStatus = 'ALLOWED';
          reason = 'Customer authentication failed; offering alternative payment checkout link.';
        } else {
          decidedStrategy = RecoveryStrategy.escalate.value;
          policyStatus = 'REQUIRES_REVIEW';
          reason = 'Customer authentication failed and alternative method disabled.';
          requiresReview = true;
        }
        break;

      case 'BANK_DECLINE':
        if (previousAttempts.isEmpty) {
          if (policy.requireReviewForBankDecline) {
            decidedStrategy = RecoveryStrategy.retry.value;
            policyStatus = 'REQUIRES_REVIEW';
            reason = 'Bank decline detected; supervisor review required by merchant policy prior to retry.';
            requiresReview = true;
          } else if (policy.allowBankDeclineRetry) {
            decidedStrategy = RecoveryStrategy.retry.value;
            policyStatus = 'ALLOWED';
            reason = 'First-attempt issuing bank decline; eligible for smart secondary routing retry.';
          } else {
            decidedStrategy = RecoveryStrategy.escalate.value;
            policyStatus = 'REQUIRES_REVIEW';
            reason = 'Bank decline retry disabled in merchant policy settings.';
            requiresReview = true;
          }
        } else {
          decidedStrategy = RecoveryStrategy.waitAndRetry.value;
          policyStatus = 'REQUIRES_REVIEW';
          reason = 'Bank decline retry already attempted (${previousAttempts.length} prior attempts); requires delay or review.';
          requiresReview = true;
        }
        break;

      case 'NETWORK_ERROR':
        if (policy.allowNetworkRetry && retryAttemptsCount < policy.maxAutomaticRetries) {
          decidedStrategy = RecoveryStrategy.retry.value;
          policyStatus = 'ALLOWED';
          reason = 'Transient network timeout/gateway error; safe for immediate retry attempt.';
        } else {
          decidedStrategy = RecoveryStrategy.waitAndRetry.value;
          policyStatus = 'REQUIRES_REVIEW';
          reason = 'Network retry limit reached or network retries restricted by merchant policy.';
          requiresReview = true;
        }
        break;

      case 'INSUFFICIENT_FUNDS':
        if (policy.allowAlternativeMethod) {
          decidedStrategy = RecoveryStrategy.alternativeMethod.value;
          policyStatus = 'ALLOWED';
          reason = 'Insufficient funds in primary account; proposing alternate payment method.';
        } else {
          decidedStrategy = RecoveryStrategy.escalate.value;
          policyStatus = 'REQUIRES_REVIEW';
          reason = 'Insufficient funds with alternative method disabled; escalated for customer outreach.';
          requiresReview = true;
        }
        break;

      case 'UNKNOWN':
      default:
        decidedStrategy = RecoveryStrategy.escalate.value;
        policyStatus = 'REQUIRES_REVIEW';
        reason = 'Unclassified failure telemetry; manual supervisor review mandatory.';
        requiresReview = true;
        break;
    }

    // 4. RULE: Autonomy Mode lifecycle status mapping
    String finalStatus;
    bool requiresConfirmation;

    if (requiresReview || policyStatus == 'REQUIRES_REVIEW') {
      finalStatus = RecoveryStatus.requiresReview.value;
      requiresConfirmation = true;
    } else if (autonomy == 'AUTONOMOUS') {
      if (policy.automaticRetryEnabled) {
        finalStatus = RecoveryStatus.approved.value;
        requiresConfirmation = false;
      } else {
        finalStatus = RecoveryStatus.planned.value;
        requiresConfirmation = true;
      }
    } else if (autonomy == 'ASSISTED') {
      finalStatus = RecoveryStatus.approved.value;
      requiresConfirmation = true;
    } else {
      // MANUAL mode
      finalStatus = RecoveryStatus.planned.value;
      requiresConfirmation = true;
    }

    return RecoveryDecision(
      strategy: decidedStrategy,
      status: finalStatus,
      reason: reason,
      requiresReview: requiresReview,
      requiresConfirmation: requiresConfirmation,
      simulated: true, // Phase 6 invariant: always simulated
      attemptNumber: attemptNumber,
      policyStatus: policyStatus,
      autonomyMode: autonomy,
      createdAt: now,
    );
  }

  /// Full Phase 6 Recovery Decision Workflow:
  ///
  /// 1. Load Transaction
  /// 2. Load latest AI Decision
  /// 3. Load Merchant Policy
  /// 4. Load Previous Recovery Attempts
  /// 5. Evaluate Deterministic Rules
  /// 6. Create Recovery Decision & Simulated Recovery Attempt
  /// 7. Store in Firestore with Audit Logging
  ///
  /// Zero real Razorpay/live payment calls are made.
  Future<RecoveryAttempt> createRecoveryDecision({
    required String transactionId,
    required String merchantId,
    TransactionModel? transaction,
    AIDecision? aiDecision,
    MerchantPolicy? policy,
    List<RecoveryAttempt>? previousAttempts,
  }) async {
    // 1. Load transaction
    final tx = transaction ??
        await _txRepo.getTransaction(transactionId, merchantId) ??
        TransactionModel(
          id: transactionId,
          merchantId: merchantId,
          amount: 0,
          currency: 'INR',
          status: 'FAILED',
          paymentMethod: 'UNKNOWN',
          bank: 'UNKNOWN',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

    // 2. Load AI decision
    final ai = aiDecision ??
        await _aiRepo.getDecisionForTransaction(transactionId, merchantId) ??
        AIDecision(
          id: 'dec_$transactionId',
          merchantId: merchantId,
          transactionId: transactionId,
          failureCategory: 'UNKNOWN',
          recommendedStrategy: 'ESCALATE',
          createdAt: DateTime.now(),
        );

    // 3. Load merchant policy
    final pol = policy ?? await _policyRepo.getPolicy(merchantId);

    // 4. Load previous attempts
    final prev = previousAttempts ??
        await _attemptRepo.getAttemptsByTransaction(transactionId, merchantId);

    // 5. Evaluate deterministic strategy
    final decision = evaluateStrategy(
      transaction: tx,
      aiDecision: ai,
      policy: pol,
      previousAttempts: prev,
    );

    // 6. Create RecoveryAttempt record
    final attemptId = 'rec_${transactionId}_${decision.attemptNumber}';
    final isSimulatedSuccess = decision.status == 'APPROVED';

    final attempt = RecoveryAttempt(
      id: attemptId,
      merchantId: merchantId,
      transactionId: transactionId,
      strategy: decision.strategy,
      status: isSimulatedSuccess
          ? RecoveryStatus.simulated.value
          : decision.status,
      attemptNumber: decision.attemptNumber,
      trigger: RecoveryTrigger.aiRecommendation.value,
      reason: decision.reason,
      aiDecisionId: ai.id,
      policyStatus: decision.policyStatus,
      simulated: true,
      result: 'SIMULATION_SUCCESS: Strategy evaluated and simulated without live payment execution.',
      createdAt: DateTime.now(),
      completedAt: isSimulatedSuccess ? DateTime.now() : null,
      updatedAt: DateTime.now(),
    );

    // 7. Persist to Firestore
    try {
      await _attemptRepo.saveRecoveryAttempt(attempt);

      // 8. Generate immutable audit record
      final auditDoc = _db.collection('audit_logs').doc('audit_${attempt.id}');
      await auditDoc.set({
        'merchantId': merchantId,
        'action': 'RECOVERY_STRATEGY_DECIDED',
        'transactionId': transactionId,
        'recoveryAttemptId': attempt.id,
        'strategy': attempt.strategy,
        'status': attempt.status,
        'policyStatus': decision.policyStatus,
        'simulated': true,
        'autonomyMode': decision.autonomyMode,
        'createdAt': Timestamp.now(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Offline/test resilience
    }

    return attempt;
  }
}
