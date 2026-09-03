import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a payment transaction processed or monitored by Revive.
///
/// Retains granular, structured failure taxonomy ([errorCode], [errorReason],
/// [errorSource], [errorStep]) to empower REVIVE's recovery classification engine.
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

  /// Creation timestamp.
  final DateTime createdAt;

  /// Last modification timestamp.
  final DateTime updatedAt;

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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
