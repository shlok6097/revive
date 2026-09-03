import 'dart:convert';
import 'recovery_attempt.dart';

/// Structured decision produced by REVIVE's deterministic Recovery Strategy Engine.
///
/// Encapsulates policy validation, autonomy level constraints, and simulation parameters.
class RecoveryDecision {
  const RecoveryDecision({
    required this.strategy,
    required this.status,
    required this.reason,
    this.requiresReview = false,
    this.requiresConfirmation = false,
    this.simulated = true,
    this.attemptNumber = 1,
    this.policyStatus = 'ALLOWED',
    this.autonomyMode = 'MANUAL',
    required this.createdAt,
  });

  /// The decided recovery strategy ('RETRY', 'WAIT_AND_RETRY', 'ALTERNATIVE_METHOD', 'NO_ACTION', 'ESCALATE').
  final String strategy;

  /// Lifecycle state resulting from policy evaluation ('PLANNED', 'APPROVED', 'BLOCKED', 'SIMULATED', 'REQUIRES_REVIEW').
  final String status;

  /// Rationale for the deterministic strategy decision.
  final String reason;

  /// Whether human supervisor review is required before execution.
  final bool requiresReview;

  /// Whether operator confirmation is required (e.g. in ASSISTED mode).
  final bool requiresConfirmation;

  /// True during Phase 6 simulation. Real payments are never triggered.
  final bool simulated;

  /// Target attempt number for this strategy decision.
  final int attemptNumber;

  /// Policy compliance check status ('ALLOWED', 'BLOCKED', 'REQUIRES_REVIEW').
  final String policyStatus;

  /// Autonomy configuration mode active during decision ('MANUAL', 'ASSISTED', 'AUTONOMOUS').
  final String autonomyMode;

  /// Decision timestamp.
  final DateTime createdAt;

  bool get isApproved => status == 'APPROVED' || status == 'SIMULATED';
  bool get isBlocked => status == 'BLOCKED';
  bool get isAllowed => policyStatus == 'ALLOWED';

  Map<String, dynamic> toMap() {
    return {
      'strategy': strategy,
      'status': status,
      'reason': reason,
      'requiresReview': requiresReview,
      'requiresConfirmation': requiresConfirmation,
      'simulated': simulated,
      'attemptNumber': attemptNumber,
      'policyStatus': policyStatus,
      'autonomyMode': autonomyMode,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory RecoveryDecision.fromMap(Map<String, dynamic> map) {
    return RecoveryDecision(
      strategy: RecoveryStrategy.fromString(map['strategy'] as String?).value,
      status: RecoveryStatus.fromString(map['status'] as String?).value,
      reason: map['reason'] as String? ?? '',
      requiresReview: map['requiresReview'] as bool? ?? false,
      requiresConfirmation: map['requiresConfirmation'] as bool? ?? false,
      simulated: map['simulated'] as bool? ?? true,
      attemptNumber: (map['attemptNumber'] as num?)?.toInt() ?? 1,
      policyStatus: map['policyStatus'] as String? ?? 'ALLOWED',
      autonomyMode: map['autonomyMode'] as String? ?? 'MANUAL',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());
  factory RecoveryDecision.fromJson(String source) =>
      RecoveryDecision.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
