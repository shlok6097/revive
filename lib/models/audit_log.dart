import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an immutable audit entry tracking actions and state changes in Revive.
class AuditLog {
  const AuditLog({
    required this.id,
    required this.merchantId,
    required this.action,
    required this.entityType,
    required this.entityId,
    this.metadata = const {},
    required this.createdAt,
  });

  /// Unique audit record identifier.
  final String id;

  /// Associated Merchant ID (Firebase Auth UID).
  final String merchantId;

  /// System or user action performed (e.g. 'POLICY_UPDATED', 'RECOVERY_TRIGGERED', 'MERCHANT_LOGIN').
  final String action;

  /// Entity classification ('TRANSACTION', 'POLICY', 'MERCHANT', 'CUSTOMER').
  final String entityType;

  /// Identifier of the modified entity.
  final String entityId;

  /// Contextual structured metadata.
  final Map<String, dynamic> metadata;

  /// Timestamp when event occurred.
  final DateTime createdAt;

  /// Creates an [AuditLog] from Firestore document snapshot.
  factory AuditLog.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AuditLog.fromMap(data, doc.id);
  }

  /// Creates an [AuditLog] from raw Map and document ID.
  factory AuditLog.fromMap(Map<String, dynamic> data, String id) {
    return AuditLog(
      id: id,
      merchantId: data['merchantId'] as String? ?? '',
      action: data['action'] as String? ?? '',
      entityType: data['entityType'] as String? ?? '',
      entityId: data['entityId'] as String? ?? '',
      metadata: data['metadata'] as Map<String, dynamic>? ?? {},
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Serializes audit log into Firestore compatible Map.
  Map<String, dynamic> toFirestore() {
    return {
      'merchantId': merchantId,
      'action': action,
      'entityType': entityType,
      'entityId': entityId,
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Returns a modified copy of this audit log.
  AuditLog copyWith({
    String? id,
    String? merchantId,
    String? action,
    String? entityType,
    String? entityId,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
  }) {
    return AuditLog(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      action: action ?? this.action,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
