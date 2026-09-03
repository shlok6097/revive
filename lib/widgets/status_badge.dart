import 'package:flutter/material.dart';

/// Renders a modern, semantic status badge for transaction and system states.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  /// Transaction or entity status ('SUCCESS', 'FAILED', 'PENDING', 'RECOVERED').
  final String status;

  /// Whether to render a smaller padding variant.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toUpperCase().trim();
    final config = _getStatusConfig(normalized);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8.0 : 10.0,
        vertical: compact ? 3.0 : 5.0,
      ),
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(
          color: config.borderColor,
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: config.textColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            normalized,
            style: TextStyle(
              color: config.textColor,
              fontSize: compact ? 11.0 : 12.0,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  _StatusConfig _getStatusConfig(String status) {
    switch (status) {
      case 'SUCCESS':
        return const _StatusConfig(
          backgroundColor: Color(0xFFEDF7EE),
          textColor: Color(0xFF1E7E34),
          borderColor: Color(0xFFC3E6CB),
        );
      case 'RECOVERED':
        return const _StatusConfig(
          backgroundColor: Color(0xFFE8F4FD),
          textColor: Color(0xFF0D6EFD),
          borderColor: Color(0xFFB8DAFF),
        );
      case 'FAILED':
        return const _StatusConfig(
          backgroundColor: Color(0xFFFDECEA),
          textColor: Color(0xFFD32F2F),
          borderColor: Color(0xFFF5C6CB),
        );
      case 'PENDING':
      case 'INITIATED':
      case 'IN_PROGRESS':
        return const _StatusConfig(
          backgroundColor: Color(0xFFFFF8E1),
          textColor: Color(0xFFF57F17),
          borderColor: Color(0xFFFFEEBA),
        );
      default:
        return const _StatusConfig(
          backgroundColor: Color(0xFFF5F5F5),
          textColor: Color(0xFF616161),
          borderColor: Color(0xFFE0E0E0),
        );
    }
  }
}

class _StatusConfig {
  const _StatusConfig({
    required this.backgroundColor,
    required this.textColor,
    required this.borderColor,
  });

  final Color backgroundColor;
  final Color textColor;
  final Color borderColor;
}
