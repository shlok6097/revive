import 'dart:convert';

/// Lifecycle statuses resulting from recovery execution in REVIVE.
enum RecoveryExecutionStatus {
  simulatedSuccess('SIMULATED_SUCCESS'),
  simulatedFailure('SIMULATED_FAILURE'),
  executing('EXECUTING'),
  success('SUCCESS'),
  failed('FAILED'),
  blocked('BLOCKED'),
  notExecutable('NOT_EXECUTABLE'),
  duplicate('DUPLICATE'),
  requiresConfirmation('REQUIRES_CONFIRMATION');

  const RecoveryExecutionStatus(this.value);
  final String value;

  static RecoveryExecutionStatus fromString(String? val) {
    if (val == null) return RecoveryExecutionStatus.failed;
    final normalized = val.trim().toUpperCase();
    for (final s in RecoveryExecutionStatus.values) {
      if (s.value == normalized) return s;
    }
    return RecoveryExecutionStatus.failed;
  }
}

/// Represents the structured outcome of a simulated or live recovery execution.
class RecoveryExecutionResult {
  const RecoveryExecutionResult({
    required this.success,
    required this.status,
    required this.message,
    this.simulated = true,
    required this.executedAt,
    this.externalReference,
    this.executionId,
    this.transactionId,
    this.recoveryAttemptId,
    this.isDuplicate = false,
  });

  /// Whether the execution or simulation completed successfully.
  final bool success;

  /// High-level execution lifecycle status ('SIMULATED_SUCCESS', 'EXECUTING', 'BLOCKED', etc.).
  final String status;

  /// Human-readable explanation of the execution outcome.
  final String message;

  /// Whether this action was executed in safe simulation mode without live payment calls.
  final bool simulated;

  /// Timestamp when the execution was initiated/completed.
  final DateTime executedAt;

  /// External tracking reference ID (e.g. `sim_123456` or `rec_live_...`).
  final String? externalReference;

  /// Deterministic execution idempotency identifier.
  final String? executionId;

  /// ID of the target transaction.
  final String? transactionId;

  /// ID of the recovery attempt.
  final String? recoveryAttemptId;

  /// Whether this result was retrieved from an existing idempotent execution record.
  final bool isDuplicate;

  bool get isSimulatedSuccess => status == 'SIMULATED_SUCCESS';
  bool get isBlocked => status == 'BLOCKED';
  bool get requiresConfirmation => status == 'REQUIRES_CONFIRMATION';

  Map<String, dynamic> toMap() {
    return {
      'success': success,
      'status': status,
      'message': message,
      'simulated': simulated,
      'executedAt': executedAt.toIso8601String(),
      'externalReference': externalReference,
      'executionId': executionId,
      'transactionId': transactionId,
      'recoveryAttemptId': recoveryAttemptId,
      'isDuplicate': isDuplicate,
    };
  }

  factory RecoveryExecutionResult.fromMap(Map<String, dynamic> map) {
    return RecoveryExecutionResult(
      success: map['success'] as bool? ?? false,
      status: RecoveryExecutionStatus.fromString(map['status'] as String?).value,
      message: map['message'] as String? ?? '',
      simulated: map['simulated'] as bool? ?? true,
      executedAt: map['executedAt'] != null
          ? DateTime.tryParse(map['executedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      externalReference: map['externalReference'] as String?,
      executionId: map['executionId'] as String?,
      transactionId: map['transactionId'] as String?,
      recoveryAttemptId: map['recoveryAttemptId'] as String?,
      isDuplicate: map['isDuplicate'] as bool? ?? false,
    );
  }

  String toJson() => jsonEncode(toMap());
  factory RecoveryExecutionResult.fromJson(String source) =>
      RecoveryExecutionResult.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
