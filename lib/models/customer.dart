import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a customer associated with merchant transactions in Revive.
class Customer {
  const Customer({
    required this.id,
    required this.merchantId,
    required this.name,
    required this.email,
    required this.phone,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Unique customer identifier.
  final String id;

  /// Associated Merchant ID (Firebase Auth UID).
  final String merchantId;

  /// Customer full name.
  final String name;

  /// Customer primary email address.
  final String email;

  /// Contact phone number.
  final String phone;

  /// Account creation timestamp.
  final DateTime createdAt;

  /// Last modification timestamp.
  final DateTime updatedAt;

  /// Creates a [Customer] instance from Firestore document snapshot.
  factory Customer.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Customer.fromMap(data, doc.id);
  }

  /// Creates a [Customer] instance from raw Map and document ID.
  factory Customer.fromMap(Map<String, dynamic> data, String id) {
    return Customer(
      id: id,
      merchantId: data['merchantId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Serializes customer into Firestore compatible Map.
  Map<String, dynamic> toFirestore() {
    return {
      'merchantId': merchantId,
      'name': name,
      'email': email,
      'phone': phone,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Returns a modified copy of this customer.
  Customer copyWith({
    String? id,
    String? merchantId,
    String? name,
    String? email,
    String? phone,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Customer(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
