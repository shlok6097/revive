import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an authenticated merchant organization in the Revive ecosystem.
///
/// The [id] directly corresponds to the Firebase Authentication UID.
class Merchant {
  const Merchant({
    required this.id,
    required this.name,
    required this.email,
    this.razorpayAccountId,
    this.autonomyMode = 'SEMI_AUTONOMOUS',
    required this.createdAt,
  });

  /// The unique merchant identifier, mapped 1:1 with Firebase Auth UID.
  final String id;

  /// Merchant or business display name.
  final String name;

  /// Registered merchant primary email address.
  final String email;

  /// Optional connected Razorpay Account ID (e.g. 'acc_xxxxxxxxxxxxxx').
  final String? razorpayAccountId;

  /// Current REVIVE recovery autonomy policy ('MANUAL', 'SEMI_AUTONOMOUS', 'FULL_AUTONOMOUS').
  final String autonomyMode;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Creates a [Merchant] instance from Firestore document snapshot.
  factory Merchant.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Merchant.fromMap(data, doc.id);
  }

  /// Creates a [Merchant] instance from a Map and document ID.
  factory Merchant.fromMap(Map<String, dynamic> data, String id) {
    return Merchant(
      id: id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      razorpayAccountId: data['razorpayAccountId'] as String?,
      autonomyMode: data['autonomyMode'] as String? ?? 'SEMI_AUTONOMOUS',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Converts the merchant instance to Firestore document data.
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'razorpayAccountId': razorpayAccountId,
      'autonomyMode': autonomyMode,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Returns a modified copy of this merchant profile.
  Merchant copyWith({
    String? id,
    String? name,
    String? email,
    String? razorpayAccountId,
    String? autonomyMode,
    DateTime? createdAt,
  }) {
    return Merchant(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      razorpayAccountId: razorpayAccountId ?? this.razorpayAccountId,
      autonomyMode: autonomyMode ?? this.autonomyMode,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
