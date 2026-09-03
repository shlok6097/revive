import 'package:cloud_firestore/cloud_firestore.dart';

/// Defines recovery autonomy rules, guardrails, and permitted strategies for a merchant.
class MerchantPolicy {
  const MerchantPolicy({
    required this.id,
    required this.merchantId,
    this.autonomyMode = 'SEMI_AUTONOMOUS',
    this.maxRecoveryAttempts = 3,
    this.allowedStrategies = const [
      'SMART_ROUTING_RETRY',
      'DYNAMIC_FALLBACK_UPI',
      'PAYMENT_LINK_SMS',
    ],
    required this.createdAt,
    required this.updatedAt,
  });

  /// Unique policy configuration document identifier.
  final String id;

  /// Associated Merchant ID (Firebase Auth UID).
  final String merchantId;

  /// Policy execution mode ('MANUAL', 'SEMI_AUTONOMOUS', 'FULL_AUTONOMOUS').
  final String autonomyMode;

  /// Maximum recovery iterations allowed per single failed transaction.
  final int maxRecoveryAttempts;

  /// Whitelist of enabled recovery strategy algorithms.
  final List<String> allowedStrategies;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Last modification timestamp.
  final DateTime updatedAt;

  /// Creates a [MerchantPolicy] from Firestore document snapshot.
  factory MerchantPolicy.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return MerchantPolicy.fromMap(data, doc.id);
  }

  /// Creates a [MerchantPolicy] from raw Map and document ID.
  factory MerchantPolicy.fromMap(Map<String, dynamic> data, String id) {
    return MerchantPolicy(
      id: id,
      merchantId: data['merchantId'] as String? ?? '',
      autonomyMode: data['autonomyMode'] as String? ?? 'SEMI_AUTONOMOUS',
      maxRecoveryAttempts: (data['maxRecoveryAttempts'] as num?)?.toInt() ?? 3,
      allowedStrategies: (data['allowedStrategies'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['SMART_ROUTING_RETRY', 'DYNAMIC_FALLBACK_UPI', 'PAYMENT_LINK_SMS'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Serializes policy into Firestore compatible Map.
  Map<String, dynamic> toFirestore() {
    return {
      'merchantId': merchantId,
      'autonomyMode': autonomyMode,
      'maxRecoveryAttempts': maxRecoveryAttempts,
      'allowedStrategies': allowedStrategies,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Returns a modified copy of this merchant policy.
  MerchantPolicy copyWith({
    String? id,
    String? merchantId,
    String? autonomyMode,
    int? maxRecoveryAttempts,
    List<String>? allowedStrategies,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MerchantPolicy(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      autonomyMode: autonomyMode ?? this.autonomyMode,
      maxRecoveryAttempts: maxRecoveryAttempts ?? this.maxRecoveryAttempts,
      allowedStrategies: allowedStrategies ?? this.allowedStrategies,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
