import 'package:flutter/material.dart';

/// Reusable fintech dashboard metric card displaying KPIs, values, and trends.
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.trendText,
    this.isPositiveTrend = true,
    required this.icon,
    this.iconColor = const Color(0xFF1E88E5),
  });

  /// Metric title / KPI name (e.g. 'Total Volume').
  final String title;

  /// Primary formatted metric value (e.g. '₹24,85,200').
  final String value;

  /// Secondary explanatory note (e.g. '36 recovered transactions').
  final String? subtitle;

  /// Trend percentage or delta string (e.g. '+12.4% this month').
  final String? trendText;

  /// Whether the trend represents positive growth.
  final bool isPositiveTrend;

  /// Display icon representing the KPI.
  final IconData icon;

  /// Color accent for the icon badge.
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: Color(0xFF6B7280),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Icon(
                  icon,
                  size: 18.0,
                  color: iconColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24.0,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8.0),
          if (trendText != null || subtitle != null)
            Row(
              children: [
                if (trendText != null) ...[
                  Icon(
                    isPositiveTrend ? Icons.trending_up : Icons.trending_down,
                    size: 16.0,
                    color: isPositiveTrend ? const Color(0xFF1E7E34) : const Color(0xFFD32F2F),
                  ),
                  const SizedBox(width: 4.0),
                  Text(
                    trendText!,
                    style: TextStyle(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w600,
                      color: isPositiveTrend ? const Color(0xFF1E7E34) : const Color(0xFFD32F2F),
                    ),
                  ),
                  const SizedBox(width: 6.0),
                ],
                if (subtitle != null)
                  Expanded(
                    child: Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.0,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
