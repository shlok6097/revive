import '../../models/bank_health.dart';
import '../../models/transaction.dart';

/// Isolated mock and demo data for UI layout, telemetry widgets, and transaction tables.
///
/// NOTE: This data is strictly separated from Firestore persistence and will be replaced
/// with real repository aggregation streams in subsequent phases.
class MockDashboardData {
  MockDashboardData._();

  static const String totalVolume = '₹24,85,200';
  static const String totalVolumeTrend = '+14.2% vs last week';

  static const String successRate = '94.2%';
  static const String successRateTrend = '+2.1% recovery boost';

  static const String failedPayments = '48';
  static const String failedSubtitle = '₹3,42,000 at risk';

  static const String recoveredPayments = '36';
  static const String recoveredSubtitle = '₹2,68,500 salvaged (75.0%)';

  /// Realistic mock bank health telemetry benchmarking payment gateways.
  static final List<BankHealth> bankHealthList = [
    BankHealth(
      id: 'bh_hdfc',
      bankName: 'HDFC Bank',
      status: 'OPTIMAL',
      successRate: 99.1,
      failureRate: 0.9,
      latency: 185,
      lastUpdatedAt: DateTime.now().subtract(const Duration(minutes: 2)),
    ),
    BankHealth(
      id: 'bh_icici',
      bankName: 'ICICI Bank',
      status: 'OPTIMAL',
      successRate: 98.4,
      failureRate: 1.6,
      latency: 210,
      lastUpdatedAt: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
    BankHealth(
      id: 'bh_axis',
      bankName: 'Axis Bank',
      status: 'OPTIMAL',
      successRate: 97.6,
      failureRate: 2.4,
      latency: 245,
      lastUpdatedAt: DateTime.now().subtract(const Duration(minutes: 3)),
    ),
    BankHealth(
      id: 'bh_sbi',
      bankName: 'State Bank of India',
      status: 'DEGRADED',
      successRate: 93.8,
      failureRate: 6.2,
      latency: 480,
      lastUpdatedAt: DateTime.now().subtract(const Duration(minutes: 1)),
    ),
  ];

  /// Realistic mock transactions capturing structured error taxonomy.
  static final List<TransactionModel> mockTransactions = [
    TransactionModel(
      id: 'tx_rv_982401',
      merchantId: 'mock_merchant',
      amount: 4500.0,
      currency: 'INR',
      status: 'SUCCESS',
      paymentMethod: 'UPI',
      bank: 'HDFC',
      createdAt: DateTime.now().subtract(const Duration(minutes: 8)),
      updatedAt: DateTime.now().subtract(const Duration(minutes: 8)),
    ),
    TransactionModel(
      id: 'tx_rv_982402',
      merchantId: 'mock_merchant',
      amount: 14850.0,
      currency: 'INR',
      status: 'RECOVERED',
      paymentMethod: 'NETBANKING',
      bank: 'SBI',
      errorCode: 'BANK_SERVER_TIMEOUT',
      errorReason: 'Core banking gateway timed out during MPIN validation',
      errorSource: 'BANK_GATEWAY',
      errorStep: 'OTP_VERIFICATION',
      customerId: 'cust_901',
      createdAt: DateTime.now().subtract(const Duration(minutes: 22)),
      updatedAt: DateTime.now().subtract(const Duration(minutes: 20)),
    ),
    TransactionModel(
      id: 'tx_rv_982403',
      merchantId: 'mock_merchant',
      amount: 1250.0,
      currency: 'INR',
      status: 'FAILED',
      paymentMethod: 'UPI',
      bank: 'ICICI',
      errorCode: 'INSUFFICIENT_FUNDS',
      errorReason: 'Customer account balance insufficient for debit amount',
      errorSource: 'CUSTOMER_APP',
      errorStep: 'DEBIT_ATTEMPT',
      customerId: 'cust_902',
      createdAt: DateTime.now().subtract(const Duration(minutes: 35)),
      updatedAt: DateTime.now().subtract(const Duration(minutes: 35)),
    ),
    TransactionModel(
      id: 'tx_rv_982404',
      merchantId: 'mock_merchant',
      amount: 28900.0,
      currency: 'INR',
      status: 'RECOVERED',
      paymentMethod: 'CARD',
      bank: 'AXIS',
      errorCode: '3DS_CHALLENGE_EXPIRED',
      errorReason: 'Customer 3D-Secure biometric window expired on browser',
      errorSource: 'AUTHENTICATION_SERVER',
      errorStep: 'PAYMENT_AUTHORIZATION',
      customerId: 'cust_903',
      createdAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 10)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 8)),
    ),
    TransactionModel(
      id: 'tx_rv_982405',
      merchantId: 'mock_merchant',
      amount: 3200.0,
      currency: 'INR',
      status: 'SUCCESS',
      paymentMethod: 'UPI',
      bank: 'HDFC',
      createdAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 40)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 40)),
    ),
    TransactionModel(
      id: 'tx_rv_982406',
      merchantId: 'mock_merchant',
      amount: 8750.0,
      currency: 'INR',
      status: 'FAILED',
      paymentMethod: 'NETBANKING',
      bank: 'SBI',
      errorCode: 'GATEWAY_DEGRADED_DOWN',
      errorReason: 'SBI Netbanking switch unreachable during peak server maintenance',
      errorSource: 'BANK_GATEWAY',
      errorStep: 'DEBIT_ATTEMPT',
      customerId: 'cust_904',
      createdAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 15)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 15)),
    ),
    TransactionModel(
      id: 'tx_rv_982407',
      merchantId: 'mock_merchant',
      amount: 19500.0,
      currency: 'INR',
      status: 'RECOVERED',
      paymentMethod: 'UPI',
      bank: 'HDFC',
      errorCode: 'PSP_ROUTING_FAILURE',
      errorReason: 'Primary Payment Service Provider rate limit exceeded',
      errorSource: 'ISSUER_NETWORK',
      errorStep: 'PAYMENT_AUTHORIZATION',
      customerId: 'cust_905',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 58)),
    ),
  ];
}
