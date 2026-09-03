import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ai_decision.dart';

/// Repository for persisting and retrieving structured AI recovery decisions.
///
/// INVARIANT:
/// All queries and writes are strictly scoped to the authenticated merchant ID.
class AIDecisionRepository {
  AIDecisionRepository({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db {
    try {
      return _firestore ?? FirebaseFirestore.instance;
    } catch (_) {
      return FirebaseFirestore.instance;
    }
  }

  /// Persists a validated AI decision into `ai_decisions/{decisionId}`.
  Future<void> saveDecision(AIDecision decision) async {
    await _db.collection('ai_decisions').doc(decision.id).set(
          decision.toFirestore(),
          SetOptions(merge: true),
        );
  }

  /// Fetches the most recent AI decision for a given [transactionId] and [merchantId].
  Future<AIDecision?> getDecisionForTransaction(
    String transactionId,
    String merchantId,
  ) async {
    try {
      final query = await _db
          .collection('ai_decisions')
          .where('merchantId', isEqualTo: merchantId)
          .where('transactionId', isEqualTo: transactionId)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;
      return AIDecision.fromFirestore(query.docs.first);
    } catch (_) {
      return null;
    }
  }

  /// Streams the latest AI decisions for the specified [merchantId].
  Stream<List<AIDecision>> streamDecisionsForMerchant(
    String merchantId, {
    int limit = 20,
  }) {
    try {
      return _db
          .collection('ai_decisions')
          .where('merchantId', isEqualTo: merchantId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) =>
              snapshot.docs.map((doc) => AIDecision.fromFirestore(doc)).toList());
    } catch (_) {
      return const Stream.empty();
    }
  }
}
