import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/merchant.dart';

/// Repository for managing Merchant profile data in Cloud Firestore.
///
/// Ensures strict alignment between the Firebase Auth UID and `merchants/{merchantId}`.
class MerchantRepository {
  MerchantRepository({FirebaseFirestore? firestore}) : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _merchantsCollection =>
      _db.collection('merchants');

  /// Creates a new merchant profile document in `merchants/{merchant.id}`.
  Future<void> createMerchantProfile(Merchant merchant) async {
    try {
      await _merchantsCollection.doc(merchant.id).set(
            merchant.toFirestore(),
            SetOptions(merge: true),
          );
    } catch (e) {
      throw Exception('Failed to create merchant profile: $e');
    }
  }

  /// Retrieves the merchant profile corresponding to [merchantId].
  Future<Merchant?> getMerchantProfile(String merchantId) async {
    try {
      final doc = await _merchantsCollection.doc(merchantId).get();
      if (!doc.exists) return null;
      return Merchant.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to load merchant profile: $e');
    }
  }

  /// Updates existing merchant profile fields.
  Future<void> updateMerchantProfile(Merchant merchant) async {
    try {
      await _merchantsCollection.doc(merchant.id).update(merchant.toFirestore());
    } catch (e) {
      throw Exception('Failed to update merchant profile: $e');
    }
  }

  /// Emits real-time stream of the merchant profile.
  Stream<Merchant?> streamMerchantProfile(String merchantId) {
    return _merchantsCollection.doc(merchantId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return Merchant.fromFirestore(snapshot);
    });
  }
}
