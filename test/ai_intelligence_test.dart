import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revive/models/ai_decision.dart';
import 'package:revive/models/transaction.dart';
import 'package:revive/services/ai_service.dart';
import 'package:revive/services/recovery_policy_service.dart';
import 'package:revive/widgets/ai_intelligence_card.dart';

void main() {
  group('Phase 5 — REVIVE AI Failure Intelligence Tests', () {
    final localLLM = LocalLLMService();
    const policyService = RecoveryPolicyService();

    test('Test 1 — Bank decline classification', () {
      final tx = TransactionModel(
        id: 'tx_fail_01',
        merchantId: 'merchant_123',
        amount: 2499.0,
        currency: 'INR',
        status: 'FAILED',
        paymentMethod: 'UPI',
        bank: 'HDFC',
        errorCode: 'BAD_REQUEST_ERROR',
        errorReason: 'Bank declined transaction',
        errorSource: 'bank',
        errorStep: 'payment_authorization',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = MockAIService().classifyPaymentFailure(transaction: tx);
      expect(result, completion(predicate<AIDecisionResult>((r) {
        return r.failureCategory == 'BANK_DECLINE';
      })));
    });

    test('Test 2 — Insufficient funds classification', () {
      final tx = TransactionModel(
        id: 'tx_fail_02',
        merchantId: 'merchant_123',
        amount: 5000.0,
        currency: 'INR',
        status: 'FAILED',
        paymentMethod: 'UPI',
        bank: 'ICICI',
        errorCode: 'INSUFFICIENT_FUNDS',
        errorReason: 'Customer account has insufficient funds',
        errorSource: 'bank_account',
        errorStep: 'payment_authorization',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = MockAIService().classifyPaymentFailure(transaction: tx);
      expect(result, completion(predicate<AIDecisionResult>((r) {
        return r.failureCategory == 'INSUFFICIENT_FUNDS';
      })));
    });

    test('Test 3 — Network error classification', () {
      final tx = TransactionModel(
        id: 'tx_fail_03',
        merchantId: 'merchant_123',
        amount: 1500.0,
        currency: 'INR',
        status: 'FAILED',
        paymentMethod: 'NETBANKING',
        bank: 'SBI',
        errorCode: 'GATEWAY_TIMEOUT',
        errorReason: 'Gateway timeout contacting issuing bank network',
        errorSource: 'gateway',
        errorStep: 'payment_authorization',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = MockAIService().classifyPaymentFailure(transaction: tx);
      expect(result, completion(predicate<AIDecisionResult>((r) {
        return r.failureCategory == 'NETWORK_ERROR';
      })));
    });

    test('Test 4 — Invalid details classification', () {
      final tx = TransactionModel(
        id: 'tx_fail_04',
        merchantId: 'merchant_123',
        amount: 3200.0,
        currency: 'INR',
        status: 'FAILED',
        paymentMethod: 'CARD',
        bank: 'AXIS',
        errorCode: 'INVALID_EXPIRY',
        errorReason: 'Invalid card details or expired credentials',
        errorSource: 'card_network',
        errorStep: 'card_validation',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = MockAIService().classifyPaymentFailure(transaction: tx);
      expect(result, completion(predicate<AIDecisionResult>((r) {
        return r.failureCategory == 'INVALID_DETAILS';
      })));
    });

    test('Test 5 — Malformed AI response safely falls back without crash', () {
      const malformed = 'Not a JSON at all! { broken ...';
      final parsed = localLLM.sanitizeAndParse(malformed);

      expect(parsed.failureCategory, 'UNKNOWN');
      expect(parsed.recommendedStrategy, 'ESCALATE');
      expect(parsed.isFallback, true);
    });

    test('Test 6 — Markdown-wrapped JSON is extracted and parsed properly', () {
      const wrapped = '```json\n{\n  "failureCategory": "BANK_DECLINE",\n  "recommendedStrategy": "ESCALATE"\n}\n```';
      final parsed = localLLM.sanitizeAndParse(wrapped);

      expect(parsed.failureCategory, 'BANK_DECLINE');
      expect(parsed.recommendedStrategy, 'ESCALATE');
      expect(parsed.isFallback, false);
    });

    test('Test 7 — Invalid enum values are rejected with fallback', () {
      const invalidEnums = '{\n  "failureCategory": "SOMETHING_RANDOM",\n  "recommendedStrategy": "DO_MAGIC"\n}';
      final parsed = localLLM.sanitizeAndParse(invalidEnums);

      expect(parsed.failureCategory, 'UNKNOWN');
      expect(parsed.recommendedStrategy, 'ESCALATE');
      expect(parsed.isFallback, true);
    });

    test('Test 8 — Deterministic policy validation guardrails', () {
      // Fraud risk is always blocked
      final fraudEval = policyService.evaluate(
        failureCategory: 'FRAUD_RISK',
        recommendedStrategy: 'RETRY',
      );
      expect(fraudEval.policyStatus, 'BLOCKED');
      expect(fraudEval.isBlocked, true);

      // Invalid details immediate retry is blocked
      final invalidEval = policyService.evaluate(
        failureCategory: 'INVALID_DETAILS',
        recommendedStrategy: 'RETRY',
      );
      expect(invalidEval.policyStatus, 'BLOCKED');

      // Network transient error retry is allowed
      final networkEval = policyService.evaluate(
        failureCategory: 'NETWORK_ERROR',
        recommendedStrategy: 'RETRY',
      );
      expect(networkEval.policyStatus, 'ALLOWED');
      expect(networkEval.isAllowed, true);

      // Bank decline direct retry requires review
      final declineEval = policyService.evaluate(
        failureCategory: 'BANK_DECLINE',
        recommendedStrategy: 'RETRY',
      );
      expect(declineEval.policyStatus, 'REQUIRES_REVIEW');
      expect(declineEval.requiresReview, true);
    });

    test('Test 9 — AIDecision model serialization and Firestore invariants', () {
      final now = DateTime.now();
      final decision = AIDecision(
        id: 'dec_tx_123',
        merchantId: 'merchant_99',
        transactionId: 'tx_123',
        failureCategory: 'BANK_DECLINE',
        recommendedStrategy: 'ESCALATE',
        modelName: 'Phi-3-mini-4k-instruct-q4',
        modelVersion: 'v1.0',
        promptVersion: 'revive-payment-classifier-v1',
        reasoning: 'Issuing bank decline requiring manual review.',
        policyStatus: 'REQUIRES_REVIEW',
        createdAt: DateTime(2026, 9, 3),
      );

      final map = decision.toFirestore();
      expect(map['merchantId'], 'merchant_99');
      expect(map['transactionId'], 'tx_123');
      expect(map['failureCategory'], 'BANK_DECLINE');
      expect(map['recommendedStrategy'], 'ESCALATE');
      expect(map['confidence'], isNull);
      expect(map['modelName'], 'Phi-3-mini-4k-instruct-q4');
      expect(map['policyStatus'], 'REQUIRES_REVIEW');
      expect(map['createdAt'], isA<Timestamp>());

      final reconstructed = AIDecision.fromMap(map, 'dec_tx_123');
      expect(reconstructed.id, 'dec_tx_123');
      expect(reconstructed.failureCategory, 'BANK_DECLINE');
      expect(reconstructed.recommendedStrategy, 'ESCALATE');
      expect(reconstructed.policyStatus, 'REQUIRES_REVIEW');
    });

    testWidgets('Test 10 — AIIntelligenceCard renders insights and policy badge', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AIIntelligenceCard(
              aiDecision: AIDecision(
                id: 'dec_test_01',
                merchantId: 'merchant_test',
                transactionId: 'tx_test_01',
                failureCategory: 'BANK_DECLINE',
                recommendedStrategy: 'ESCALATE',
                modelName: 'Phi-3 Mini',
                policyStatus: 'REQUIRES_REVIEW',
                createdAt: DateTime.now(),
              ),
            ),
          ),
        ),
      );

      expect(find.text('AI PAYMENT ANALYSIS'), findsOneWidget);
      expect(find.text('AI ANALYZED'), findsOneWidget);
      expect(find.text('BANK DECLINE'), findsOneWidget);
      expect(find.text('ESCALATE'), findsOneWidget);
      expect(find.text('REQUIRES REVIEW'), findsOneWidget);
      expect(find.textContaining('AI Recommendation — Human/Policy Validation Required'), findsOneWidget);
    });
  });
}
