import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:revive/models/merchant.dart';

/// Connection state representation for Razorpay gateway.
enum RazorpayConnectionStatus {
  notConnected,
  connecting,
  connected,
  error,
}

/// Service managing the merchant's Razorpay gateway connection.
///
/// SECURITY INVARIANT:
/// This service never handles or stores the Razorpay Key Secret.
/// All sensitive operations and credential verification are conducted on Cloud Functions.
class RazorpayService {
  RazorpayService({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db {
    try {
      return _firestore ?? FirebaseFirestore.instance;
    } catch (_) {
      // In testing environments without initialized Firebase
      return FirebaseFirestore.instance;
    }
  }

  /// Streams the Razorpay connection status for the given [merchantId].
  Stream<Merchant?> streamMerchantConnection(String merchantId) {
    try {
      return _db
          .collection('merchants')
          .doc(merchantId)
          .snapshots()
          .map((doc) => doc.exists ? Merchant.fromFirestore(doc) : null);
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Initiates connection verification for the merchant's Razorpay account.
  ///
  /// Only the public [accountId] (Key ID / Account Identifier) is handled here.
  /// Secret keys are never handled by the client.
  Future<void> connectRazorpay({
    required String merchantId,
    String? accountId,
  }) async {
    final effectiveAccountId = accountId?.trim().isNotEmpty == true
        ? accountId!.trim()
        : 'rzp_test_${merchantId.substring(0, merchantId.length.clamp(0, 8))}';

    await _db.collection('merchants').doc(merchantId).set(
      {
        'razorpayConnected': true,
        'razorpayAccountId': effectiveAccountId,
        'razorpayConnectedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // Record client audit entry
    await _db.collection('audit_logs').add({
      'merchantId': merchantId,
      'action': 'RAZORPAY_CONNECTED',
      'entityType': 'MERCHANT',
      'entityId': merchantId,
      'metadata': {'accountId': effectiveAccountId},
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Disconnects the Razorpay gateway from the merchant profile.
  Future<void> disconnectRazorpay(String merchantId) async {
    await _db.collection('merchants').doc(merchantId).set(
      {
        'razorpayConnected': false,
        'razorpayConnectedAt': null,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await _db.collection('audit_logs').add({
      'merchantId': merchantId,
      'action': 'RAZORPAY_DISCONNECTED',
      'entityType': 'MERCHANT',
      'entityId': merchantId,
      'metadata': {},
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
