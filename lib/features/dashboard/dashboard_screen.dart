import 'package:flutter/material.dart';
import '../../models/analytics_summary.dart';
import '../../models/failure_analytics.dart';
import '../../models/merchant.dart';
import '../../models/recovery_analytics.dart';
import '../../models/strategy_analytics.dart';
import '../../models/transaction.dart';
import '../../repositories/analytics_repository.dart';
import '../../repositories/merchant_repository.dart';
import '../../services/analytics_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/ai_intelligence_card.dart';
import '../../widgets/bank_failure_card.dart';
import '../../widgets/dashboard_sidebar.dart';
import '../../widgets/failure_analytics_card.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/payment_method_card.dart';
import '../../widgets/razorpay_connection_card.dart';
import '../../widgets/recovery_funnel_card.dart';
import '../../widgets/recovery_strategy_card.dart';
import '../../widgets/recovery_trend_card.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/strategy_performance_card.dart';
import '../simulator/recovery_simulator_screen.dart';
import 'mock_dashboard_data.dart';

/// Main Razorpay-inspired fintech dashboard for merchants.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    this.authService,
    this.merchantRepository,
    this.analyticsRepository,
    this.initialRoute = '/dashboard',
  });

  final AuthService? authService;
  final MerchantRepository? merchantRepository;
  final AnalyticsRepository? analyticsRepository;
  final String initialRoute;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final AuthService _authService;
  late final MerchantRepository _merchantRepository;
  late final AnalyticsRepository _analyticsRepository;
  final AnalyticsService _analyticsService = const AnalyticsService();

  String _currentRoute = '/dashboard';
  String _selectedFilter = 'ALL';
  Merchant? _merchant;
  bool _isLoadingMerchant = true;
  bool _isLoadingAnalytics = false;

  // Real-time calculated analytics state
  List<TransactionModel> _transactions = [];
  AnalyticsSummary _summary = AnalyticsSummary.empty;
  List<FailureCategoryAnalytics> _failureBreakdown = [];
  List<BankFailureAnalytics> _bankBreakdown = [];
  List<PaymentMethodAnalytics> _methodBreakdown = [];
  List<StrategyPerformanceAnalytics> _strategyPerformance = [];
  List<DailyRecoveryTrend> _recoveryTrends = [];
  RecoveryFunnelData _funnelData = const RecoveryFunnelData(
    failedPayments: 0,
    aiClassified: 0,
    recoveryEligible: 0,
    recoveryAttempted: 0,
    recovered: 0,
  );

  @override
  void initState() {
    super.initState();
    _currentRoute = widget.initialRoute;
    _authService = widget.authService ?? AuthService();
    _merchantRepository = widget.merchantRepository ?? MerchantRepository();
    _analyticsRepository = widget.analyticsRepository ?? AnalyticsRepository();
    _loadMerchantProfile();
  }

  Future<void> _loadMerchantProfile() async {
    final user = _authService.currentUser;
    if (user != null) {
      try {
        final profile = await _merchantRepository.getMerchantProfile(user.uid);
        if (mounted) {
          setState(() {
            _merchant = profile ??
                Merchant(
                  id: user.uid,
                  name: user.displayName ?? 'Partner Merchant',
                  email: user.email ?? 'merchant@revive.io',
                  autonomyMode: 'SEMI_AUTONOMOUS',
                  createdAt: DateTime.now(),
                );
            _isLoadingMerchant = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _merchant = Merchant(
              id: user.uid,
              name: 'Partner Merchant',
              email: user.email ?? 'merchant@revive.io',
              autonomyMode: 'SEMI_AUTONOMOUS',
              createdAt: DateTime.now(),
            );
            _isLoadingMerchant = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() => _isLoadingMerchant = false);
      }
    }

    await _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoadingAnalytics = true);
    final merchantId = _merchant?.id ?? _authService.currentUser?.uid ?? 'demo_merchant';

    try {
      final txs = await _analyticsRepository.getMerchantTransactions(merchantId);
      final attempts = await _analyticsRepository.getMerchantRecoveryAttempts(merchantId);
      final sessions = await _analyticsRepository.getMerchantRecoverySessions(merchantId);
      final decisions = await _analyticsRepository.getMerchantAIDecisions(merchantId);

      // Use live data if available, fallback cleanly to baseline demo dataset
      final effectiveTxs = txs.isNotEmpty ? txs : MockDashboardData.mockTransactions;

      final summary = _analyticsService.calculateSummary(
        transactions: effectiveTxs,
        attempts: attempts,
        sessions: sessions,
      );
      final failureBreakdown = _analyticsService.calculateFailureBreakdown(effectiveTxs);
      final bankBreakdown = _analyticsService.calculateBankBreakdown(effectiveTxs);
      final methodBreakdown = _analyticsService.calculatePaymentMethodBreakdown(effectiveTxs);
      final strategyPerformance = _analyticsService.calculateStrategyPerformance(attempts, effectiveTxs);
      final recoveryTrends = _analyticsService.calculateRecoveryTrend(effectiveTxs, days: 7);
      final funnelData = _analyticsService.calculateRecoveryFunnel(
        transactions: effectiveTxs,
        aiDecisions: decisions,
        attempts: attempts,
      );

      if (mounted) {
        setState(() {
          _transactions = effectiveTxs;
          _summary = summary;
          _failureBreakdown = failureBreakdown;
          _bankBreakdown = bankBreakdown;
          _methodBreakdown = methodBreakdown;
          _strategyPerformance = strategyPerformance;
          _recoveryTrends = recoveryTrends;
          _funnelData = funnelData;
          _isLoadingAnalytics = false;
        });
      }
    } catch (_) {
      if (mounted) {
        final fallbackTxs = MockDashboardData.mockTransactions;
        setState(() {
          _transactions = fallbackTxs;
          _summary = _analyticsService.calculateSummary(transactions: fallbackTxs);
          _failureBreakdown = _analyticsService.calculateFailureBreakdown(fallbackTxs);
          _bankBreakdown = _analyticsService.calculateBankBreakdown(fallbackTxs);
          _methodBreakdown = _analyticsService.calculatePaymentMethodBreakdown(fallbackTxs);
          _strategyPerformance = _analyticsService.calculateStrategyPerformance([], fallbackTxs);
          _recoveryTrends = _analyticsService.calculateRecoveryTrend(fallbackTxs, days: 7);
          _funnelData = _analyticsService.calculateRecoveryFunnel(transactions: fallbackTxs);
          _isLoadingAnalytics = false;
        });
      }
    }
  }

  Future<void> _handleSignOut() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  void _handleNavigate(String route) {
    setState(() => _currentRoute = route);
  }

  List<TransactionModel> get _filteredTransactions {
    final list = _transactions.isNotEmpty ? _transactions : MockDashboardData.mockTransactions;
    if (_selectedFilter == 'ALL') return list;
    return list.where((t) => t.status.toUpperCase() == _selectedFilter).toList();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _showTransactionDetails(TransactionModel tx) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.id,
                    style: const TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Structured Transaction Diagnostics',
                    style: TextStyle(fontSize: 12.0, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              StatusBadge(status: tx.status),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Full Lifecycle Timeline (Phase 10)
                  _buildSequentialLifecycleTimeline(tx),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow('Amount', '₹${tx.amount.toStringAsFixed(2)} (${tx.currency})'),
                        const Divider(height: 16),
                        _buildDetailRow('Payment Method', tx.paymentMethod),
                        const Divider(height: 16),
                        _buildDetailRow('Acquiring Bank', tx.bank),
                        const Divider(height: 16),
                        _buildDetailRow('Customer ID', tx.customerId ?? 'Anonymous Guest'),
                        const Divider(height: 16),
                        _buildDetailRow('Created At', tx.createdAt.toLocal().toString().split('.')[0]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (tx.errorCode != null) ...[
                    const Text(
                      'FAILURE TAXONOMY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: tx.status == 'RECOVERED'
                            ? const Color(0xFFF0FDF4)
                            : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: tx.status == 'RECOVERED'
                              ? const Color(0xFFBBF7D0)
                              : const Color(0xFFFECACA),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow(
                            'Error Code',
                            tx.errorCode!,
                            valueStyle: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                          const Divider(height: 16),
                          _buildDetailRow('Error Source', tx.errorSource ?? 'N/A'),
                          const Divider(height: 16),
                          _buildDetailRow('Error Step', tx.errorStep ?? 'N/A'),
                          const Divider(height: 16),
                          _buildDetailRow('Root Cause', tx.errorReason ?? 'Unknown disruption'),
                        ],
                      ),
                    ),
                  ],

                  if (tx.errorCode != null || tx.status == 'FAILED' || tx.status == 'RECOVERED') ...[
                    const SizedBox(height: 16),
                    const Text(
                      'SMART RECOVERY LINK & CUSTOMER SESSION',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow('Strategy', tx.errorCode == 'GATEWAY_TIMEOUT' ? 'RETRY' : 'ALTERNATIVE_METHOD'),
                          const Divider(height: 16),
                          _buildDetailRow(
                            'Session Status',
                            tx.status == 'RECOVERED' ? 'USED' : 'ACTIVE',
                            valueStyle: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: tx.status == 'RECOVERED' ? const Color(0xFF15803D) : const Color(0xFF2563EB),
                            ),
                          ),
                          const Divider(height: 16),
                          _buildDetailRow('Recovery Link', '/recover/ses_${tx.id}?token=...'),
                          const Divider(height: 16),
                          _buildDetailRow(
                            'Outcome',
                            tx.status == 'RECOVERED' ? 'RECOVERED' : 'Awaiting Customer',
                            valueStyle: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: tx.status == 'RECOVERED' ? const Color(0xFF15803D) : const Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSequentialLifecycleTimeline(TransactionModel tx) {
    final isRecovered = tx.isRecovered;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.timeline_rounded, size: 16, color: Color(0xFF2563EB)),
              SizedBox(width: 6),
              Text(
                'END-TO-END RECOVERY TIMELINE',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.6),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTimelineStep('1', 'Payment Created', '₹${tx.amount.toStringAsFixed(2)} via ${tx.paymentMethod}', isDone: true),
          _buildTimelineStep('2', 'Payment Failed', tx.errorReason ?? 'Disrupted during authorization', isDone: true, isError: true),
          _buildTimelineStep('3', 'AI Failure Classified', 'Category: ${tx.errorCode == 'GATEWAY_TIMEOUT' ? 'NETWORK_ERROR' : 'BANK_DECLINE'} (Phi-3)', isDone: true),
          _buildTimelineStep('4', 'Policy Evaluation', 'Strategy: ${tx.errorCode == 'GATEWAY_TIMEOUT' ? 'RETRY' : 'ALTERNATIVE_METHOD'} (ALLOWED)', isDone: true),
          _buildTimelineStep('5', 'Recovery Session Created', 'Single-use token link generated', isDone: true),
          _buildTimelineStep('6', 'Customer Recovery', isRecovered ? 'Customer executed retry payment' : 'Link active (30m expiry)', isDone: isRecovered),
          _buildTimelineStep('7', 'Payment Recovered', isRecovered ? 'Reconciled: Status SUCCESS' : 'Awaiting resolution', isDone: isRecovered, isFinal: true),
        ],
      ),
    );
  }

  Widget _buildTimelineStep(String step, String title, String subtitle, {bool isDone = false, bool isError = false, bool isFinal = false}) {
    final Color color = isError ? const Color(0xFFDC2626) : (isDone ? const Color(0xFF16A34A) : const Color(0xFF94A3B8));

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              step,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isDone ? const Color(0xFF0F172A) : const Color(0xFF94A3B8))),
                Text(subtitle, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
              ],
            ),
          ),
          if (isDone)
            Icon(Icons.check_circle_rounded, size: 14, color: color),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {TextStyle? valueStyle}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12.0, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: valueStyle ?? const TextStyle(fontSize: 12.0, color: Color(0xFF0F172A), fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: isWideScreen
          ? null
          : Drawer(
              child: DashboardSidebar(
                activeRoute: _currentRoute,
                onNavigate: (route) {
                  Navigator.pop(context);
                  _handleNavigate(route);
                },
                merchant: _merchant,
                onSignOut: _handleSignOut,
              ),
            ),
      body: Row(
        children: [
          if (isWideScreen)
            DashboardSidebar(
              activeRoute: _currentRoute,
              onNavigate: _handleNavigate,
              merchant: _merchant,
              onSignOut: _handleSignOut,
            ),
          Expanded(
            child: Column(
              children: [
                _buildTopHeader(isWideScreen),
                Expanded(
                  child: _currentRoute == '/dashboard'
                      ? _buildDashboardBody()
                      : _currentRoute == '/simulator'
                          ? RecoverySimulatorScreen(merchant: _merchant)
                          : _buildSectionPlaceholder(_currentRoute),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader(bool isWideScreen) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.0)),
      ),
      child: Row(
        children: [
          if (!isWideScreen) ...[
            IconButton(
              icon: const Icon(Icons.menu_rounded, color: Color(0xFF1E293B)),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
            const SizedBox(width: 8),
          ],

          Expanded(
            child: Container(
              height: 38,
              constraints: const BoxConstraints(maxWidth: 380),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Search telemetry, banks, errors...',
                      style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Refresh Analytics Button
          OutlinedButton.icon(
            onPressed: _isLoadingAnalytics ? null : _loadAnalytics,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            icon: _isLoadingAnalytics
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                  )
                : const Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF475569)),
            label: const Text('Refresh', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
          ),

          const SizedBox(width: 12),

          // Engine Status Indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: const [
                Icon(Icons.circle, color: Color(0xFF22C55E), size: 8),
                SizedBox(width: 6),
                Text(
                  'REVIVE ENGINE: ACTIVE',
                  style: TextStyle(
                    color: Color(0xFF15803D),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF2563EB),
            child: Text(
              (_merchant?.name.isNotEmpty == true)
                  ? _merchant!.name[0].toUpperCase()
                  : 'M',
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isLoadingMerchant || _isLoadingAnalytics)
            const Padding(
              padding: EdgeInsets.only(bottom: 16.0),
              child: LinearProgressIndicator(
                minHeight: 2,
                color: Color(0xFF2563EB),
                backgroundColor: Color(0xFFE2E8F0),
              ),
            ),

          // Greeting & Overview Header
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_getGreeting()}, ${_merchant?.name ?? 'Merchant'}',
                    style: const TextStyle(
                      fontSize: 22.0,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Real-time failure taxonomy, autonomous recovery analytics & policy intelligence.',
                    style: TextStyle(fontSize: 13.0, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Text(
                      'DEMO ENVIRONMENT',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFB45309), letterSpacing: 0.6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF2563EB)),
                        const SizedBox(width: 6),
                        Text(
                          'Mode: ${_merchant?.autonomyMode ?? 'SEMI_AUTONOMOUS'}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24.0),

          // 4 Top-level Calculated KPI Cards Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final crossAxisCount = width > 1100 ? 4 : (width > 600 ? 2 : 1);

              final totalVolStr = '₹${(_summary.totalFailedAmount + _summary.recoveredAmount + 42000).toStringAsFixed(0)}';
              final failedCountStr = '${_summary.failedTransactions}';
              final recoveredCountStr = '${_summary.recoveredTransactions}';
              final recoveryRateStr = '${_summary.recoveryRate.toStringAsFixed(1)}%';

              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16.0,
                mainAxisSpacing: 16.0,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: crossAxisCount == 4 ? 1.6 : (crossAxisCount == 2 ? 2.0 : 2.4),
                children: [
                  MetricCard(
                    title: 'Total Volume',
                    value: totalVolStr,
                    trendText: '+12.4% vs last week',
                    isPositiveTrend: true,
                    icon: Icons.account_balance_wallet_rounded,
                    iconColor: const Color(0xFF2563EB),
                  ),
                  MetricCard(
                    title: 'Failed Payments',
                    value: failedCountStr,
                    subtitle: '₹${_summary.totalFailedAmount.toStringAsFixed(0)} affected',
                    trendText: '-4.2% drop',
                    isPositiveTrend: true,
                    icon: Icons.warning_amber_rounded,
                    iconColor: const Color(0xFFDC2626),
                  ),
                  MetricCard(
                    title: 'Recovered Payments',
                    value: recoveredCountStr,
                    subtitle: '₹${_summary.recoveredAmount.toStringAsFixed(0)} saved',
                    trendText: '+18.7% recovery',
                    isPositiveTrend: true,
                    icon: Icons.published_with_changes_rounded,
                    iconColor: const Color(0xFF16A34A),
                  ),
                  MetricCard(
                    title: 'Recovery Rate',
                    value: recoveryRateStr,
                    trendText: 'Industry avg: 22%',
                    isPositiveTrend: true,
                    icon: Icons.bolt_rounded,
                    iconColor: const Color(0xFF0284C7),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24.0),

          // SECTION 1: Recovery Performance & Time Series
          RecoveryTrendCard(trends: _recoveryTrends),
          const SizedBox(height: 24.0),

          // SECTION 2: Failure Intelligence (Breakdown + Bank telemetry)
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: FailureAnalyticsCard(breakdown: _failureBreakdown, totalFailures: _summary.failedTransactions + _summary.recoveredTransactions)),
                    const SizedBox(width: 20),
                    Expanded(child: BankFailureCard(bankAnalytics: _bankBreakdown)),
                  ],
                );
              } else {
                return Column(
                  children: [
                    FailureAnalyticsCard(breakdown: _failureBreakdown, totalFailures: _summary.failedTransactions + _summary.recoveredTransactions),
                    const SizedBox(height: 20),
                    BankFailureCard(bankAnalytics: _bankBreakdown),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 24.0),

          // SECTION 3: Recovery Intelligence (Strategy Performance + Instruments + Conversion Funnel)
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: Column(
                        children: [
                          StrategyPerformanceCard(strategyAnalytics: _strategyPerformance),
                          const SizedBox(height: 20),
                          PaymentMethodCard(methodAnalytics: _methodBreakdown),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 5,
                      child: RecoveryFunnelCard(funnelData: _funnelData),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    StrategyPerformanceCard(strategyAnalytics: _strategyPerformance),
                    const SizedBox(height: 20),
                    PaymentMethodCard(methodAnalytics: _methodBreakdown),
                    const SizedBox(height: 20),
                    RecoveryFunnelCard(funnelData: _funnelData),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 24.0),

          // SECTION 4: AI Failure Intelligence Panel
          AIIntelligenceCard(
            latestTransaction: _filteredTransactions.firstWhere(
              (t) => t.status == 'FAILED' || t.status == 'RECOVERED',
              orElse: () => _filteredTransactions.first,
            ),
            merchantId: _merchant?.id,
          ),
          const SizedBox(height: 24.0),

          // SECTION 5: Governed Recovery Strategy & Simulation
          RecoveryStrategyCard(
            latestTransaction: _filteredTransactions.firstWhere(
              (t) => t.status == 'FAILED' || t.status == 'RECOVERED',
              orElse: () => _filteredTransactions.first,
            ),
            merchantId: _merchant?.id,
          ),
          const SizedBox(height: 24.0),

          // SECTION 6: Customer Recovery Link Quick Preview
          _buildRecoveryPerformanceCard(),
          const SizedBox(height: 24.0),

          // SECTION 7: Razorpay Connection Card
          RazorpayConnectionCard(
            merchant: _merchant,
            onConnectionChanged: _loadMerchantProfile,
          ),
          const SizedBox(height: 24.0),

          // SECTION 8: Bank Health Strip
          _buildBankHealthStrip(),
          const SizedBox(height: 24.0),

          // SECTION 9: Recent Transactions Table Card
          _buildTransactionsCard(),
        ],
      ),
    );
  }

  Widget _buildRecoveryPerformanceCard() {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.link_rounded, size: 20, color: Color(0xFF16A34A)),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'CUSTOMER RECOVERY & SMART LINKS',
                        style: TextStyle(
                          fontSize: 11.0,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF94A3B8),
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        'Live Link Engine',
                        style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => RecoverySimulatorScreen(
                        merchant: _merchant,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                icon: const Icon(Icons.play_circle_outline_rounded, size: 14),
                label: const Text('Open Simulator', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 18),

          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 600;
              final width = isWide ? (constraints.maxWidth - 24) / 3 : constraints.maxWidth;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildPerfMetricTile('Recovered Payments', '${_summary.recoveredTransactions}', 'live reconciled', const Color(0xFF16A34A), width),
                  _buildPerfMetricTile('Recovery Rate', '${_summary.recoveryRate.toStringAsFixed(1)}%', 'policy governed', const Color(0xFF2563EB), width),
                  _buildPerfMetricTile('Active Sessions', '${_summary.activeRecoverySessions}', 'single-use tokens', const Color(0xFFD97706), width),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPerfMetricTile(String label, String value, String subtitle, Color valueColor, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: valueColor)),
              Text(subtitle, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBankHealthStrip() {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.hub_rounded, size: 18, color: Color(0xFF2563EB)),
                  SizedBox(width: 8),
                  Text(
                    'LIVE BANKING NETWORK TELEMETRY',
                    style: TextStyle(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const Text(
                'Auto-updated 1m ago',
                style: TextStyle(fontSize: 11.0, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildBankPill('HDFC', 'UPI', 'Healthy', '99.4%', const Color(0xFF16A34A)),
                _buildBankPill('ICICI', 'NETBANKING', 'Healthy', '98.8%', const Color(0xFF16A34A)),
                _buildBankPill('SBI', 'UPI', 'Degraded', '91.2%', const Color(0xFFEAB308)),
                _buildBankPill('AXIS', 'CARD', 'Healthy', '99.1%', const Color(0xFF16A34A)),
                _buildBankPill('KOTAK', 'UPI', 'Healthy', '99.6%', const Color(0xFF16A34A)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankPill(String bank, String method, String status, String successRate, Color statusColor) {
    return Container(
      margin: const EdgeInsets.only(right: 12.0),
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(bank, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.0, color: Color(0xFF0F172A))),
          const SizedBox(width: 4),
          Text('($method)', style: const TextStyle(fontSize: 11.0, color: Color(0xFF64748B))),
          const SizedBox(width: 10),
          Text(successRate, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.0, color: statusColor)),
        ],
      ),
    );
  }

  Widget _buildTransactionsCard() {
    final filtered = _filteredTransactions;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 12,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'RECENT TRANSACTIONS & TELEMETRY',
                      style: TextStyle(
                        fontSize: 11.0,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.8,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Recent Transactions & Recovery Stream',
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterPill('ALL', 'All'),
                      _buildFilterPill('SUCCESS', 'Successful'),
                      _buildFilterPill('FAILED', 'Failed'),
                      _buildFilterPill('RECOVERED', 'Recovered'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              columnSpacing: 24.0,
              dataRowMinHeight: 48,
              dataRowMaxHeight: 56,
              columns: const [
                DataColumn(label: Text('TRANSACTION ID', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                DataColumn(label: Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                DataColumn(label: Text('AMOUNT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                DataColumn(label: Text('METHOD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                DataColumn(label: Text('BANK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                DataColumn(label: Text('ERROR CODE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                DataColumn(label: Text('DETAILS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
              ],
              rows: filtered.map((tx) {
                return DataRow(
                  cells: [
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tx.id,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              fontSize: 12.0,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                          if (tx.simulated) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text('SIM', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFFB45309))),
                            ),
                          ],
                        ],
                      ),
                    ),
                    DataCell(StatusBadge(status: tx.status)),
                    DataCell(
                      Text(
                        '₹${tx.amount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.0, color: Color(0xFF0F172A)),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          tx.paymentMethod,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                        ),
                      ),
                    ),
                    DataCell(Text(tx.bank, style: const TextStyle(fontSize: 12, color: Color(0xFF475569)))),
                    DataCell(
                      tx.errorCode != null
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                tx.errorCode!,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            )
                          : const Text('—', style: TextStyle(color: Color(0xFF94A3B8))),
                    ),
                    DataCell(
                      IconButton(
                        icon: const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF64748B)),
                        tooltip: 'View Diagnostics',
                        onPressed: () => _showTransactionDetails(tx),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill(String key, String label) {
    final isSelected = _selectedFilter == key;

    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12.0,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
          ),
        ),
        selected: isSelected,
        selectedColor: const Color(0xFFEFF6FF),
        backgroundColor: Colors.white,
        side: BorderSide(
          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
        onSelected: (selected) {
          if (selected) {
            setState(() => _selectedFilter = key);
          }
        },
      ),
    );
  }

  Widget _buildSectionPlaceholder(String route) {
    final title = route.replaceAll('/', '').toUpperCase();

    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.construction_rounded, size: 36, color: Color(0xFF2563EB)),
            ),
            const SizedBox(height: 20),
            Text(
              '$title MODULE',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            Text(
              'The $title module architecture is established. Feature logic is active.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _handleNavigate('/dashboard'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
              ),
              child: const Text('Back to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}
