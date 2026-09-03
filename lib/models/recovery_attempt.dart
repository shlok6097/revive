import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an automated or manual payment recovery attempt executed by Revive.
class RecoveryAttempt {
  const RecoveryAttempt({
    required this.id,
    required this.merchantId,
    required this.transactionId,
    required this.strategy,
    required this.status,
    this.result,
    required this.reason,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Unique recovery attempt record identifier.
  final String id;

  /// Associated Merchant ID (Firebase Auth UID).
  final String merchantId;

  /// Target failed transaction identifier.
  final String transactionId;

  /// Recovery strategy identifier (e.g. 'SMART_ROUTING_RETRY', 'DYNAMIC_FALLBACK_UPI', 'PAYMENT_LINK_SMS').
  final String strategy;

  /// Lifecycle state ('INITIATED', 'IN_PROGRESS', 'SUCCESS', 'FAILED', 'CANCELLED').
  final String status;

  /// Detailed recovery execution outcome or response payload.
  final String? result;

  /// Algorithmic or heuristic rationale for selecting this strategy.
  final String reason;

  /// Timestamp when attempt was initiated.
  final DateTime createdAt;

  /// Timestamp of latest status update.
  final DateTime updatedAt;

  /// Creates a [RecoveryAttempt] from Firestore document snapshot.
  factory RecoveryAttempt.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return RecoveryAttempt.fromMap(data, doc.id);
  }

  /// Creates a [RecoveryAttempt] from raw Map and document ID.
  factory RecoveryAttempt.fromMap(Map<String, dynamic> data, String id) {
    return RecoveryAttempt(
      id: id,
      merchantId: data['merchantId'] as String? ?? '',
      transactionId: data['transactionId'] as String? ?? '',
      strategy: data['strategy'] as String? ?? '',
      status: data['status'] as String? ?? 'INITIATED',
      result: data['result'] as String?,
      reason: data['reason'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Serializes attempt into Firestore compatible Map.
  Map<String, dynamic> toFirestore() {
    return {
      'merchantId': merchantId,
      'transactionId': transactionId,
      'strategy': strategy,
      'status': status,
      'result': result,
      'reason': reason,
      'createdAt': Timestamp.fromDate(createdAt),
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
    String? result,
    String? reason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RecoveryAttempt(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      transactionId: transactionId ?? this.transactionId,
      strategy: strategy ?? this.strategy,
      status: status ?? this.status,
      result: result ?? this.result,
      reason: reason ?? this.reason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
