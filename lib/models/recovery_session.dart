import 'package:cloud_firestore/cloud_firestore.dart';

/// Lifecycle statuses for a customer recovery session.
enum RecoverySessionStatus {
  active('ACTIVE'),
  used('USED'),
  expired('EXPIRED'),
  cancelled('CANCELLED'),
  failed('FAILED');

  const RecoverySessionStatus(this.value);
  final String value;

  static RecoverySessionStatus fromString(String? val) {
    if (val == null) return RecoverySessionStatus.failed;
    final normalized = val.trim().toUpperCase();
    for (final s in RecoverySessionStatus.values) {
      if (s.value == normalized) return s;
    }
    return RecoverySessionStatus.failed;
  }
}

/// Represents a secure, single-use, time-bound recovery session for customer payment retry.
///
/// SECURITY INVARIANT:
/// Only the SHA-256 hash ([tokenHash]) of the recovery token is stored.
/// The raw token is never persisted in Firestore or logged.
class RecoverySession {
  const RecoverySession({
    required this.id,
    required this.merchantId,
    required this.transactionId,
    this.customerId,
    this.recoveryAttemptId,
    required this.strategy,
    required this.status,
    required this.tokenHash,
    required this.expiresAt,
    this.usedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Unique recovery session identifier (e.g. 'ses_982341').
  final String id;

  /// Associated Merchant ID (Firebase Auth UID).
  final String merchantId;

  /// ID of the failed transaction to be recovered.
  final String transactionId;

  /// Associated customer ID (if known).
  final String? customerId;

  /// Associated recovery attempt ID in the strategy pipeline.
  final String? recoveryAttemptId;

  /// Governed recovery strategy ('RETRY', 'ALTERNATIVE_METHOD', 'WAIT_AND_RETRY').
  final String strategy;

  /// Current session status ('ACTIVE', 'USED', 'EXPIRED', 'CANCELLED', 'FAILED').
  final String status;

  /// SHA-256 cryptographic hash of the session recovery token.
  final String tokenHash;

  /// Timestamp when the recovery link expires.
  final DateTime expiresAt;

  /// Timestamp when the session was used to complete payment.
  final DateTime? usedAt;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Last modification timestamp.
  final DateTime updatedAt;

  bool get isActive => status == 'ACTIVE' && DateTime.now().isBefore(expiresAt);
  bool get isUsed => status == 'USED';
  bool get isExpired => status == 'EXPIRED' || DateTime.now().isAfter(expiresAt);

  /// Creates a [RecoverySession] instance from Firestore document snapshot.
  factory RecoverySession.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return RecoverySession.fromMap(data, doc.id);
  }

  /// Creates a [RecoverySession] instance from raw Map and document ID.
  factory RecoverySession.fromMap(Map<String, dynamic> data, String id) {
    return RecoverySession(
      id: id,
      merchantId: data['merchantId'] as String? ?? '',
      transactionId: data['transactionId'] as String? ?? '',
      customerId: data['customerId'] as String?,
      recoveryAttemptId: data['recoveryAttemptId'] as String?,
      strategy: data['strategy'] as String? ?? 'RETRY',
      status: RecoverySessionStatus.fromString(data['status'] as String?).value,
      tokenHash: data['tokenHash'] as String? ?? '',
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      usedAt: (data['usedAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Serializes recovery session into Firestore compatible Map.
  Map<String, dynamic> toFirestore() {
    return {
      'merchantId': merchantId,
      'transactionId': transactionId,
      'customerId': customerId,
      'recoveryAttemptId': recoveryAttemptId,
      'strategy': strategy,
      'status': status,
      'tokenHash': tokenHash,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'usedAt': usedAt != null ? Timestamp.fromDate(usedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Returns a modified copy of this recovery session.
  RecoverySession copyWith({
    String? id,
    String? merchantId,
    String? transactionId,
    String? customerId,
    String? recoveryAttemptId,
    String? strategy,
    String? status,
    String? tokenHash,
    DateTime? expiresAt,
    DateTime? usedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RecoverySession(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      transactionId: transactionId ?? this.transactionId,
      customerId: customerId ?? this.customerId,
      recoveryAttemptId: recoveryAttemptId ?? this.recoveryAttemptId,
      strategy: strategy ?? this.strategy,
      status: status ?? this.status,
      tokenHash: tokenHash ?? this.tokenHash,
      expiresAt: expiresAt ?? this.expiresAt,
      usedAt: usedAt ?? this.usedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
