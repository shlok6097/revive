import 'package:flutter/material.dart';

/// Central routing definitions for the Revive application.
class AppRoutes {
  AppRoutes._();

  static const String initial = dashboard;

  static const String auth = '/auth';
  static const String dashboard = '/dashboard';
  static const String transactions = '/transactions';
  static const String recovery = '/recovery';
  static const String simulator = '/simulator';
  static const String settings = '/settings';

  /// Map of route names to their placeholder builder widgets.
  /// Feature screens will replace these placeholders in subsequent phases.
  static final Map<String, WidgetBuilder> routes = {
    auth: (context) => const _RoutePlaceholder(title: 'Auth'),
    dashboard: (context) => const _RoutePlaceholder(title: 'Dashboard'),
    transactions: (context) => const _RoutePlaceholder(title: 'Transactions'),
    recovery: (context) => const _RoutePlaceholder(title: 'Recovery'),
    simulator: (context) => const _RoutePlaceholder(title: 'Simulator'),
    settings: (context) => const _RoutePlaceholder(title: 'Settings'),
  };
}

/// Minimal placeholder screen used strictly for routing scaffolding in Phase 1.
class _RoutePlaceholder extends StatelessWidget {
  const _RoutePlaceholder({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: Text(
          'Revive $title Placeholder',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}
