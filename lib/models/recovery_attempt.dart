import 'package:cloud_firestore/cloud_firestore.dart';

/// Supported recovery strategy types in REVIVE.
enum RecoveryStrategy {
  retry('RETRY'),
  waitAndRetry('WAIT_AND_RETRY'),
  alternativeMethod('ALTERNATIVE_METHOD'),
  noAction('NO_ACTION'),
  escalate('ESCALATE');

  const RecoveryStrategy(this.value);
  final String value;

  static RecoveryStrategy fromString(String? val) {
    if (val == null) return RecoveryStrategy.escalate;
    final normalized = val.trim().toUpperCase();
    for (final s in RecoveryStrategy.values) {
      if (s.value == normalized) return s;
    }
    return RecoveryStrategy.escalate;
  }
}

/// Lifecycle status for a recovery attempt.
enum RecoveryStatus {
  planned('PLANNED'),
  approved('APPROVED'),
  blocked('BLOCKED'),
  simulated('SIMULATED'),
  completed('COMPLETED'),
  failed('FAILED'),
  requiresReview('REQUIRES_REVIEW');

  const RecoveryStatus(this.value);
  final String value;

  static RecoveryStatus fromString(String? val) {
    if (val == null) return RecoveryStatus.requiresReview;
    final normalized = val.trim().toUpperCase();
    for (final s in RecoveryStatus.values) {
      if (s.value == normalized) return s;
    }
    return RecoveryStatus.requiresReview;
  }
}

/// Trigger origins initiating a recovery strategy.
enum RecoveryTrigger {
  aiRecommendation('AI_RECOMMENDATION'),
  ruleEngine('RULE_ENGINE'),
  manual('MANUAL'),
  system('SYSTEM');

  const RecoveryTrigger(this.value);
  final String value;

  static RecoveryTrigger fromString(String? val) {
    if (val == null) return RecoveryTrigger.aiRecommendation;
    final normalized = val.trim().toUpperCase();
    for (final t in RecoveryTrigger.values) {
      if (t.value == normalized) return t;
    }
    return RecoveryTrigger.aiRecommendation;
  }
}

/// Represents an automated, assisted, or manual payment recovery attempt in REVIVE.
///
/// INVARIANT:
/// During Phase 6, all attempts operate in simulation mode (`simulated = true`).
/// No real payment operations are triggered on payment gateways.
class RecoveryAttempt {
  const RecoveryAttempt({
    required this.id,
    required this.merchantId,
    required this.transactionId,
    required this.strategy,
    required this.status,
    this.attemptNumber = 1,
    this.trigger = 'AI_RECOMMENDATION',
    required this.reason,
    this.aiDecisionId,
    this.policyStatus = 'ALLOWED',
    this.simulated = true,
    this.result,
    required this.createdAt,
    this.completedAt,
    required this.updatedAt,
  });

  /// Unique recovery attempt record identifier.
  final String id;

  /// Associated Merchant ID (Firebase Auth UID).
  final String merchantId;

  /// Target failed transaction identifier.
  final String transactionId;

  /// Recovery strategy identifier ('RETRY', 'WAIT_AND_RETRY', 'ALTERNATIVE_METHOD', 'NO_ACTION', 'ESCALATE').
  final String strategy;

  /// Lifecycle state ('PLANNED', 'APPROVED', 'BLOCKED', 'SIMULATED', 'COMPLETED', 'FAILED', 'REQUIRES_REVIEW').
  final String status;

  /// Sequential iteration number for this transaction (1-indexed).
  final int attemptNumber;

  /// Trigger origin ('AI_RECOMMENDATION', 'RULE_ENGINE', 'MANUAL', 'SYSTEM').
  final String trigger;

  /// Rationale for selecting and approving this attempt.
  final String reason;

  /// Reference ID of corresponding `ai_decisions` record, if applicable.
  final String? aiDecisionId;

  /// Deterministic policy status ('ALLOWED', 'BLOCKED', 'REQUIRES_REVIEW').
  final String policyStatus;

  /// Whether this attempt was executed in simulation mode (true in Phase 6).
  final bool simulated;

  /// Detailed recovery execution outcome or simulated response.
  final String? result;

  /// Timestamp when attempt was generated.
  final DateTime createdAt;

  /// Timestamp when attempt completed or finished simulation.
  final DateTime? completedAt;

  /// Timestamp of latest status update.
  final DateTime updatedAt;

  /// Creates a [RecoveryAttempt] from Firestore document snapshot.
  factory RecoveryAttempt.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return RecoveryAttempt.fromMap(data, doc.id);
  }

  /// Creates a [RecoveryAttempt] from raw Map and document ID.
  factory RecoveryAttempt.fromMap(Map<String, dynamic> data, String id) {
    final rawStrat = data['strategy'] as String?;
    final rawStatus = data['status'] as String?;
    final rawTrigger = data['trigger'] as String?;

    return RecoveryAttempt(
      id: id,
      merchantId: data['merchantId'] as String? ?? '',
      transactionId: data['transactionId'] as String? ?? '',
      strategy: RecoveryStrategy.fromString(rawStrat).value,
      status: RecoveryStatus.fromString(rawStatus).value,
      attemptNumber: (data['attemptNumber'] as num?)?.toInt() ?? 1,
      trigger: RecoveryTrigger.fromString(rawTrigger).value,
      reason: data['reason'] as String? ?? '',
      aiDecisionId: data['aiDecisionId'] as String?,
      policyStatus: data['policyStatus'] as String? ?? 'ALLOWED',
      simulated: data['simulated'] as bool? ?? true,
      result: data['result'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Serializes attempt into Firestore-compatible Map.
  Map<String, dynamic> toFirestore() {
    return {
      'merchantId': merchantId,
      'transactionId': transactionId,
      'strategy': strategy,
      'status': status,
      'attemptNumber': attemptNumber,
      'trigger': trigger,
      'reason': reason,
      'aiDecisionId': aiDecisionId,
      'policyStatus': policyStatus,
      'simulated': simulated,
      'result': result,
      'createdAt': Timestamp.fromDate(createdAt),
      if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt!),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Returns a modified copy of this recovery attempt.
  RecoveryAttempt copyWith({
    String? id,
    String? merchantId,
    String? transactionId,
    String? strategy,
    String? status,
    int? attemptNumber,
    String? trigger,
    String? reason,
    String? aiDecisionId,
    String? policyStatus,
    bool? simulated,
    String? result,
    DateTime? createdAt,
    DateTime? completedAt,
    DateTime? updatedAt,
  }) {
    return RecoveryAttempt(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      transactionId: transactionId ?? this.transactionId,
      strategy: strategy ?? this.strategy,
      status: status ?? this.status,
      attemptNumber: attemptNumber ?? this.attemptNumber,
      trigger: trigger ?? this.trigger,
      reason: reason ?? this.reason,
      aiDecisionId: aiDecisionId ?? this.aiDecisionId,
      policyStatus: policyStatus ?? this.policyStatus,
      simulated: simulated ?? this.simulated,
      result: result ?? this.result,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
