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
        autonomyMode: 'SEMI_AUTONOMOUS',
        createdAt: now,
      );

      final map = merchant.toFirestore();
      expect(map['name'], 'Acme Payments');
      expect(map['email'], 'merchant@acme.com');
      expect(map['razorpayAccountId'], 'acc_rzp_9900');
      expect(map['autonomyMode'], 'SEMI_AUTONOMOUS');
      expect(map['createdAt'], isA<Timestamp>());

      final reconstructed = Merchant.fromMap(map, 'usr_auth_uid_123');
      expect(reconstructed.id, 'usr_auth_uid_123');
      expect(reconstructed.name, merchant.name);
      expect(reconstructed.email, merchant.email);
      expect(reconstructed.razorpayAccountId, merchant.razorpayAccountId);
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
        strategy: 'DYNAMIC_FALLBACK_UPI',
        status: 'INITIATED',
        reason: 'Fallback to UPI intent due to Netbanking timeout',
        createdAt: now,
        updatedAt: now,
      );

      final map = attempt.toFirestore();
      expect(map['strategy'], 'DYNAMIC_FALLBACK_UPI');
      expect(map['status'], 'INITIATED');

      final reconstructed = RecoveryAttempt.fromMap(map, 'rec_001');
      expect(reconstructed.transactionId, 'tx_rv_7711');
      expect(reconstructed.strategy, 'DYNAMIC_FALLBACK_UPI');
    });

    test('AIDecision serialization', () {
      final now = DateTime.now();
      final decision = AIDecision(
        id: 'ai_001',
        merchantId: 'usr_auth_uid_123',
        transactionId: 'tx_rv_7711',
        decision: 'RETRY_VIA_SECONDARY_GATEWAY',
        confidence: 0.94,
        reason: 'HDFC gateway benchmark demonstrates 99.2% success rate',
        createdAt: now,
      );

      final map = decision.toFirestore();
      expect(map['confidence'], 0.94);
      expect(map['decision'], 'RETRY_VIA_SECONDARY_GATEWAY');

      final reconstructed = AIDecision.fromMap(map, 'ai_001');
      expect(reconstructed.confidence, 0.94);
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
        autonomyMode: 'FULL_AUTONOMOUS',
        maxRecoveryAttempts: 4,
        allowedStrategies: ['SMART_ROUTING_RETRY', 'DYNAMIC_FALLBACK_UPI'],
        createdAt: now,
        updatedAt: now,
      );

      final map = policy.toFirestore();
      expect(map['maxRecoveryAttempts'], 4);
      expect(map['allowedStrategies'], hasLength(2));

      final reconstructed = MerchantPolicy.fromMap(map, 'pol_001');
      expect(reconstructed.autonomyMode, 'FULL_AUTONOMOUS');
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
