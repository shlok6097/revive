import 'package:flutter/material.dart';

/// Represents a predefined failure telemetry scenario for the REVIVE Simulator.
class SimulationScenario {
  const SimulationScenario({
    required this.id,
    required this.title,
    required this.description,
    required this.amount,
    this.currency = 'INR',
    required this.paymentMethod,
    required this.bank,
    required this.errorCode,
    required this.errorReason,
    required this.errorSource,
    required this.errorStep,
    required this.color,
    required this.icon,
    required this.expectedStrategy,
    required this.expectedPolicyStatus,
  });

  final String id;
  final String title;
  final String description;
  final double amount;
  final String currency;
  final String paymentMethod;
  final String bank;
  final String errorCode;
  final String errorReason;
  final String errorSource;
  final String errorStep;
  final Color color;
  final IconData icon;
  final String expectedStrategy;
  final String expectedPolicyStatus;

  /// Standard preset failure scenarios for end-to-end demonstration.
  static const List<SimulationScenario> presets = [
    SimulationScenario(
      id: 'BANK_DECLINE',
      title: 'Bank Decline',
      description: 'Issuing bank declined debit authorization due to temporary limit.',
      amount: 1250.0,
      currency: 'INR',
      paymentMethod: 'UPI',
      bank: 'HDFC',
      errorCode: 'BAD_REQUEST_ERROR',
      errorReason: 'Payment declined by bank',
      errorSource: 'bank',
      errorStep: 'authorization',
      color: Color(0xFFDC2626),
      icon: Icons.block_rounded,
      expectedStrategy: 'RETRY',
      expectedPolicyStatus: 'ALLOWED',
    ),
    SimulationScenario(
      id: 'NETWORK_ERROR',
      title: 'Network Timeout',
      description: 'Network gateway timed out during payment authorization handoff.',
      amount: 850.0,
      currency: 'INR',
      paymentMethod: 'UPI',
      bank: 'ICICI',
      errorCode: 'GATEWAY_TIMEOUT',
      errorReason: 'Gateway timeout contacting issuing bank',
      errorSource: 'gateway',
      errorStep: 'payment_authorization',
      color: Color(0xFFEA580C),
      icon: Icons.wifi_off_rounded,
      expectedStrategy: 'RETRY',
      expectedPolicyStatus: 'ALLOWED',
    ),
    SimulationScenario(
      id: 'INSUFFICIENT_FUNDS',
      title: 'Insufficient Funds',
      description: 'Customer account has insufficient funds for transaction amount.',
      amount: 3200.0,
      currency: 'INR',
      paymentMethod: 'UPI',
      bank: 'SBI',
      errorCode: 'INSUFFICIENT_FUNDS',
      errorReason: 'Customer account has insufficient funds',
      errorSource: 'bank',
      errorStep: 'debit_attempt',
      color: Color(0xFFD97706),
      icon: Icons.account_balance_wallet_outlined,
      expectedStrategy: 'ALTERNATIVE_METHOD',
      expectedPolicyStatus: 'ALLOWED',
    ),
    SimulationScenario(
      id: 'INVALID_DETAILS',
      title: 'Invalid Card Details',
      description: 'Customer entered invalid card CVV or expiry date.',
      amount: 2100.0,
      currency: 'INR',
      paymentMethod: 'CARD',
      bank: 'AXIS',
      errorCode: 'BAD_REQUEST_CARD_INVALID',
      errorReason: 'Invalid card CVV or expiry',
      errorSource: 'customer_app',
      errorStep: 'card_entry',
      color: Color(0xFF7C3AED),
      icon: Icons.credit_card_off_rounded,
      expectedStrategy: 'ALTERNATIVE_METHOD',
      expectedPolicyStatus: 'ALLOWED',
    ),
    SimulationScenario(
      id: 'AUTHENTICATION_FAILURE',
      title: '2FA Auth Failure',
      description: '2FA OTP expired or failed during verification step.',
      amount: 1750.0,
      currency: 'INR',
      paymentMethod: 'NETBANKING',
      bank: 'KOTAK',
      errorCode: 'AUTH_FAILED_OTP',
      errorReason: '2FA authentication failed or expired',
      errorSource: 'authentication_server',
      errorStep: 'otp_verification',
      color: Color(0xFF0284C7),
      icon: Icons.password_rounded,
      expectedStrategy: 'RETRY',
      expectedPolicyStatus: 'ALLOWED',
    ),
    SimulationScenario(
      id: 'FRAUD_RISK',
      title: 'Fraud Risk Filter',
      description: 'Transaction flagged and blocked by automated risk safety filters.',
      amount: 45000.0,
      currency: 'INR',
      paymentMethod: 'CARD',
      bank: 'HDFC',
      errorCode: 'RISK_SUSPECTED_FRAUD',
      errorReason: 'Transaction blocked by risk safety filter',
      errorSource: 'risk_engine',
      errorStep: 'risk_scoring',
      color: Color(0xFFB91C1C),
      icon: Icons.shield_rounded,
      expectedStrategy: 'NO_ACTION',
      expectedPolicyStatus: 'BLOCKED',
    ),
    SimulationScenario(
      id: 'UNKNOWN',
      title: 'Unknown Anomaly',
      description: 'Undocumented failure telemetry requiring human operator review.',
      amount: 999.0,
      currency: 'INR',
      paymentMethod: 'UPI',
      bank: 'UNKNOWN',
      errorCode: 'UNKNOWN_DISRUPTION',
      errorReason: 'Undocumented gateway telemetry anomaly',
      errorSource: 'unknown',
      errorStep: 'processing',
      color: Color(0xFF475569),
      icon: Icons.help_outline_rounded,
      expectedStrategy: 'ESCALATE',
      expectedPolicyStatus: 'REQUIRES_REVIEW',
    ),
  ];

  static SimulationScenario get defaultScenario => presets.first;

  static SimulationScenario findById(String id) {
    return presets.firstWhere(
      (s) => s.id.toUpperCase() == id.toUpperCase(),
      orElse: () => defaultScenario,
    );
  }
}
