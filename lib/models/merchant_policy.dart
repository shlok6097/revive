import 'package:cloud_firestore/cloud_firestore.dart';

/// Supported autonomy operational modes for the REVIVE recovery engine.
enum AutonomyMode {
  manual('MANUAL'),
  assisted('ASSISTED'),
  autonomous('AUTONOMOUS');

  const AutonomyMode(this.value);
  final String value;

  static AutonomyMode fromString(String? val) {
    if (val == null) return AutonomyMode.manual;
    final normalized = val.trim().toUpperCase();
    if (normalized == 'SEMI_AUTONOMOUS') return AutonomyMode.assisted;
    if (normalized == 'FULL_AUTONOMOUS') return AutonomyMode.autonomous;
    for (final mode in AutonomyMode.values) {
      if (mode.value == normalized) return mode;
    }
    return AutonomyMode.manual;
  }
}

/// Defines recovery autonomy rules, guardrails, and permitted strategies for a merchant.
class MerchantPolicy {
  const MerchantPolicy({
    required this.id,
    required this.merchantId,
    this.autonomyMode = 'MANUAL',
    this.automaticRetryEnabled = false,
    this.maxAutomaticRetries = 1,
    this.allowNetworkRetry = true,
    this.allowBankDeclineRetry = true,
    this.allowAlternativeMethod = true,
    this.requireReviewForBankDecline = false,
    this.requireReviewForAuthenticationFailure = true,
    this.allowedStrategies = const [
      'RETRY',
      'WAIT_AND_RETRY',
      'ALTERNATIVE_METHOD',
    ],
    DateTime? createdAt,
    required this.updatedAt,
  }) : createdAt = createdAt ?? updatedAt;

  /// Unique policy configuration document identifier (typically merchant UID).
  final String id;

  /// Associated Merchant ID (Firebase Auth UID).
  final String merchantId;

  /// Policy execution mode ('MANUAL', 'ASSISTED', 'AUTONOMOUS').
  final String autonomyMode;

  /// Whether automated retry triggers are allowed to execute without manual prompt.
  final bool automaticRetryEnabled;

  /// Maximum automatic retry iterations per transaction (default: 1).
  final int maxAutomaticRetries;

  /// Whether transient network error retries are permitted.
  final bool allowNetworkRetry;

  /// Whether bank decline first-attempt retries are permitted.
  final bool allowBankDeclineRetry;

  /// Whether customer alternative payment switches (e.g. UPI fallback) are permitted.
  final bool allowAlternativeMethod;

  /// Whether bank decline recovery always requires human supervisor review.
  final bool requireReviewForBankDecline;

  /// Whether authentication / 3DS failures require supervisor review.
  final bool requireReviewForAuthenticationFailure;

  /// Whitelist of enabled recovery strategy algorithms.
  final List<String> allowedStrategies;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Last modification timestamp.
  final DateTime updatedAt;

  /// Alias for backward compatibility with Phase 2 models.
  int get maxRecoveryAttempts => maxAutomaticRetries;

  /// Creates a [MerchantPolicy] from Firestore document snapshot.
  factory MerchantPolicy.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return MerchantPolicy.fromMap(data, doc.id);
  }

  /// Creates a [MerchantPolicy] from raw Map and document ID.
  factory MerchantPolicy.fromMap(Map<String, dynamic> data, String id) {
    final rawMode = data['autonomyMode'] as String?;
    final mode = AutonomyMode.fromString(rawMode).value;

    return MerchantPolicy(
      id: id,
      merchantId: data['merchantId'] as String? ?? id,
      autonomyMode: mode,
      automaticRetryEnabled: data['automaticRetryEnabled'] as bool? ?? false,
      maxAutomaticRetries: (data['maxAutomaticRetries'] as num?)?.toInt() ??
          (data['maxRecoveryAttempts'] as num?)?.toInt() ??
          1,
      allowNetworkRetry: data['allowNetworkRetry'] as bool? ?? true,
      allowBankDeclineRetry: data['allowBankDeclineRetry'] as bool? ?? true,
      allowAlternativeMethod: data['allowAlternativeMethod'] as bool? ?? true,
      requireReviewForBankDecline: data['requireReviewForBankDecline'] as bool? ?? false,
      requireReviewForAuthenticationFailure:
          data['requireReviewForAuthenticationFailure'] as bool? ?? true,
      allowedStrategies: (data['allowedStrategies'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['RETRY', 'WAIT_AND_RETRY', 'ALTERNATIVE_METHOD'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Serializes policy into Firestore-compatible Map.
  Map<String, dynamic> toFirestore() {
    return {
      'merchantId': merchantId,
      'autonomyMode': autonomyMode,
      'automaticRetryEnabled': automaticRetryEnabled,
      'maxAutomaticRetries': maxAutomaticRetries,
      'allowNetworkRetry': allowNetworkRetry,
      'allowBankDeclineRetry': allowBankDeclineRetry,
      'allowAlternativeMethod': allowAlternativeMethod,
      'requireReviewForBankDecline': requireReviewForBankDecline,
      'requireReviewForAuthenticationFailure': requireReviewForAuthenticationFailure,
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
    bool? automaticRetryEnabled,
    int? maxAutomaticRetries,
    bool? allowNetworkRetry,
    bool? allowBankDeclineRetry,
    bool? allowAlternativeMethod,
    bool? requireReviewForBankDecline,
    bool? requireReviewForAuthenticationFailure,
    List<String>? allowedStrategies,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MerchantPolicy(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      autonomyMode: autonomyMode ?? this.autonomyMode,
      automaticRetryEnabled: automaticRetryEnabled ?? this.automaticRetryEnabled,
      maxAutomaticRetries: maxAutomaticRetries ?? this.maxAutomaticRetries,
      allowNetworkRetry: allowNetworkRetry ?? this.allowNetworkRetry,
      allowBankDeclineRetry: allowBankDeclineRetry ?? this.allowBankDeclineRetry,
      allowAlternativeMethod: allowAlternativeMethod ?? this.allowAlternativeMethod,
      requireReviewForBankDecline:
          requireReviewForBankDecline ?? this.requireReviewForBankDecline,
      requireReviewForAuthenticationFailure:
          requireReviewForAuthenticationFailure ?? this.requireReviewForAuthenticationFailure,
      allowedStrategies: allowedStrategies ?? this.allowedStrategies,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
