import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a payment transaction processed or monitored by Revive.
///
/// Retains granular, structured failure taxonomy ([errorCode], [errorReason],
/// [errorSource], [errorStep]), Phase 8 recovery outcome metadata ([recoveryOutcome],
/// [recoveredAt], [recoverySessionId]), and [simulated] flag for demo safety.
class TransactionModel {
  const TransactionModel({
    required this.id,
    required this.merchantId,
    required this.amount,
    this.currency = 'INR',
    required this.status,
    required this.paymentMethod,
    required this.bank,
    this.errorCode,
    this.errorReason,
    this.errorSource,
    this.errorStep,
    this.customerId,
    this.recoveryOutcome,
    this.recoveredAt,
    this.recoverySessionId,
    this.simulated = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Unique transaction identifier (e.g. 'tx_rv_982401').
  final String id;

  /// Associated Merchant ID (Firebase Auth UID).
  final String merchantId;

  /// Transaction total in major units (e.g. INR 4999.00).
  final double amount;

  /// ISO 4217 Currency Code (default: 'INR').
  final String currency;

  /// Transaction lifecycle state ('SUCCESS', 'FAILED', 'PENDING', 'RECOVERED').
  final String status;

  /// Payment instrument used ('UPI', 'CARD', 'NETBANKING', 'WALLET').
  final String paymentMethod;

  /// Issuing or acquiring banking entity (e.g. 'HDFC', 'ICICI', 'SBI', 'AXIS').
  final String bank;

  /// Structured error code (e.g. 'BAD_REQUEST_GATEWAY_TIMEOUT', 'INSUFFICIENT_FUNDS').
  final String? errorCode;

  /// Human-readable explanation of the failure.
  final String? errorReason;

  /// Node where failure originated ('BANK_GATEWAY', 'ISSUER_NETWORK', 'CUSTOMER_APP', 'AUTHENTICATION_SERVER').
  final String? errorSource;

  /// Exact funnel step where disruption occurred ('OTP_VERIFICATION', 'DEBIT_ATTEMPT', 'PAYMENT_AUTHORIZATION').
  final String? errorStep;

  /// Associated customer ID if linked.
  final String? customerId;

  /// Structured recovery outcome ('RECOVERED', 'NOT_RECOVERED', 'EXPIRED', 'CANCELLED').
  final String? recoveryOutcome;

  /// Timestamp when transaction was successfully recovered.
  final DateTime? recoveredAt;

  /// ID of the recovery session that facilitated recovery.
  final String? recoverySessionId;

  /// Whether this transaction is a simulated demo transaction.
  final bool simulated;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Last modification timestamp.
  final DateTime updatedAt;

  bool get isRecovered => status == 'RECOVERED' || recoveryOutcome == 'RECOVERED';

  /// Creates a [TransactionModel] from Firestore document snapshot.
  factory TransactionModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return TransactionModel.fromMap(data, doc.id);
  }

  /// Creates a [TransactionModel] from a raw Map and document ID.
  factory TransactionModel.fromMap(Map<String, dynamic> data, String id) {
    return TransactionModel(
      id: id,
      merchantId: data['merchantId'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      currency: data['currency'] as String? ?? 'INR',
      status: data['status'] as String? ?? 'PENDING',
      paymentMethod: data['paymentMethod'] as String? ?? 'UPI',
      bank: data['bank'] as String? ?? 'UNKNOWN',
      errorCode: data['errorCode'] as String?,
      errorReason: data['errorReason'] as String?,
      errorSource: data['errorSource'] as String?,
      errorStep: data['errorStep'] as String?,
      customerId: data['customerId'] as String?,
      recoveryOutcome: data['recoveryOutcome'] as String?,
      recoveredAt: (data['recoveredAt'] as Timestamp?)?.toDate(),
      recoverySessionId: data['recoverySessionId'] as String?,
      simulated: data['simulated'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Serializes transaction into Firestore compatible Map with server timestamps.
  Map<String, dynamic> toFirestore() {
    return {
      'merchantId': merchantId,
      'amount': amount,
      'currency': currency,
      'status': status,
      'paymentMethod': paymentMethod,
      'bank': bank,
      'errorCode': errorCode,
      'errorReason': errorReason,
      'errorSource': errorSource,
      'errorStep': errorStep,
      'customerId': customerId,
      'recoveryOutcome': recoveryOutcome,
      'recoveredAt': recoveredAt != null ? Timestamp.fromDate(recoveredAt!) : null,
      'recoverySessionId': recoverySessionId,
      'simulated': simulated,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Returns a modified copy of this transaction.
  TransactionModel copyWith({
    String? id,
    String? merchantId,
    double? amount,
    String? currency,
    String? status,
    String? paymentMethod,
    String? bank,
    String? errorCode,
    String? errorReason,
    String? errorSource,
    String? errorStep,
    String? customerId,
    String? recoveryOutcome,
    DateTime? recoveredAt,
    String? recoverySessionId,
    bool? simulated,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      bank: bank ?? this.bank,
      errorCode: errorCode ?? this.errorCode,
      errorReason: errorReason ?? this.errorReason,
      errorSource: errorSource ?? this.errorSource,
      errorStep: errorStep ?? this.errorStep,
      customerId: customerId ?? this.customerId,
      recoveryOutcome: recoveryOutcome ?? this.recoveryOutcome,
      recoveredAt: recoveredAt ?? this.recoveredAt,
      recoverySessionId: recoverySessionId ?? this.recoverySessionId,
      simulated: simulated ?? this.simulated,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
