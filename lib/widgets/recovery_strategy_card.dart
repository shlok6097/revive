import 'package:flutter/material.dart';
import '../models/ai_decision.dart';
import '../models/merchant_policy.dart';
import '../models/recovery_attempt.dart';
import '../models/recovery_decision.dart';
import '../models/transaction.dart';
import '../repositories/merchant_policy_repository.dart';
import '../services/recovery_strategy_service.dart';

/// Fintech card displaying deterministic recovery strategy evaluation,
/// attempt counters, policy decisions, and a visual recovery progress timeline.
class RecoveryStrategyCard extends StatefulWidget {
  const RecoveryStrategyCard({
    super.key,
    this.latestTransaction,
    this.aiDecision,
    this.merchantPolicy,
    this.previousAttempts = const [],
    this.merchantId,
    this.strategyService,
  });

  final TransactionModel? latestTransaction;
  final AIDecision? aiDecision;
  final MerchantPolicy? merchantPolicy;
  final List<RecoveryAttempt> previousAttempts;
  final String? merchantId;
  final RecoveryStrategyService? strategyService;

  @override
  State<RecoveryStrategyCard> createState() => _RecoveryStrategyCardState();
}

class _RecoveryStrategyCardState extends State<RecoveryStrategyCard> {
  RecoveryDecision? _decision;
  RecoveryAttempt? _simulatedAttempt;
  bool _isSimulating = false;

  @override
  void initState() {
    super.initState();
    _evaluate();
  }

  void _evaluate() {
    final tx = widget.latestTransaction;
    if (tx == null) return;

    final service = widget.strategyService ?? RecoveryStrategyService();
    final pol = widget.merchantPolicy ??
        MerchantPolicyRepository.defaultPolicy(widget.merchantId ?? 'merchant_current');
    final ai = widget.aiDecision ??
        AIDecision(
          id: 'dec_${tx.id}',
          merchantId: widget.merchantId ?? 'merchant_current',
          transactionId: tx.id,
          failureCategory: tx.errorCode == 'GATEWAY_TIMEOUT' ? 'NETWORK_ERROR' : 'BANK_DECLINE',
          recommendedStrategy: tx.errorCode == 'GATEWAY_TIMEOUT' ? 'RETRY' : 'ESCALATE',
          createdAt: DateTime.now(),
        );

    final dec = service.evaluateStrategy(
      transaction: tx,
      aiDecision: ai,
      policy: pol,
      previousAttempts: widget.previousAttempts,
    );

    setState(() => _decision = dec);
  }

  Future<void> _runSimulation() async {
    final tx = widget.latestTransaction;
    if (tx == null) return;

    setState(() => _isSimulating = true);
    try {
      final service = widget.strategyService ?? RecoveryStrategyService();
      final attempt = await service.createRecoveryDecision(
        transactionId: tx.id,
        merchantId: widget.merchantId ?? 'merchant_current',
        transaction: tx,
        aiDecision: widget.aiDecision,
        policy: widget.merchantPolicy,
        previousAttempts: widget.previousAttempts,
      );
      if (mounted) {
        setState(() {
          _simulatedAttempt = attempt;
          _evaluate();
        });
      }
    } catch (_) {
      // Handled gracefully in simulation UI
    } finally {
      if (mounted) setState(() => _isSimulating = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
      case 'SIMULATED':
      case 'COMPLETED':
        return const Color(0xFF16A34A);
      case 'BLOCKED':
      case 'FAILED':
        return const Color(0xFFDC2626);
      case 'PLANNED':
        return const Color(0xFF2563EB);
      case 'REQUIRES_REVIEW':
      default:
        return const Color(0xFFD97706);
    }
  }

  Color _getStatusBg(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
      case 'SIMULATED':
      case 'COMPLETED':
        return const Color(0xFFF0FDF4);
      case 'BLOCKED':
      case 'FAILED':
        return const Color(0xFFFEF2F2);
      case 'PLANNED':
        return const Color(0xFFEFF6FF);
      case 'REQUIRES_REVIEW':
      default:
        return const Color(0xFFFFFBEB);
    }
  }

  @override
  Widget build(BuildContext context) {
    final failureCategory = widget.aiDecision?.failureCategory ?? 'BANK_DECLINE';
    final aiRecommendation = widget.aiDecision?.recommendedStrategy ?? 'RETRY';
    final policyStatus = _decision?.policyStatus ?? 'ALLOWED';
    final strategy = _decision?.strategy ?? 'RETRY';
    final status = _simulatedAttempt?.status ?? _decision?.status ?? 'APPROVED';
    final maxRetries = widget.merchantPolicy?.maxAutomaticRetries ?? 1;
    final currentAttempt = widget.previousAttempts.length;
    final autonomyMode = widget.merchantPolicy?.autonomyMode ?? 'MANUAL';

    final statusColor = _getStatusColor(status);
    final statusBg = _getStatusBg(status);

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
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.alt_route_rounded,
                      size: 20,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'RECOVERY STRATEGY ENGINE',
                        style: TextStyle(
                          fontSize: 11.0,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF94A3B8),
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        'Governed Strategy & Simulation',
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      'MODE: $autonomyMode',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      status.replaceAll('_', ' '),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Diagnostic Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 600;
              final itemWidth = isWide ? (constraints.maxWidth - 36) / 4 : (constraints.maxWidth - 12) / 2;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildMetricTile('Failure Category', failureCategory.replaceAll('_', ' '), itemWidth),
                  _buildMetricTile('AI Recommendation', aiRecommendation.replaceAll('_', ' '), itemWidth, valueColor: const Color(0xFF9333EA)),
                  _buildMetricTile('Policy Decision', policyStatus.replaceAll('_', ' '), itemWidth, valueColor: const Color(0xFF16A34A)),
                  _buildMetricTile('Retry Attempts', '$currentAttempt / $maxRetries', itemWidth, valueColor: const Color(0xFF0F172A)),
                ],
              );
            },
          ),
          const SizedBox(height: 18),

          // Visual Recovery Timeline
          _buildRecoveryTimeline(),
          const SizedBox(height: 16),

          // Decision Reason & Simulation Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF2563EB)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _decision?.reason ?? 'Deterministic recovery strategy: $strategy approved for simulated execution.',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isSimulating ? null : _runSimulation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  icon: _isSimulating
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.play_arrow_rounded, size: 16),
                  label: const Text('Simulate Strategy', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Safety Invariant Callout
          Row(
            children: const [
              Icon(Icons.info_outline, size: 13, color: Color(0xFF94A3B8)),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Phase 6 Simulation Mode: Strategy calculated deterministically. Zero real payment actions executed.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, double width, {Color? valueColor}) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: valueColor ?? const Color(0xFF0F172A)),
          ),
        ],
      ),
    );
  }

  Widget _buildRecoveryTimeline() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RECOVERY LIFECYCLE PROGRESS',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 0.6),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTimelineStep(title: 'Payment Failed', isCompleted: true),
                _buildTimelineArrow(),
                _buildTimelineStep(title: 'AI Analysis', isCompleted: true),
                _buildTimelineArrow(),
                _buildTimelineStep(title: 'Policy Evaluation', isCompleted: true),
                _buildTimelineArrow(),
                _buildTimelineStep(title: 'Strategy Selected', isCompleted: true),
                _buildTimelineArrow(),
                _buildTimelineStep(title: 'Real Recovery', isCompleted: false, isDeferred: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep({
    required String title,
    required bool isCompleted,
    bool isDeferred = false,
  }) {
    Color bg;
    Color textColor;
    IconData icon;

    if (isDeferred) {
      bg = const Color(0xFFF1F5F9);
      textColor = const Color(0xFF94A3B8);
      icon = Icons.radio_button_unchecked_rounded;
    } else if (isCompleted) {
      bg = const Color(0xFFF0FDF4);
      textColor = const Color(0xFF15803D);
      icon = Icons.check_circle_rounded;
    } else {
      bg = const Color(0xFFEFF6FF);
      textColor = const Color(0xFF2563EB);
      icon = Icons.circle_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDeferred
              ? const Color(0xFFE2E8F0)
              : isCompleted
                  ? const Color(0xFFBBF7D0)
                  : const Color(0xFFBFDBFE),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 5),
          Text(
            isDeferred ? '$title (Phase 7)' : title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineArrow() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFFCBD5E1)),
    );
  }
}
