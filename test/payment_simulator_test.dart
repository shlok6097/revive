import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revive/features/recovery/customer_recovery_screen.dart';
import 'package:revive/features/simulator/recovery_simulator_screen.dart';
import 'package:revive/models/simulation_scenario.dart';
import 'package:revive/services/ai_service.dart';
import 'package:revive/services/payment_simulator_service.dart';
import 'package:revive/services/recovery_session_client.dart';
import 'package:revive/services/recovery_strategy_service.dart';

void main() {
  group('Phase 9 — REVIVE Recovery Simulator & Demo Engine Tests', () {
    test('Test 1 — SimulationScenario catalog contains all 7 required failure presets', () {
      expect(SimulationScenario.presets.length, 7);

      final bankDecline = SimulationScenario.findById('BANK_DECLINE');
      expect(bankDecline.title, 'Bank Decline');
      expect(bankDecline.bank, 'HDFC');
      expect(bankDecline.errorCode, 'BAD_REQUEST_ERROR');
      expect(bankDecline.expectedStrategy, 'RETRY');

      final netTimeout = SimulationScenario.findById('NETWORK_ERROR');
      expect(netTimeout.title, 'Network Timeout');
      expect(netTimeout.bank, 'ICICI');
      expect(netTimeout.errorCode, 'GATEWAY_TIMEOUT');

      final fraudRisk = SimulationScenario.findById('FRAUD_RISK');
      expect(fraudRisk.title, 'Fraud Risk Filter');
      expect(fraudRisk.expectedPolicyStatus, 'BLOCKED');

      final unknown = SimulationScenario.findById('UNKNOWN');
      expect(unknown.title, 'Unknown Anomaly');
      expect(unknown.expectedStrategy, 'ESCALATE');
    });

    test('Test 2 — PaymentSimulatorService runs full pipeline for BANK_DECLINE scenario', () async {
      final simulatorService = PaymentSimulatorService(
        aiService: MockAIService(),
        strategyService: RecoveryStrategyService(),
        sessionClient: RecoverySessionClient(),
      );

      final stepsRecorded = <String>[];
      final result = await simulatorService.runSimulationPipeline(
        merchantId: 'merchant_alpha',
        scenario: SimulationScenario.findById('BANK_DECLINE'),
        onStep: (step) => stepsRecorded.add(step),
      );

      expect(result.transaction.simulated, true);
      expect(result.transaction.status, 'FAILED');
      expect(result.transaction.bank, 'HDFC');
      expect(result.aiDecision.category, 'BANK_DECLINE');
      expect(result.recoveryDecision.strategy, isNotEmpty);
      expect(result.durationMs, greaterThan(0));
      expect(stepsRecorded.length, greaterThanOrEqualTo(5));
    });

    test('Test 3 — PaymentSimulatorService enforces policy block on FRAUD_RISK scenario', () async {
      final simulatorService = PaymentSimulatorService(
        aiService: MockAIService(),
        strategyService: RecoveryStrategyService(),
        sessionClient: RecoverySessionClient(),
      );

      final result = await simulatorService.runSimulationPipeline(
        merchantId: 'merchant_alpha',
        scenario: SimulationScenario.findById('FRAUD_RISK'),
      );

      expect(result.transaction.simulated, true);
      expect(result.aiDecision.category, 'FRAUD_RISK');
      expect(result.recoveryDecision.isBlocked, true);
      expect(result.recoveryDecision.policyStatus, 'BLOCKED');
      expect(result.recoverySessionId, isNull);
      expect(result.finalStatus, 'BLOCKED');
    });

    test('Test 4 — PaymentSimulatorService handles UNKNOWN anomaly with ESCALATE strategy', () async {
      final simulatorService = PaymentSimulatorService(
        aiService: MockAIService(),
        strategyService: RecoveryStrategyService(),
        sessionClient: RecoverySessionClient(),
      );

      final result = await simulatorService.runSimulationPipeline(
        merchantId: 'merchant_alpha',
        scenario: SimulationScenario.findById('UNKNOWN'),
      );

      expect(result.transaction.simulated, true);
      expect(result.recoveryDecision.strategy, 'ESCALATE');
      expect(result.recoveryDecision.policyStatus, 'REQUIRES_REVIEW');
    });

    testWidgets('Test 5 — RecoverySimulatorScreen renders scenario presets and controls', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: RecoverySimulatorScreen(),
        ),
      );

      expect(find.text('REVIVE SIMULATOR'), findsOneWidget);
      expect(find.text('Payment Failure & Autonomous Recovery Simulator'), findsOneWidget);
      expect(find.text('Phi-3 Mini Local Active'), findsOneWidget);
      expect(find.text('1. CHOOSE FAILURE SCENARIO'), findsOneWidget);
      expect(find.text('Bank Decline'), findsOneWidget);
      expect(find.text('Network Timeout'), findsOneWidget);
      expect(find.text('Fraud Risk Filter'), findsOneWidget);
      expect(find.text('RUN SIMULATION'), findsOneWidget);
      expect(find.text('Select a scenario and click RUN SIMULATION'), findsOneWidget);
    });

    testWidgets('Test 6 — RecoverySimulatorScreen switches scenario on tap', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: RecoverySimulatorScreen(),
        ),
      );

      // Tap on Network Timeout scenario
      await tester.tap(find.text('Network Timeout'));
      await tester.pumpAndSettle();

      expect(find.text('₹850 • UPI'), findsOneWidget);
    });

    testWidgets('Test 7 — RecoverySimulatorScreen runs simulation and renders diagnostic panels', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final simulatorService = PaymentSimulatorService(
        aiService: MockAIService(),
        strategyService: RecoveryStrategyService(),
        sessionClient: RecoverySessionClient(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RecoverySimulatorScreen(
            simulatorService: simulatorService,
          ),
        ),
      );

      // Scroll and Tap RUN SIMULATION
      await tester.ensureVisible(find.text('RUN SIMULATION'));
      await tester.tap(find.text('RUN SIMULATION'));
      await tester.pumpAndSettle();

      // Verify diagnostics rendered
      await tester.ensureVisible(find.text('AI FAILURE INTELLIGENCE'));
      expect(find.text('AI FAILURE INTELLIGENCE'), findsOneWidget);
      expect(find.text('Phi-3 Mini'), findsOneWidget);
      expect(find.text('GOVERNED RECOVERY STRATEGY'), findsOneWidget);
      expect(find.text('CUSTOMER RECOVERY LINK'), findsOneWidget);
      expect(find.text('OPEN CUSTOMER RECOVERY'), findsOneWidget);
      expect(find.text('SIMULATION SUMMARY'), findsOneWidget);
      expect(find.text('SIMULATION PIPELINE TIMELINE'), findsOneWidget);
    });

    testWidgets('Test 8 — CustomerRecoveryScreen renders DEMO SIMULATION MODE and button when simulated: true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CustomerRecoveryScreen(
            sessionId: 'ses_sim_99',
            token: 'tok_sim_99',
            simulated: true,
            mockValidation: CustomerRecoveryValidation(
              valid: true,
              sessionId: 'ses_sim_99',
              transactionId: 'tx_sim_99',
              amount: 1250.0,
              currency: 'INR',
              paymentMethod: 'UPI',
              bank: 'HDFC',
              strategy: 'RETRY',
              title: 'Payment could not be completed',
              message: "We couldn't complete your payment. Please try again.",
              actionPrompt: 'Try Payment Again',
              allowAlternate: true,
              simulated: true,
            ),
          ),
        ),
      );

      expect(find.text('DEMO SIMULATION MODE'), findsOneWidget);
      expect(find.text('Simulate Successful Payment'), findsOneWidget);
    });

    testWidgets('Test 9 — CustomerRecoveryScreen demo button triggers simulated payment recovery', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CustomerRecoveryScreen(
            sessionId: 'ses_sim_99',
            token: 'tok_sim_99',
            simulated: true,
            mockValidation: CustomerRecoveryValidation(
              valid: true,
              sessionId: 'ses_sim_99',
              transactionId: 'tx_sim_99',
              amount: 1250.0,
              currency: 'INR',
              paymentMethod: 'UPI',
              bank: 'HDFC',
              strategy: 'RETRY',
              title: 'Payment could not be completed',
              message: "We couldn't complete your payment. Please try again.",
              actionPrompt: 'Try Payment Again',
              allowAlternate: true,
              simulated: true,
            ),
          ),
        ),
      );

      // Tap Simulate Successful Payment
      await tester.tap(find.text('Simulate Successful Payment'));
      await tester.pumpAndSettle();

      expect(find.text('Payment Recovered Successfully!'), findsOneWidget);
      expect(find.text('COMPLETED'), findsOneWidget);
    });
  });
}
