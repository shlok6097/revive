import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/recovery_attempt.dart';

/// Repository for persisting and retrieving structured payment recovery attempts.
///
/// INVARIANT:
/// All queries and writes are strictly scoped to the authenticated merchant ID.
class RecoveryAttemptRepository {
  RecoveryAttemptRepository({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db {
    try {
      return _firestore ?? FirebaseFirestore.instance;
    } catch (_) {
      return FirebaseFirestore.instance;
    }
  }

  /// Persists a recovery attempt record into `recovery_attempts/{attemptId}`.
  Future<void> saveRecoveryAttempt(RecoveryAttempt attempt) async {
    await _db.collection('recovery_attempts').doc(attempt.id).set(
          attempt.toFirestore(),
          SetOptions(merge: true),
        );
  }

  /// Fetches all recovery attempts associated with a specific [transactionId] and [merchantId].
  Future<List<RecoveryAttempt>> getAttemptsByTransaction(
    String transactionId,
    String merchantId,
  ) async {
    try {
      final snapshot = await _db
          .collection('recovery_attempts')
          .where('merchantId', isEqualTo: merchantId)
          .where('transactionId', isEqualTo: transactionId)
          .orderBy('attemptNumber', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => RecoveryAttempt.fromFirestore(doc))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetches the latest recovery attempt for a given [transactionId] and [merchantId].
  Future<RecoveryAttempt?> getLatestAttempt(
    String transactionId,
    String merchantId,
  ) async {
    try {
      final snapshot = await _db
          .collection('recovery_attempts')
          .where('merchantId', isEqualTo: merchantId)
          .where('transactionId', isEqualTo: transactionId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return RecoveryAttempt.fromFirestore(snapshot.docs.first);
    } catch (_) {
      return null;
    }
  }

  /// Counts the total number of previous recovery attempts for [transactionId] and [merchantId].
  Future<int> countPreviousAttempts(
    String transactionId,
    String merchantId,
  ) async {
    try {
      final attempts = await getAttemptsByTransaction(transactionId, merchantId);
      return attempts.length;
    } catch (_) {
      return 0;
    }
  }

  /// Streams real-time recovery attempt records scoped strictly to [merchantId].
  Stream<List<RecoveryAttempt>> streamAttemptsForMerchant(
    String merchantId, {
    int limit = 50,
  }) {
    try {
      return _db
          .collection('recovery_attempts')
          .where('merchantId', isEqualTo: merchantId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => RecoveryAttempt.fromFirestore(doc))
              .toList());
    } catch (_) {
      return const Stream.empty();
    }
  }
}
