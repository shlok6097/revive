import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/merchant_policy.dart';

/// Repository for persisting and retrieving merchant recovery configuration policies.
///
/// INVARIANT:
/// Policies are merchant-isolated at path `merchant_policies/{merchantId}`.
class MerchantPolicyRepository {
  MerchantPolicyRepository({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db {
    try {
      return _firestore ?? FirebaseFirestore.instance;
    } catch (_) {
      return FirebaseFirestore.instance;
    }
  }

  /// Default safe policy for any newly registered or unconfigured merchant.
  static MerchantPolicy defaultPolicy(String merchantId) {
    final now = DateTime.now();
    return MerchantPolicy(
      id: merchantId,
      merchantId: merchantId,
      autonomyMode: 'MANUAL',
      automaticRetryEnabled: false,
      maxAutomaticRetries: 1,
      allowNetworkRetry: true,
      allowBankDeclineRetry: true,
      allowAlternativeMethod: true,
      requireReviewForBankDecline: false,
      requireReviewForAuthenticationFailure: true,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Fetches the configured [MerchantPolicy] for [merchantId], or returns a default safe policy.
  Future<MerchantPolicy> getPolicy(String merchantId) async {
    try {
      final doc = await _db.collection('merchant_policies').doc(merchantId).get();
      if (!doc.exists || doc.data() == null) {
        return defaultPolicy(merchantId);
      }
      return MerchantPolicy.fromFirestore(doc);
    } catch (_) {
      return defaultPolicy(merchantId);
    }
  }

  /// Saves or updates the merchant's policy in `merchant_policies/{merchantId}`.
  Future<void> savePolicy(MerchantPolicy policy) async {
    await _db
        .collection('merchant_policies')
        .doc(policy.merchantId)
        .set(policy.toFirestore(), SetOptions(merge: true));
  }

  /// Streams the real-time [MerchantPolicy] for [merchantId].
  Stream<MerchantPolicy> streamPolicy(String merchantId) {
    try {
      return _db
          .collection('merchant_policies')
          .doc(merchantId)
          .snapshots()
          .map((doc) {
        if (!doc.exists || doc.data() == null) {
          return defaultPolicy(merchantId);
        }
        return MerchantPolicy.fromFirestore(doc);
      });
    } catch (_) {
      return Stream.value(defaultPolicy(merchantId));
    }
  }
}
