import 'package:flutter/material.dart';
import '../models/recovery_analytics.dart';

/// Card rendering the 5-stage autonomous recovery conversion funnel.
class RecoveryFunnelCard extends StatelessWidget {
  const RecoveryFunnelCard({
    super.key,
    required this.funnelData,
  });

  final RecoveryFunnelData funnelData;

  @override
  Widget build(BuildContext context) {
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
                    child: const Icon(Icons.filter_alt_rounded, size: 20, color: Color(0xFF16A34A)),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'CONVERSION FUNNEL',
                        style: TextStyle(
                          fontSize: 11.0,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF94A3B8),
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        'Recovery Funnel',
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${funnelData.recoveryRate.toStringAsFixed(1)}% Yield',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          _buildFunnelStage(
            stepNumber: '1',
            label: 'Failed Payments',
            subtitle: 'Ingested via webhook telemetry',
            count: funnelData.failedPayments,
            rate: '100%',
            color: const Color(0xFFEF4444),
            barWidthFactor: 1.0,
          ),
          _buildFunnelConnector(),
          _buildFunnelStage(
            stepNumber: '2',
            label: 'AI Classified',
            subtitle: 'Analyzed by local Phi-3 Mini',
            count: funnelData.aiClassified,
            rate: '${funnelData.classificationRate.toStringAsFixed(0)}%',
            color: const Color(0xFF6366F1),
            barWidthFactor: 0.88,
          ),
          _buildFunnelConnector(),
          _buildFunnelStage(
            stepNumber: '3',
            label: 'Recovery Eligible',
            subtitle: 'Passed deterministic policy rules',
            count: funnelData.recoveryEligible,
            rate: '${funnelData.eligibilityRate.toStringAsFixed(0)}%',
            color: const Color(0xFF2563EB),
            barWidthFactor: 0.74,
          ),
          _buildFunnelConnector(),
          _buildFunnelStage(
            stepNumber: '4',
            label: 'Recovery Attempted',
            subtitle: 'Customer link or retry orchestrated',
            count: funnelData.recoveryAttempted,
            rate: '${funnelData.attemptRate.toStringAsFixed(0)}%',
            color: const Color(0xFFD97706),
            barWidthFactor: 0.60,
          ),
          _buildFunnelConnector(),
          _buildFunnelStage(
            stepNumber: '5',
            label: 'Recovered & Reconciled',
            subtitle: 'Confirmed payment success',
            count: funnelData.recovered,
            rate: '${funnelData.recoveryRate.toStringAsFixed(0)}%',
            color: const Color(0xFF16A34A),
            barWidthFactor: 0.48,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildFunnelStage({
    required String stepNumber,
    required String label,
    required String subtitle,
    required int count,
    required String rate,
    required Color color,
    required double barWidthFactor,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              stepNumber,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$count',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color),
              ),
              Text(
                rate,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFunnelConnector() {
    return Container(
      height: 10,
      alignment: Alignment.centerLeft,
      margin: const EdgeInsets.only(left: 22),
      child: Container(
        width: 2,
        height: 10,
        color: const Color(0xFFCBD5E1),
      ),
    );
  }
}
