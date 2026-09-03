import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents real-time or sampled health metrics for a banking gateway / network node.
class BankHealth {
  const BankHealth({
    required this.id,
    this.merchantId,
    required this.bankName,
    required this.status,
    required this.successRate,
    required this.failureRate,
    required this.latency,
    required this.lastUpdatedAt,
  });

  /// Unique bank health record identifier.
  final String id;

  /// Optional merchant-specific isolation ID (null if global benchmark).
  final String? merchantId;

  /// Bank or gateway identifier (e.g. 'HDFC', 'ICICI', 'SBI', 'AXIS').
  final String bankName;

  /// Node operational status ('OPTIMAL', 'DEGRADED', 'DOWN').
  final String status;

  /// Percentage of successful transactions (e.g. 98.4).
  final double successRate;

  /// Percentage of failed transactions (e.g. 1.6).
  final double failureRate;

  /// Round-trip authorization latency in milliseconds (e.g. 240).
  final int latency;

  /// Timestamp of latest telemetry sample.
  final DateTime lastUpdatedAt;

  /// Creates a [BankHealth] instance from Firestore document snapshot.
  factory BankHealth.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return BankHealth.fromMap(data, doc.id);
  }

  /// Creates a [BankHealth] instance from raw Map and document ID.
  factory BankHealth.fromMap(Map<String, dynamic> data, String id) {
    return BankHealth(
      id: id,
      merchantId: data['merchantId'] as String?,
      bankName: data['bankName'] as String? ?? '',
      status: data['status'] as String? ?? 'OPTIMAL',
      successRate: (data['successRate'] as num?)?.toDouble() ?? 100.0,
      failureRate: (data['failureRate'] as num?)?.toDouble() ?? 0.0,
      latency: (data['latency'] as num?)?.toInt() ?? 0,
      lastUpdatedAt: (data['lastUpdatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Serializes telemetry metrics into Firestore compatible Map.
  Map<String, dynamic> toFirestore() {
    return {
      'merchantId': merchantId,
      'bankName': bankName,
      'status': status,
      'successRate': successRate,
      'failureRate': failureRate,
      'latency': latency,
      'lastUpdatedAt': Timestamp.fromDate(lastUpdatedAt),
    };
  }

  /// Returns a modified copy of this bank health record.
  BankHealth copyWith({
    String? id,
    String? merchantId,
    String? bankName,
    String? status,
    double? successRate,
    double? failureRate,
    int? latency,
    DateTime? lastUpdatedAt,
  }) {
    return BankHealth(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      bankName: bankName ?? this.bankName,
      status: status ?? this.status,
      successRate: successRate ?? this.successRate,
      failureRate: failureRate ?? this.failureRate,
      latency: latency ?? this.latency,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }
}
