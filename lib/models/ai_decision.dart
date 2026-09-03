import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an AI or heuristic decision generated for transaction recovery evaluation.
class AIDecision {
  const AIDecision({
    required this.id,
    required this.merchantId,
    required this.transactionId,
    required this.decision,
    required this.confidence,
    required this.reason,
    required this.createdAt,
  });

  /// Unique AI decision log identifier.
  final String id;

  /// Associated Merchant ID (Firebase Auth UID).
  final String merchantId;

  /// Target transaction identifier.
  final String transactionId;

  /// Recommended action (e.g. 'RETRY_VIA_SECONDARY_GATEWAY', 'SEND_INSTANT_CHECKOUT_LINK').
  final String decision;

  /// Statistical confidence score between 0.0 and 1.0.
  final double confidence;

  /// Detailed contextual rationale for the decision.
  final String reason;

  /// Timestamp when decision was computed.
  final DateTime createdAt;

  /// Creates an [AIDecision] from Firestore document snapshot.
  factory AIDecision.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AIDecision.fromMap(data, doc.id);
  }

  /// Creates an [AIDecision] from raw Map and document ID.
  factory AIDecision.fromMap(Map<String, dynamic> data, String id) {
    return AIDecision(
      id: id,
      merchantId: data['merchantId'] as String? ?? '',
      transactionId: data['transactionId'] as String? ?? '',
      decision: data['decision'] as String? ?? '',
      confidence: (data['confidence'] as num?)?.toDouble() ?? 0.0,
      reason: data['reason'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Serializes decision into Firestore compatible Map.
  Map<String, dynamic> toFirestore() {
    return {
      'merchantId': merchantId,
      'transactionId': transactionId,
      'decision': decision,
      'confidence': confidence,
      'reason': reason,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Returns a modified copy of this AI decision.
  AIDecision copyWith({
    String? id,
    String? merchantId,
    String? transactionId,
    String? decision,
    double? confidence,
    String? reason,
    DateTime? createdAt,
  }) {
    return AIDecision(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      transactionId: transactionId ?? this.transactionId,
      decision: decision ?? this.decision,
      confidence: confidence ?? this.confidence,
      reason: reason ?? this.reason,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
