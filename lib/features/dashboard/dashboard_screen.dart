import 'package:flutter/material.dart';
import '../../models/merchant.dart';
import '../../models/transaction.dart';
import '../../repositories/merchant_repository.dart';
import '../../services/auth_service.dart';
import '../../widgets/ai_intelligence_card.dart';
import '../../widgets/dashboard_sidebar.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/razorpay_connection_card.dart';
import '../../widgets/status_badge.dart';
import 'mock_dashboard_data.dart';

/// Main Razorpay-inspired fintech dashboard for merchants.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    this.authService,
    this.merchantRepository,
    this.initialRoute = '/dashboard',
  });

  final AuthService? authService;
  final MerchantRepository? merchantRepository;
  final String initialRoute;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final AuthService _authService;
  late final MerchantRepository _merchantRepository;

  String _currentRoute = '/dashboard';
  String _selectedFilter = 'ALL';
  Merchant? _merchant;
  bool _isLoadingMerchant = true;

  @override
  void initState() {
    super.initState();
    _currentRoute = widget.initialRoute;
    _authService = widget.authService ?? AuthService();
    _merchantRepository = widget.merchantRepository ?? MerchantRepository();
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
    final list = MockDashboardData.mockTransactions;
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
                          if (tx.status == 'RECOVERED') ...[
                            const Divider(height: 16),
                            _buildDetailRow(
                              'Recovery Status',
                              'Recovered via Smart Dynamic UPI Fallback',
                              valueStyle: const TextStyle(
                                color: Color(0xFF15803D),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  if (tx.errorCode != null || tx.status == 'FAILED' || tx.status == 'RECOVERED') ...[
                    const SizedBox(height: 16),
                    const Text(
                      'AI FAILURE INTELLIGENCE',
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
                        color: const Color(0xFFFAF5FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE9D5FF)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow(
                            'Failure Category',
                            tx.errorCode == 'GATEWAY_TIMEOUT' ? 'NETWORK_ERROR' : 'BANK_DECLINE',
                            valueStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF7E22CE)),
                          ),
                          const Divider(height: 16),
                          _buildDetailRow(
                            'Recommended Strategy',
                            tx.errorCode == 'GATEWAY_TIMEOUT' ? 'RETRY' : 'ALTERNATIVE_METHOD',
                            valueStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                          ),
                          const Divider(height: 16),
                          _buildDetailRow(
                            'Policy Status',
                            'REQUIRES_REVIEW',
                            valueStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                          ),
                          const Divider(height: 16),
                          _buildDetailRow('Model Attribution', 'Phi-3 Mini (v1.0)'),
                          const Divider(height: 16),
                          _buildDetailRow('Prompt Version', 'revive-payment-classifier-v1'),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFE9D5FF)),
                            ),
                            child: const Text(
                              'AI Recommendation — Human/Policy Validation Required (No recovery executed)',
                              style: TextStyle(fontSize: 11, color: Color(0xFF6B21A8), fontWeight: FontWeight.w600),
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
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {TextStyle? valueStyle}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: valueStyle ??
                const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width >= 960;

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
          // Sidebar for Desktop / Tablet
          if (isWideScreen)
            DashboardSidebar(
              activeRoute: _currentRoute,
              onNavigate: _handleNavigate,
              merchant: _merchant,
              onSignOut: _handleSignOut,
            ),

          // Main Content View
          Expanded(
            child: Column(
              children: [
                // Top Header Bar
                _buildTopHeader(isWideScreen),

                // Main Content Body
                Expanded(
                  child: _currentRoute == '/dashboard'
                      ? _buildDashboardBody()
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

          // Search Bar Placeholder
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
                      'Search transactions, customers, banks...',
                      style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 16),

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

          const SizedBox(width: 16),

          // Notification Bell
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF475569)),
                onPressed: () {},
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2563EB),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(width: 8),

          // Merchant Profile Avatar
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
          if (_isLoadingMerchant)
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
                    'Real-time payment telemetry, failure taxonomy & autonomous recovery metrics.',
                    style: TextStyle(fontSize: 13.0, color: Color(0xFF64748B)),
                  ),
                ],
              ),
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
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24.0),

          // 4 Metric KPI Cards Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final crossAxisCount = width > 1100 ? 4 : (width > 600 ? 2 : 1);

              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16.0,
                mainAxisSpacing: 16.0,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: crossAxisCount == 4 ? 1.6 : (crossAxisCount == 2 ? 2.0 : 2.4),
                children: const [
                  MetricCard(
                    title: 'Total Volume',
                    value: MockDashboardData.totalVolume,
                    trendText: MockDashboardData.totalVolumeTrend,
                    isPositiveTrend: true,
                    icon: Icons.account_balance_wallet_rounded,
                    iconColor: Color(0xFF2563EB),
                  ),
                  MetricCard(
                    title: 'Success Rate',
                    value: MockDashboardData.successRate,
                    trendText: MockDashboardData.successRateTrend,
                    isPositiveTrend: true,
                    icon: Icons.check_circle_rounded,
                    iconColor: Color(0xFF16A34A),
                  ),
                  MetricCard(
                    title: 'Failed Payments',
                    value: MockDashboardData.failedPayments,
                    subtitle: MockDashboardData.failedSubtitle,
                    trendText: '-4.2% drop',
                    isPositiveTrend: true,
                    icon: Icons.warning_amber_rounded,
                    iconColor: Color(0xFFDC2626),
                  ),
                  MetricCard(
                    title: 'Recovered Payments',
                    value: MockDashboardData.recoveredPayments,
                    subtitle: MockDashboardData.recoveredSubtitle,
                    trendText: '+18.5% recovery',
                    isPositiveTrend: true,
                    icon: Icons.published_with_changes_rounded,
                    iconColor: Color(0xFF0284C7),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24.0),

          // Payment Gateway Connection Status Card
          RazorpayConnectionCard(
            merchant: _merchant,
            onConnectionChanged: _loadMerchantProfile,
          ),
          const SizedBox(height: 24.0),

          // Bank Health Telemetry Strip
          _buildBankHealthStrip(),
          const SizedBox(height: 24.0),

          // AI Failure Intelligence Overview Card
          AIIntelligenceCard(
            latestTransaction: _filteredTransactions.firstWhere(
              (t) => t.status == 'FAILED' || t.status == 'RECOVERED',
              orElse: () => _filteredTransactions.first,
            ),
            merchantId: _merchant?.id,
          ),
          const SizedBox(height: 24.0),

          // Recent Transactions Table Card
          _buildTransactionsCard(),
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
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: Color(0xFF475569),
                    ),
                  ),
                ],
              ),
              const Text(
                'Updated 1m ago',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              return Wrap(
                spacing: 16,
                runSpacing: 12,
                children: MockDashboardData.bankHealthList.map((bh) {
                  final isDegraded = bh.status == 'DEGRADED';
                  return Container(
                    width: isWide ? (constraints.maxWidth - 48) / 4 : (constraints.maxWidth - 16) / 2,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDegraded ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                bh.bankName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDegraded ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                bh.status,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isDegraded ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                'Success: ${bh.successRate}%',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${bh.latency}ms',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header with Tabs
          Padding(
            padding: const EdgeInsets.all(20.0),
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
                      'Recent Transactions & Recovery Stream',
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Click any record to inspect structured error taxonomy and recovery actions.',
                      style: TextStyle(fontSize: 12.0, color: Color(0xFF64748B)),
                    ),
                  ],
                ),

                // Filter Buttons
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('ALL', 'All'),
                      const SizedBox(width: 6),
                      _buildFilterChip('RECOVERED', 'Recovered'),
                      const SizedBox(width: 6),
                      _buildFilterChip('FAILED', 'Failed'),
                      const SizedBox(width: 6),
                      _buildFilterChip('SUCCESS', 'Success'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Transactions Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: false,
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              columns: const [
                DataColumn(label: Text('TRANSACTION ID', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF64748B)))),
                DataColumn(label: Text('AMOUNT', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF64748B)))),
                DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF64748B)))),
                DataColumn(label: Text('METHOD', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF64748B)))),
                DataColumn(label: Text('BANK', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF64748B)))),
                DataColumn(label: Text('FAILURE TAXONOMY / CODE', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF64748B)))),
                DataColumn(label: Text('TIME', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF64748B)))),
              ],
              rows: _filteredTransactions.map((tx) {
                return DataRow(
                  onSelectChanged: (_) => _showTransactionDetails(tx),
                  cells: [
                    DataCell(
                      Text(
                        tx.id,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        '₹${tx.amount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      ),
                    ),
                    DataCell(StatusBadge(status: tx.status, compact: true)),
                    DataCell(Text(tx.paymentMethod, style: const TextStyle(fontSize: 13))),
                    DataCell(Text(tx.bank, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                    DataCell(
                      tx.errorCode != null
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: tx.status == 'RECOVERED'
                                    ? const Color(0xFFF0FDF4)
                                    : const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                tx.errorCode!,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: tx.status == 'RECOVERED'
                                      ? const Color(0xFF15803D)
                                      : const Color(0xFFDC2626),
                                ),
                              ),
                            )
                          : const Text('—', style: TextStyle(color: Color(0xFF94A3B8))),
                    ),
                    DataCell(
                      Text(
                        '${DateTime.now().difference(tx.createdAt).inMinutes}m ago',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
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

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = value),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionPlaceholder(String route) {
    final title = route.replaceAll('/', '').toUpperCase();
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        constraints: const BoxConstraints(maxWidth: 500),
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
              'The $title module architecture is established. Feature logic will be connected in subsequent phases.',
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
