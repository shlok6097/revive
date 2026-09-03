import 'package:cloud_firestore/cloud_firestore.dart';

/// Validated failure categories recognized by REVIVE AI engine.
enum FailureCategory {
  bankDecline('BANK_DECLINE'),
  insufficientFunds('INSUFFICIENT_FUNDS'),
  networkError('NETWORK_ERROR'),
  invalidDetails('INVALID_DETAILS'),
  authenticationFailure('AUTHENTICATION_FAILURE'),
  fraudRisk('FRAUD_RISK'),
  unknown('UNKNOWN');

  const FailureCategory(this.value);
  final String value;

  static FailureCategory fromString(String? val) {
    if (val == null) return FailureCategory.unknown;
    final normalized = val.trim().toUpperCase();
    for (final cat in FailureCategory.values) {
      if (cat.value == normalized) return cat;
    }
    return FailureCategory.unknown;
  }
}

/// Validated recovery strategies recommended by REVIVE AI engine.
enum RecommendedStrategy {
  retry('RETRY'),
  alternativeMethod('ALTERNATIVE_METHOD'),
  waitAndRetry('WAIT_AND_RETRY'),
  noAction('NO_ACTION'),
  escalate('ESCALATE');

  const RecommendedStrategy(this.value);
  final String value;

  static RecommendedStrategy fromString(String? val) {
    if (val == null) return RecommendedStrategy.escalate;
    final normalized = val.trim().toUpperCase();
    for (final strat in RecommendedStrategy.values) {
      if (strat.value == normalized) return strat;
    }
    return RecommendedStrategy.escalate;
  }
}

/// Represents an AI-generated failure classification and strategy recommendation.
///
/// Implements strict classification taxonomy and model attribution for compliance.
class AIDecision {
  const AIDecision({
    required this.id,
    required this.merchantId,
    required this.transactionId,
    required this.failureCategory,
    required this.recommendedStrategy,
    this.confidence,
    this.modelName = 'Phi-3-mini-4k-instruct-q4',
    this.modelVersion = 'v1.0',
    this.promptVersion = 'revive-payment-classifier-v1',
    this.reasoning,
    this.policyStatus = 'REQUIRES_REVIEW',
    required this.createdAt,
  });

  /// Unique AI decision identifier in `ai_decisions/{decisionId}`.
  final String id;

  /// Associated Merchant ID (Firebase Auth UID).
  final String merchantId;

  /// Target transaction identifier in `transactions/{transactionId}`.
  final String transactionId;

  /// Standardized failure classification category.
  final String failureCategory;

  /// Recommended non-executing strategy suggestion.
  final String recommendedStrategy;

  /// Optional confidence rating (null by default in Phase 5).
  final double? confidence;

  /// Model identifier that produced this classification.
  final String modelName;

  /// Model release/weights version.
  final String modelVersion;

  /// Versioned classification prompt identifier.
  final String promptVersion;

  /// Contextual reasoning text.
  final String? reasoning;

  /// Deterministic policy status: 'ALLOWED', 'BLOCKED', 'REQUIRES_REVIEW'.
  final String policyStatus;

  /// Decision timestamp.
  final DateTime createdAt;

  /// Backward-compatibility alias for decision string.
  String get decision => recommendedStrategy;

  /// Backward-compatibility alias for reason string.
  String get reason => reasoning ?? '';

  /// Creates an [AIDecision] from Firestore document snapshot.
  factory AIDecision.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AIDecision.fromMap(data, doc.id);
  }

  /// Creates an [AIDecision] from raw Map and document ID.
  factory AIDecision.fromMap(Map<String, dynamic> data, String id) {
    final rawCat = data['failureCategory'] as String? ?? data['category'] as String?;
    final rawStrat = data['recommendedStrategy'] as String? ?? data['decision'] as String?;

    return AIDecision(
      id: id,
      merchantId: data['merchantId'] as String? ?? '',
      transactionId: data['transactionId'] as String? ?? '',
      failureCategory: FailureCategory.fromString(rawCat).value,
      recommendedStrategy: RecommendedStrategy.fromString(rawStrat).value,
      confidence: (data['confidence'] as num?)?.toDouble(),
      modelName: data['modelName'] as String? ?? 'Phi-3-mini-4k-instruct-q4',
      modelVersion: data['modelVersion'] as String? ?? 'v1.0',
      promptVersion: data['promptVersion'] as String? ?? 'revive-payment-classifier-v1',
      reasoning: data['reasoning'] as String? ?? data['reason'] as String?,
      policyStatus: data['policyStatus'] as String? ?? 'REQUIRES_REVIEW',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Serializes decision into Firestore-compatible Map.
  Map<String, dynamic> toFirestore() {
    return {
      'merchantId': merchantId,
      'transactionId': transactionId,
      'failureCategory': failureCategory,
      'recommendedStrategy': recommendedStrategy,
      'confidence': confidence,
      'modelName': modelName,
      'modelVersion': modelVersion,
      'promptVersion': promptVersion,
      'reasoning': reasoning,
      'policyStatus': policyStatus,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Returns a modified copy of this AI decision.
  AIDecision copyWith({
    String? id,
    String? merchantId,
    String? transactionId,
    String? failureCategory,
    String? recommendedStrategy,
    double? confidence,
    String? modelName,
    String? modelVersion,
    String? promptVersion,
    String? reasoning,
    String? policyStatus,
    DateTime? createdAt,
  }) {
    return AIDecision(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      transactionId: transactionId ?? this.transactionId,
      failureCategory: failureCategory ?? this.failureCategory,
      recommendedStrategy: recommendedStrategy ?? this.recommendedStrategy,
      confidence: confidence ?? this.confidence,
      modelName: modelName ?? this.modelName,
      modelVersion: modelVersion ?? this.modelVersion,
      promptVersion: promptVersion ?? this.promptVersion,
      reasoning: reasoning ?? this.reasoning,
      policyStatus: policyStatus ?? this.policyStatus,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
