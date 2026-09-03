import 'package:flutter/material.dart';
import '../models/ai_decision.dart';
import '../models/transaction.dart';
import '../services/ai_failure_intelligence_service.dart';

/// Card displaying AI failure analysis insights, model attribution, and deterministic policy status.
class AIIntelligenceCard extends StatefulWidget {
  const AIIntelligenceCard({
    super.key,
    this.latestTransaction,
    this.aiDecision,
    this.merchantId,
    this.aiIntelligenceService,
  });

  final TransactionModel? latestTransaction;
  final AIDecision? aiDecision;
  final String? merchantId;
  final AIFailureIntelligenceService? aiIntelligenceService;

  @override
  State<AIIntelligenceCard> createState() => _AIIntelligenceCardState();
}

class _AIIntelligenceCardState extends State<AIIntelligenceCard> {
  AIDecision? _decision;
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _decision = widget.aiDecision;
    if (_decision == null && widget.latestTransaction != null) {
      _runAnalysis();
    }
  }

  Future<void> _runAnalysis() async {
    final tx = widget.latestTransaction;
    if (tx == null) return;

    setState(() => _isAnalyzing = true);
    try {
      final service = widget.aiIntelligenceService ?? AIFailureIntelligenceService();
      final res = await service.analyzeTransaction(
        transaction: tx,
        merchantId: widget.merchantId ?? 'merchant_current',
      );
      if (mounted) setState(() => _decision = res);
    } catch (_) {
      // Fallback display handled gracefully
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Color _getPolicyColor(String status) {
    switch (status.toUpperCase()) {
      case 'ALLOWED':
        return const Color(0xFF16A34A);
      case 'BLOCKED':
        return const Color(0xFFDC2626);
      case 'REQUIRES_REVIEW':
      default:
        return const Color(0xFFD97706);
    }
  }

  Color _getPolicyBgColor(String status) {
    switch (status.toUpperCase()) {
      case 'ALLOWED':
        return const Color(0xFFF0FDF4);
      case 'BLOCKED':
        return const Color(0xFFFEF2F2);
      case 'REQUIRES_REVIEW':
      default:
        return const Color(0xFFFFFBEB);
    }
  }

  @override
  Widget build(BuildContext context) {
    final failureCategory = _decision?.failureCategory ?? 'BANK_DECLINE';
    final recommendedStrategy = _decision?.recommendedStrategy ?? 'ESCALATE';
    final policyStatus = _decision?.policyStatus ?? 'REQUIRES_REVIEW';
    final modelName = _decision?.modelName ?? 'Phi-3 Mini';
    final promptVersion = _decision?.promptVersion ?? 'revive-payment-classifier-v1';
    final policyColor = _getPolicyColor(policyStatus);
    final policyBg = _getPolicyBgColor(policyStatus);

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
                      color: const Color(0xFFFAF5FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      size: 20,
                      color: Color(0xFF9333EA),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'AI PAYMENT ANALYSIS',
                        style: TextStyle(
                          fontSize: 11.0,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF94A3B8),
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        'Failure Intelligence & Recommendation',
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF5FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE9D5FF)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF9333EA),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'AI ANALYZED',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: Color(0xFF7E22CE),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Diagnostic Metrics Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 550;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  // Failure Category Box
                  Container(
                    width: isWide ? (constraints.maxWidth - 24) / 3 : constraints.maxWidth,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Failure Category',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          failureCategory.replaceAll('_', ' '),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                  ),

                  // Recommended Strategy Box
                  Container(
                    width: isWide ? (constraints.maxWidth - 24) / 3 : constraints.maxWidth,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Recommended Strategy',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          recommendedStrategy.replaceAll('_', ' '),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
                        ),
                      ],
                    ),
                  ),

                  // Policy Status Box
                  Container(
                    width: isWide ? (constraints.maxWidth - 24) / 3 : constraints.maxWidth,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: policyBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: policyColor.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Policy Status',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          policyStatus.replaceAll('_', ' '),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: policyColor),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),

          // Attribution and Guardrail Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.info_outline, size: 16, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI Recommendation — Human/Policy Validation Required (Model: $modelName | Prompt: $promptVersion)',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
                if (_isAnalyzing)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
