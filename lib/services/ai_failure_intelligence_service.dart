import 'dart:async';
import '../models/ai_decision.dart';
import '../models/transaction.dart';
import '../repositories/ai_decision_repository.dart';
import 'ai_service.dart';
import 'recovery_policy_service.dart';

/// Orchestrates the full AI Failure Intelligence pipeline:
///
/// 1. Telemetry extraction
/// 2. LLM / Heuristic classification
/// 3. Deterministic Policy Guardrail evaluation
/// 4. Structured Decision persistence into `ai_decisions`
///
/// NO recovery actions are executed in this phase.
class AIFailureIntelligenceService {
  AIFailureIntelligenceService({
    AIService? aiService,
    RecoveryPolicyService? policyService,
    AIDecisionRepository? decisionRepository,
  })  : _aiService = aiService ?? LocalLLMService(),
        _policyService = policyService ?? const RecoveryPolicyService(),
        _decisionRepository = decisionRepository ?? AIDecisionRepository();

  final AIService _aiService;
  final RecoveryPolicyService _policyService;
  final AIDecisionRepository _decisionRepository;

  /// Analyzes a failed transaction, validates policy, and persists the decision.
  Future<AIDecision> analyzeTransaction({
    required TransactionModel transaction,
    required String merchantId,
  }) async {
    // 1. Invoke AI model classification
    final aiResult = await _aiService.classifyPaymentFailure(
      transaction: transaction,
      merchantId: merchantId,
    );

    // 2. Deterministic policy guardrail validation
    final policyEval = _policyService.evaluate(
      failureCategory: aiResult.failureCategory,
      recommendedStrategy: aiResult.recommendedStrategy,
      transaction: transaction,
    );

    // 3. Assemble immutable AI decision record
    final decision = AIDecision(
      id: 'dec_${transaction.id}',
      merchantId: merchantId,
      transactionId: transaction.id,
      failureCategory: aiResult.failureCategory,
      recommendedStrategy: aiResult.recommendedStrategy,
      confidence: null,
      modelName: aiResult.modelName,
      modelVersion: aiResult.modelVersion,
      promptVersion: aiResult.promptVersion,
      reasoning: policyEval.policyReason,
      policyStatus: policyEval.policyStatus,
      createdAt: DateTime.now(),
    );

    // 4. Persist to Firestore
    try {
      await _decisionRepository.saveDecision(decision);
    } catch (_) {
      // Offline/local testing resilience
    }

    return decision;
  }
}
