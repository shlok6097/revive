import 'package:flutter/material.dart';
import '../../models/merchant.dart';
import '../../models/simulation_scenario.dart';
import '../../services/payment_simulator_service.dart';
import '../recovery/customer_recovery_screen.dart';

/// Interactive Payment Failure Simulator & End-to-End Autonomous Recovery Demo Screen.
class RecoverySimulatorScreen extends StatefulWidget {
  const RecoverySimulatorScreen({
    super.key,
    this.merchant,
    this.simulatorService,
    this.initialScenario,
  });

  final Merchant? merchant;
  final PaymentSimulatorService? simulatorService;
  final SimulationScenario? initialScenario;

  @override
  State<RecoverySimulatorScreen> createState() => _RecoverySimulatorScreenState();
}

class _RecoverySimulatorScreenState extends State<RecoverySimulatorScreen> {
  late SimulationScenario _selectedScenario;
  late PaymentSimulatorService _simulatorService;

  bool _isRunning = false;
  List<String> _progressSteps = [];
  SimulationRunResult? _result;

  @override
  void initState() {
    super.initState();
    _selectedScenario = widget.initialScenario ?? SimulationScenario.presets.first;
    _simulatorService = widget.simulatorService ?? PaymentSimulatorService();
  }

  Future<void> _runSimulation() async {
    setState(() {
      _isRunning = true;
      _progressSteps = ['Initializing simulation environment...'];
      _result = null;
    });

    try {
      final merchantId = widget.merchant?.id ?? 'merchant_demo_uid';

      final result = await _simulatorService.runSimulationPipeline(
        merchantId: merchantId,
        scenario: _selectedScenario,
        onStep: (stepMessage) {
          if (mounted) {
            setState(() {
              _progressSteps.add(stepMessage);
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _result = result;
          _isRunning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRunning = false;
          _progressSteps.add('Error in simulation: $e');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Text(
                'REVIVE SIMULATOR',
                style: TextStyle(
                  color: Color(0xFF2563EB),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Payment Failure & Autonomous Recovery Simulator',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.memory_rounded, size: 14, color: Color(0xFF16A34A)),
                SizedBox(width: 6),
                Text(
                  'Phi-3 Mini Local Active',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF16A34A)),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subtitle Description
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Text(
                'Experience the complete autonomous recovery pipeline end-to-end: payment failure telemetry ingestion, local Phi-3 LLM classification, deterministic safety policy evaluation, recovery attempt registration, single-use smart recovery link generation, and customer payment resolution.',
                style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
              ),
            ),
            const SizedBox(height: 24),

            // Two-column layout for Wide Screens, stacked for Mobile
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 900;

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: _buildLeftControlPanel()),
                      const SizedBox(width: 24),
                      Expanded(flex: 6, child: _buildRightDiagnosticsPanel()),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildLeftControlPanel(),
                      const SizedBox(height: 24),
                      _buildRightDiagnosticsPanel(),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LEFT CONTROL PANEL: Scenarios & Action & Timeline
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildLeftControlPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Scenario Selection Header
        const Text(
          '1. CHOOSE FAILURE SCENARIO',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.8),
        ),
        const SizedBox(height: 12),

        // Scenario Preset List
        ...SimulationScenario.presets.map((scenario) => _buildScenarioTile(scenario)),
        const SizedBox(height: 20),

        // Run Simulation Action Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isRunning ? null : _runSimulation,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: _isRunning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.play_arrow_rounded, size: 20),
            label: Text(
              _isRunning ? 'RUNNING PIPELINE...' : 'RUN SIMULATION',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.5),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Progress Timeline
        if (_progressSteps.isNotEmpty) _buildProgressTimelineCard(),
      ],
    );
  }

  Widget _buildScenarioTile(SimulationScenario scenario) {
    final isSelected = _selectedScenario.id == scenario.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: InkWell(
        onTap: _isRunning
            ? null
            : () {
                setState(() {
                  _selectedScenario = scenario;
                });
              },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF8FAFC) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
              width: isSelected ? 1.8 : 1.0,
            ),
            boxShadow: isSelected
                ? const [
                    BoxShadow(color: Color(0x0C2563EB), blurRadius: 8, offset: Offset(0, 2)),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: scenario.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(scenario.icon, size: 18, color: scenario.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          scenario.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF334155),
                          ),
                        ),
                        Text(
                          '₹${scenario.amount.toStringAsFixed(0)} • ${scenario.paymentMethod}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      scenario.description,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                size: 20,
                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressTimelineCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SIMULATION PIPELINE TIMELINE',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.8),
              ),
              if (_isRunning)
                const Text(
                  'EXECUTING...',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
                )
              else
                const Text(
                  'COMPLETED',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          ...List.generate(_progressSteps.length, (index) {
            final isLast = index == _progressSteps.length - 1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isLast && _isRunning ? Icons.hourglass_top_rounded : Icons.check_circle_rounded,
                    size: 15,
                    color: isLast && _isRunning ? const Color(0xFF2563EB) : const Color(0xFF16A34A),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _progressSteps[index],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isLast ? FontWeight.w700 : FontWeight.w500,
                        color: isLast && _isRunning ? const Color(0xFF2563EB) : const Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RIGHT DIAGNOSTICS PANEL: AI Insight, Policy, Link Preview & Summary
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildRightDiagnosticsPanel() {
    if (_result == null && !_isRunning) {
      return Container(
        height: 380,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Icon(Icons.play_circle_outline_rounded, size: 28, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select a scenario and click RUN SIMULATION',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 6),
            const Text(
              'The live telemetry, local AI classification, policy evaluation, and recovery link will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      );
    }

    if (_result == null && _isRunning) {
      return Container(
        height: 380,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircularProgressIndicator(color: Color(0xFF2563EB)),
            SizedBox(height: 16),
            Text(
              'Orchestrating autonomous recovery pipeline...',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
            ),
          ],
        ),
      );
    }

    final res = _result!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AI Failure Intelligence Panel
        _buildAIInsightPanel(res),
        const SizedBox(height: 18),

        // Governed Recovery Strategy Panel
        _buildStrategyPanel(res),
        const SizedBox(height: 18),

        // Customer Recovery Link Preview Card
        _buildCustomerLinkPreviewCard(res),
        const SizedBox(height: 18),

        // End-to-End Summary Result Card
        _buildResultSummaryCard(res),
      ],
    );
  }

  Widget _buildAIInsightPanel(SimulationRunResult res) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
                  Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFF6366F1)),
                  SizedBox(width: 8),
                  Text(
                    'AI FAILURE INTELLIGENCE',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF6366F1), letterSpacing: 0.8),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Phi-3 Mini',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF4F46E5)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Diagnostic Data Grid
          Row(
            children: [
              Expanded(child: _buildInfoItem('Failure Category', res.aiDecision.category, isBold: true)),
              Expanded(child: _buildInfoItem('AI Recommendation', res.aiDecision.recommendedStrategy, isBold: true)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildInfoItem('Policy Evaluation', res.recoveryDecision.policyStatus, isBold: true)),
              Expanded(child: _buildInfoItem('Prompt Version', 'revive-payment-classifier-v1')),
            ],
          ),
          const SizedBox(height: 14),

          // Invariant Callout
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: const [
                Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF64748B)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI recommendation is advisory. Deterministic safety policy controls execution.',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrategyPanel(SimulationRunResult res) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'GOVERNED RECOVERY STRATEGY',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.8),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: res.isBlocked ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  res.recoveryDecision.policyStatus,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: res.isBlocked ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _buildInfoItem('Selected Strategy', res.recoveryDecision.strategy, isBold: true)),
              Expanded(child: _buildInfoItem('Execution Mode', 'SIMULATED')),
              Expanded(child: _buildInfoItem('Attempt Count', '1 / 3')),
            ],
          ),
          const SizedBox(height: 8),
          _buildInfoItem('Safety Reason', res.recoveryDecision.reason),
        ],
      ),
    );
  }

  Widget _buildCustomerLinkPreviewCard(SimulationRunResult res) {
    final hasLink = !res.isBlocked && res.recoverySessionId != null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.link_rounded, size: 18, color: Color(0xFF16A34A)),
              SizedBox(width: 8),
              Text(
                'CUSTOMER RECOVERY LINK',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF16A34A), letterSpacing: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            hasLink
                ? 'A cryptographically hashed recovery session was generated. Click below to preview the customer-facing recovery UI.'
                : 'Recovery session generation is blocked by policy for this safety tier.',
            style: const TextStyle(fontSize: 12, color: Color(0xFF14532D)),
          ),
          const SizedBox(height: 14),
          if (hasLink)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => CustomerRecoveryScreen(
                        sessionId: res.recoverySessionId!,
                        token: 'tok_sim_sec',
                        simulated: true,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('OPEN CUSTOMER RECOVERY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResultSummaryCard(SimulationRunResult res) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SIMULATION SUMMARY',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.8),
              ),
              Text(
                'Time: ${res.durationSeconds.toStringAsFixed(2)}s',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Payment Amount:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              Text('₹${res.transaction.amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Failure Scenario:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              Text(res.scenario.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Strategy / Policy:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              Text('${res.recoveryDecision.strategy} (${res.recoveryDecision.policyStatus})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Final Status:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              Text(
                res.isBlocked ? 'BLOCKED' : 'READY FOR RECOVERY ✓',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: res.isBlocked ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, {bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}
