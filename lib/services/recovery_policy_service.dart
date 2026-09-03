import '../models/ai_decision.dart';
import '../models/transaction.dart';

/// Result of deterministic policy evaluation over an AI recommendation.
class PolicyEvaluation {
  const PolicyEvaluation({
    required this.policyStatus,
    required this.policyReason,
    this.canAutoExecute = false,
  });

  /// Deterministic status: 'ALLOWED', 'BLOCKED', or 'REQUIRES_REVIEW'.
  final String policyStatus;

  /// Audit trail explanation of the policy decision.
  final String policyReason;

  /// Whether autonomous execution is permitted (always false in Phase 5).
  final bool canAutoExecute;

  bool get isAllowed => policyStatus == 'ALLOWED';
  bool get isBlocked => policyStatus == 'BLOCKED';
  bool get requiresReview => policyStatus == 'REQUIRES_REVIEW';
}

/// Service implementing deterministic guardrails for AI payment recovery recommendations.
///
/// SAFETY INVARIANT:
/// AI models only propose classifications and strategies; this deterministic engine validates
/// guardrails before any action can ever be considered. It never executes payments.
class RecoveryPolicyService {
  const RecoveryPolicyService();

  /// Evaluates an AI decision against deterministic business and risk guardrails.
  PolicyEvaluation evaluate({
    required String failureCategory,
    required String recommendedStrategy,
    TransactionModel? transaction,
  }) {
    final category = FailureCategory.fromString(failureCategory);
    final strategy = RecommendedStrategy.fromString(recommendedStrategy);

    // Rule 1: Fraud risk recommendations must always be blocked
    if (category == FailureCategory.fraudRisk) {
      return const PolicyEvaluation(
        policyStatus: 'BLOCKED',
        policyReason: 'Transaction flagged for fraud risk; automated recovery blocked.',
        canAutoExecute: false,
      );
    }

    // Rule 2: Invalid payment details cannot be blindly retried
    if (category == FailureCategory.invalidDetails) {
      if (strategy == RecommendedStrategy.retry) {
        return const PolicyEvaluation(
          policyStatus: 'BLOCKED',
          policyReason: 'Retrying invalid payment credentials will fail deterministically. Alternative method required.',
          canAutoExecute: false,
        );
      }
      return const PolicyEvaluation(
        policyStatus: 'REQUIRES_REVIEW',
        policyReason: 'Customer must provide updated payment credentials before proceeding.',
        canAutoExecute: false,
      );
    }

    // Rule 3: Insufficient funds immediate retries are blocked
    if (category == FailureCategory.insufficientFunds) {
      if (strategy == RecommendedStrategy.retry) {
        return const PolicyEvaluation(
          policyStatus: 'BLOCKED',
          policyReason: 'Immediate retry blocked due to insufficient funds; scheduled delay or fallback required.',
          canAutoExecute: false,
        );
      }
      if (strategy == RecommendedStrategy.waitAndRetry || strategy == RecommendedStrategy.alternativeMethod) {
        return const PolicyEvaluation(
          policyStatus: 'ALLOWED',
          policyReason: 'Delayed retry or alternative payment method permitted under policy.',
          canAutoExecute: false,
        );
      }
    }

    // Rule 4: Network and gateway transient errors are safe retry candidates
    if (category == FailureCategory.networkError) {
      if (strategy == RecommendedStrategy.retry || strategy == RecommendedStrategy.waitAndRetry) {
        return const PolicyEvaluation(
          policyStatus: 'ALLOWED',
          policyReason: 'Transient network failure; safe retry strategy validated.',
          canAutoExecute: false,
        );
      }
    }

    // Rule 5: Authentication failures require customer interaction (OTP/3DS)
    if (category == FailureCategory.authenticationFailure) {
      return const PolicyEvaluation(
        policyStatus: 'REQUIRES_REVIEW',
        policyReason: 'Authentication failure requires customer to complete 3D Secure / MPIN verification.',
        canAutoExecute: false,
      );
    }

    // Rule 6: General bank declines
    if (category == FailureCategory.bankDecline) {
      if (strategy == RecommendedStrategy.alternativeMethod || strategy == RecommendedStrategy.waitAndRetry) {
        return const PolicyEvaluation(
          policyStatus: 'ALLOWED',
          policyReason: 'Bank decline strategy validated for fallback routing.',
          canAutoExecute: false,
        );
      }
      return const PolicyEvaluation(
        policyStatus: 'REQUIRES_REVIEW',
        policyReason: 'Bank decline with direct retry requires manual review or gateway health check.',
        canAutoExecute: false,
      );
    }

    // Default safety fallback: all unknown states require review
    return const PolicyEvaluation(
      policyStatus: 'REQUIRES_REVIEW',
      policyReason: 'Unrecognized failure or strategy combination; routed to manual review queue.',
      canAutoExecute: false,
    );
  }
}
