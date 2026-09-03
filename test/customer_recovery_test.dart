import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revive/features/recovery/customer_recovery_screen.dart';
import 'package:revive/models/customer.dart';
import 'package:revive/models/recovery_session.dart';
import 'package:revive/models/transaction.dart';
import 'package:revive/services/recovery_session_client.dart';

void main() {
  group('Phase 8 — Customer Recovery & Smart Recovery Links Tests', () {
    test('Test 1 — RecoverySession model serialization and status methods', () {
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(minutes: 30));

      final session = RecoverySession(
        id: 'ses_test_01',
        merchantId: 'merchant_alpha',
        transactionId: 'tx_01',
        customerId: 'cust_01',
        recoveryAttemptId: 'att_01',
        strategy: 'RETRY',
        status: 'ACTIVE',
        tokenHash: 'hash_sha256_123',
        expiresAt: expiresAt,
        createdAt: now,
        updatedAt: now,
      );

      expect(session.isActive, true);
      expect(session.isExpired, false);
      expect(session.isUsed, false);

      final map = session.toFirestore();
      expect(map['merchantId'], 'merchant_alpha');
      expect(map['tokenHash'], 'hash_sha256_123');
      expect(map['strategy'], 'RETRY');

      final reconstructed = RecoverySession.fromMap({
        'merchantId': 'merchant_alpha',
        'transactionId': 'tx_01',
        'strategy': 'RETRY',
        'status': 'ACTIVE',
        'tokenHash': 'hash_sha256_123',
      }, 'ses_test_01');

      expect(reconstructed.id, 'ses_test_01');
      expect(reconstructed.merchantId, 'merchant_alpha');
      expect(reconstructed.status, 'ACTIVE');
    });

    test('Test 2 — Customer model with externalCustomerId serialization', () {
      final now = DateTime.now();
      final customer = Customer(
        id: 'cust_01',
        merchantId: 'merchant_alpha',
        externalCustomerId: 'cust_rzp_9921',
        name: 'Aarav Sharma',
        email: 'aarav@example.com',
        phone: '+919876543210',
        createdAt: now,
        updatedAt: now,
      );

      final map = customer.toFirestore();
      expect(map['externalCustomerId'], 'cust_rzp_9921');
      expect(map['name'], 'Aarav Sharma');

      final reconstructed = Customer.fromMap(map, 'cust_01');
      expect(reconstructed.externalCustomerId, 'cust_rzp_9921');
    });

    test('Test 3 — TransactionModel with Phase 8 recovery outcome fields', () {
      final now = DateTime.now();
      final tx = TransactionModel(
        id: 'tx_rec_01',
        merchantId: 'merchant_alpha',
        amount: 2499.0,
        status: 'SUCCESS',
        paymentMethod: 'UPI',
        bank: 'HDFC',
        recoveryOutcome: 'RECOVERED',
        recoveredAt: now,
        recoverySessionId: 'ses_rec_01',
        createdAt: now,
        updatedAt: now,
      );

      expect(tx.isRecovered, true);
      final map = tx.toFirestore();
      expect(map['recoveryOutcome'], 'RECOVERED');
      expect(map['recoverySessionId'], 'ses_rec_01');
      expect(map['recoveredAt'], isNotNull);
    });

    test('Test 4 — Deterministic customer-safe messaging resolution', () {
      final validationRetry = CustomerRecoveryValidation.fromMap({
        'valid': true,
        'strategy': 'RETRY',
        'title': 'Payment could not be completed',
        'message': "We couldn't complete your payment. Please try again.",
        'actionPrompt': 'Try Payment Again',
      });
      expect(validationRetry.title, 'Payment could not be completed');
      expect(validationRetry.actionPrompt, 'Try Payment Again');

      final validationAlt = CustomerRecoveryValidation.fromMap({
        'valid': true,
        'strategy': 'ALTERNATIVE_METHOD',
        'title': 'Payment method unavailable',
        'message': "We couldn't complete your payment using this method. You can try another payment method.",
        'actionPrompt': 'Use Another Method',
      });
      expect(validationAlt.title, 'Payment method unavailable');
      expect(validationAlt.actionPrompt, 'Use Another Method');
    });

    testWidgets('Test 5 — CustomerRecoveryScreen renders active recovery session and order breakdown', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CustomerRecoveryScreen(
            sessionId: 'ses_demo',
            token: 'tok_demo',
            mockValidation: CustomerRecoveryValidation(
              valid: true,
              sessionId: 'ses_demo',
              transactionId: 'tx_demo_01',
              amount: 1499.0,
              currency: 'INR',
              paymentMethod: 'UPI',
              bank: 'HDFC',
              strategy: 'RETRY',
              title: 'Payment could not be completed',
              message: "We couldn't complete your payment. Please try again.",
              actionPrompt: 'Try Payment Again',
              allowAlternate: true,
            ),
          ),
        ),
      );

      expect(find.text('REVIVE'), findsOneWidget);
      expect(find.text('Secure Payment Recovery'), findsOneWidget);
      expect(find.text('Payment could not be completed'), findsOneWidget);
      expect(find.text("We couldn't complete your payment. Please try again."), findsOneWidget);
      expect(find.text('₹1499.00'), findsOneWidget);
      expect(find.text('Try Payment Again'), findsOneWidget);
      expect(find.text('Use Another Method'), findsOneWidget);
    });

    testWidgets('Test 6 — CustomerRecoveryScreen handles payment retry and triggers success state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CustomerRecoveryScreen(
            sessionId: 'ses_demo',
            token: 'tok_demo',
            mockValidation: CustomerRecoveryValidation(
              valid: true,
              sessionId: 'ses_demo',
              transactionId: 'tx_demo_01',
              amount: 1499.0,
              currency: 'INR',
              paymentMethod: 'UPI',
              bank: 'HDFC',
              strategy: 'RETRY',
              title: 'Payment could not be completed',
              message: "We couldn't complete your payment. Please try again.",
              actionPrompt: 'Try Payment Again',
              allowAlternate: true,
            ),
          ),
        ),
      );

      // Tap Try Payment Again
      await tester.tap(find.text('Try Payment Again'));
      await tester.pumpAndSettle();

      expect(find.text('Payment Recovered Successfully!'), findsOneWidget);
      expect(find.text('COMPLETED'), findsOneWidget);
    });

    testWidgets('Test 7 — CustomerRecoveryScreen allows picking alternative payment method', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CustomerRecoveryScreen(
            sessionId: 'ses_demo',
            token: 'tok_demo',
            mockValidation: CustomerRecoveryValidation(
              valid: true,
              sessionId: 'ses_demo',
              transactionId: 'tx_demo_01',
              amount: 2499.0,
              currency: 'INR',
              paymentMethod: 'UPI',
              bank: 'ICICI',
              strategy: 'RETRY',
              title: 'Payment could not be completed',
              message: "We couldn't complete your payment. Please try again.",
              actionPrompt: 'Try Payment Again',
              allowAlternate: true,
            ),
          ),
        ),
      );

      // Tap Use Another Method to open options
      await tester.tap(find.text('Use Another Method'));
      await tester.pumpAndSettle();

      expect(find.text('SELECT ALTERNATIVE PAYMENT METHOD'), findsOneWidget);
      expect(find.text('CARD'), findsOneWidget);
      expect(find.text('NETBANKING'), findsOneWidget);

      // Select Card
      await tester.tap(find.text('CARD'));
      await tester.pumpAndSettle();

      expect(find.text('Pay ₹2499.00 with CARD'), findsOneWidget);
    });

    testWidgets('Test 8 — CustomerRecoveryScreen displays error for expired or invalid link', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CustomerRecoveryScreen(
            sessionId: 'ses_expired',
            token: 'tok_invalid',
            mockValidation: CustomerRecoveryValidation(
              valid: false,
              status: 'EXPIRED',
              error: 'This recovery link has expired for your security.',
            ),
          ),
        ),
      );

      expect(find.text('Recovery Link Expired or Invalid'), findsOneWidget);
      expect(find.text('This recovery link has expired for your security.'), findsOneWidget);
    });
  });
}
