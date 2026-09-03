import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction.dart';

/// Repository for reading and managing transactions from Firestore.
///
/// INVARIANT:
/// All queries are strictly scoped by [merchantId] (Firebase Auth UID).
class TransactionRepository {
  TransactionRepository({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db {
    try {
      return _firestore ?? FirebaseFirestore.instance;
    } catch (_) {
      return FirebaseFirestore.instance;
    }
  }

  /// Fetches a single transaction by [transactionId] scoped to [merchantId].
  Future<TransactionModel?> getTransaction(
    String transactionId,
    String merchantId,
  ) async {
    try {
      final doc = await _db.collection('transactions').doc(transactionId).get();
      if (!doc.exists || doc.data() == null) return null;

      final data = doc.data()!;
      // Security check: ensure transaction belongs to merchant
      if (data['merchantId'] != merchantId) return null;

      return TransactionModel.fromFirestore(doc);
    } catch (_) {
      return null;
    }
  }

  /// Persists or updates a transaction document in Firestore.
  Future<void> saveTransaction(TransactionModel tx) async {
    await _db
        .collection('transactions')
        .doc(tx.id)
        .set(tx.toFirestore(), SetOptions(merge: true));
  }

  /// Streams transactions for the specified [merchantId] in reverse chronological order.
  Stream<List<TransactionModel>> streamTransactions(
    String merchantId, {
    int limit = 50,
  }) {
    try {
      return _db
          .collection('transactions')
          .where('merchantId', isEqualTo: merchantId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => TransactionModel.fromFirestore(doc))
              .toList());
    } catch (_) {
      return const Stream.empty();
    }
  }
}
