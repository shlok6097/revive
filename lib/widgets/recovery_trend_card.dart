import 'dart:math';
import 'package:flutter/material.dart';
import '../models/recovery_analytics.dart';

/// Card rendering a responsive daily time-series chart of failed vs recovered payments.
class RecoveryTrendCard extends StatelessWidget {
  const RecoveryTrendCard({
    super.key,
    required this.trends,
  });

  final List<DailyRecoveryTrend> trends;

  @override
  Widget build(BuildContext context) {
    final maxCount = trends.fold<int>(1, (prev, t) => max(prev, max(t.failedCount + t.recoveredCount, 1)));
    final totalRecovered = trends.fold<int>(0, (sum, t) => sum + t.recoveredCount);
    final totalFailed = trends.fold<int>(0, (sum, t) => sum + t.failedCount);
    final totalRecoveredAmount = trends.fold<double>(0.0, (sum, t) => sum + t.recoveredAmount);

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
          // Header Row
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
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.show_chart_rounded, size: 20, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'RECOVERY PERFORMANCE',
                        style: TextStyle(
                          fontSize: 11.0,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF94A3B8),
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        '7-Day Recovery Trend',
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
                  _buildLegendItem('Failed', const Color(0xFFEF4444)),
                  const SizedBox(width: 12),
                  _buildLegendItem('Recovered', const Color(0xFF16A34A)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Mini Summary Stats
          Row(
            children: [
              _buildMiniStat('Total Recovered (7d)', '$totalRecovered txns', const Color(0xFF16A34A)),
              const SizedBox(width: 20),
              _buildMiniStat('Recovered Value', '₹${totalRecoveredAmount.toStringAsFixed(0)}', const Color(0xFF0F172A)),
              const SizedBox(width: 20),
              _buildMiniStat('Active Failure Load', '$totalFailed txns', const Color(0xFFEF4444)),
            ],
          ),
          const SizedBox(height: 24),

          // Chart Area
          if (trends.isEmpty)
            Container(
              height: 160,
              alignment: Alignment.center,
              child: const Text(
                'No transaction history for the past 7 days.',
                style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              ),
            )
          else
            SizedBox(
              height: 160,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: trends.map((trend) => _buildDayColumn(trend, maxCount)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDayColumn(DailyRecoveryTrend trend, int maxCount) {
    const maxHeight = 100.0;
    final total = trend.failedCount + trend.recoveredCount;

    final failedHeight = total > 0 ? (trend.failedCount / maxCount) * maxHeight : 4.0;
    final recoveredHeight = total > 0 ? (trend.recoveredCount / maxCount) * maxHeight : 4.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Rate badge
        if (trend.recoveredCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Text(
              '${trend.recoveryRate.toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
            ),
          )
        else
          const SizedBox(height: 18),

        // Bars Group
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 14,
              height: max(failedHeight, 4.0),
              decoration: BoxDecoration(
                color: trend.failedCount > 0 ? const Color(0xFFEF4444) : const Color(0xFFF1F5F9),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
              ),
            ),
            const SizedBox(width: 3),
            Container(
              width: 14,
              height: max(recoveredHeight, 4.0),
              decoration: BoxDecoration(
                color: trend.recoveredCount > 0 ? const Color(0xFF16A34A) : const Color(0xFFF1F5F9),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Date Label
        Text(
          trend.label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _buildMiniStat(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: valueColor)),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
      ],
    );
  }
}
