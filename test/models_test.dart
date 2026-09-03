import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revive/models/ai_decision.dart';
import 'package:revive/models/audit_log.dart';
import 'package:revive/models/bank_health.dart';
import 'package:revive/models/customer.dart';
import 'package:revive/models/merchant.dart';
import 'package:revive/models/merchant_policy.dart';
import 'package:revive/models/recovery_attempt.dart';
import 'package:revive/models/transaction.dart';

void main() {
  group('Firestore Models Serialization & Invariants', () {
    test('Merchant serialization and UID identity', () {
      final now = DateTime.now();
      final merchant = Merchant(
        id: 'usr_auth_uid_123',
        name: 'Acme Payments',
        email: 'merchant@acme.com',
        razorpayAccountId: 'acc_rzp_9900',
        razorpayConnected: true,
        razorpayConnectedAt: now,
        autonomyMode: 'SEMI_AUTONOMOUS',
        createdAt: now,
      );

      final map = merchant.toFirestore();
      expect(map['name'], 'Acme Payments');
      expect(map['email'], 'merchant@acme.com');
      expect(map['razorpayAccountId'], 'acc_rzp_9900');
      expect(map['razorpayConnected'], true);
      expect(map['razorpayConnectedAt'], isA<Timestamp>());
      expect(map['autonomyMode'], 'SEMI_AUTONOMOUS');
      expect(map['createdAt'], isA<Timestamp>());

      final reconstructed = Merchant.fromMap(map, 'usr_auth_uid_123');
      expect(reconstructed.id, 'usr_auth_uid_123');
      expect(reconstructed.name, merchant.name);
      expect(reconstructed.email, merchant.email);
      expect(reconstructed.razorpayAccountId, merchant.razorpayAccountId);
      expect(reconstructed.razorpayConnected, true);
      expect(reconstructed.autonomyMode, merchant.autonomyMode);
    });

    test('TransactionModel serialization preserves structured failure taxonomy', () {
      final now = DateTime.now();
      final tx = TransactionModel(
        id: 'tx_rv_7711',
        merchantId: 'usr_auth_uid_123',
        amount: 8500.50,
        currency: 'INR',
        status: 'FAILED',
        paymentMethod: 'NETBANKING',
        bank: 'SBI',
        errorCode: 'GATEWAY_DEGRADED_DOWN',
        errorReason: 'Core banking switch timed out during MPIN validation',
        errorSource: 'BANK_GATEWAY',
        errorStep: 'OTP_VERIFICATION',
        customerId: 'cust_001',
        createdAt: now,
        updatedAt: now,
      );

      final map = tx.toFirestore();
      expect(map['merchantId'], 'usr_auth_uid_123');
      expect(map['amount'], 8500.50);
      expect(map['errorCode'], 'GATEWAY_DEGRADED_DOWN');
      expect(map['errorSource'], 'BANK_GATEWAY');
      expect(map['errorStep'], 'OTP_VERIFICATION');

      final reconstructed = TransactionModel.fromMap(map, 'tx_rv_7711');
      expect(reconstructed.id, 'tx_rv_7711');
      expect(reconstructed.errorCode, 'GATEWAY_DEGRADED_DOWN');
      expect(reconstructed.errorSource, 'BANK_GATEWAY');
      expect(reconstructed.errorStep, 'OTP_VERIFICATION');
    });

    test('Customer serialization', () {
      final now = DateTime.now();
      final customer = Customer(
        id: 'cust_001',
        merchantId: 'usr_auth_uid_123',
        name: 'Rahul Sharma',
        email: 'rahul@example.com',
        phone: '+919876543210',
        createdAt: now,
        updatedAt: now,
      );

      final map = customer.toFirestore();
      expect(map['merchantId'], 'usr_auth_uid_123');
      expect(map['phone'], '+919876543210');

      final reconstructed = Customer.fromMap(map, 'cust_001');
      expect(reconstructed.id, 'cust_001');
      expect(reconstructed.email, 'rahul@example.com');
    });

    test('RecoveryAttempt serialization', () {
      final now = DateTime.now();
      final attempt = RecoveryAttempt(
        id: 'rec_001',
        merchantId: 'usr_auth_uid_123',
        transactionId: 'tx_rv_7711',
        strategy: 'ALTERNATIVE_METHOD',
        status: 'PLANNED',
        reason: 'Fallback to UPI intent due to Netbanking timeout',
        createdAt: now,
        updatedAt: now,
      );

      final map = attempt.toFirestore();
      expect(map['strategy'], 'ALTERNATIVE_METHOD');
      expect(map['status'], 'PLANNED');

      final reconstructed = RecoveryAttempt.fromMap(map, 'rec_001');
      expect(reconstructed.transactionId, 'tx_rv_7711');
      expect(reconstructed.strategy, 'ALTERNATIVE_METHOD');
      expect(reconstructed.status, 'PLANNED');
    });

    test('AIDecision serialization', () {
      final now = DateTime.now();
      final decision = AIDecision(
        id: 'ai_001',
        merchantId: 'usr_auth_uid_123',
        transactionId: 'tx_rv_7711',
        failureCategory: 'BANK_DECLINE',
        recommendedStrategy: 'RETRY',
        confidence: 0.94,
        reasoning: 'HDFC gateway benchmark demonstrates 99.2% success rate',
        policyStatus: 'REQUIRES_REVIEW',
        createdAt: now,
      );

      final map = decision.toFirestore();
      expect(map['confidence'], 0.94);
      expect(map['failureCategory'], 'BANK_DECLINE');
      expect(map['recommendedStrategy'], 'RETRY');
      expect(map['policyStatus'], 'REQUIRES_REVIEW');

      final reconstructed = AIDecision.fromMap(map, 'ai_001');
      expect(reconstructed.confidence, 0.94);
      expect(reconstructed.failureCategory, 'BANK_DECLINE');
      expect(reconstructed.recommendedStrategy, 'RETRY');
      expect(reconstructed.policyStatus, 'REQUIRES_REVIEW');
    });

    test('BankHealth serialization', () {
      final now = DateTime.now();
      final bh = BankHealth(
        id: 'bh_hdfc',
        bankName: 'HDFC Bank',
        status: 'OPTIMAL',
        successRate: 99.1,
        failureRate: 0.9,
        latency: 185,
        lastUpdatedAt: now,
      );

      final map = bh.toFirestore();
      expect(map['successRate'], 99.1);
      expect(map['latency'], 185);

      final reconstructed = BankHealth.fromMap(map, 'bh_hdfc');
      expect(reconstructed.bankName, 'HDFC Bank');
    });

    test('MerchantPolicy serialization', () {
      final now = DateTime.now();
      final policy = MerchantPolicy(
        id: 'pol_001',
        merchantId: 'usr_auth_uid_123',
        autonomyMode: 'AUTONOMOUS',
        maxAutomaticRetries: 4,
        allowedStrategies: ['RETRY', 'ALTERNATIVE_METHOD'],
        createdAt: now,
        updatedAt: now,
      );

      final map = policy.toFirestore();
      expect(map['maxAutomaticRetries'], 4);
      expect(map['allowedStrategies'], hasLength(2));

      final reconstructed = MerchantPolicy.fromMap(map, 'pol_001');
      expect(reconstructed.autonomyMode, 'AUTONOMOUS');
      expect(reconstructed.maxAutomaticRetries, 4);
    });

    test('AuditLog serialization', () {
      final now = DateTime.now();
      final log = AuditLog(
        id: 'log_001',
        merchantId: 'usr_auth_uid_123',
        action: 'POLICY_UPDATED',
        entityType: 'POLICY',
        entityId: 'pol_001',
        metadata: {'previousMode': 'MANUAL', 'newMode': 'FULL_AUTONOMOUS'},
        createdAt: now,
      );

      final map = log.toFirestore();
      expect(map['action'], 'POLICY_UPDATED');
      expect(map['metadata']['previousMode'], 'MANUAL');

      final reconstructed = AuditLog.fromMap(map, 'log_001');
      expect(reconstructed.action, 'POLICY_UPDATED');
    });
  });
}
