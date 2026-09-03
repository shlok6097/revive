import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../features/auth/login/login_screen.dart';
import '../features/auth/signup/signup_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/recovery/customer_recovery_screen.dart';
import '../services/auth_service.dart';

/// Central routing configuration and route-guarding for the Revive application.
class AppRoutes {
  AppRoutes._();

  static const String root = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String dashboard = '/dashboard';
  static const String transactions = '/transactions';
  static const String recovery = '/recovery';
  static const String simulator = '/simulator';
  static const String settings = '/settings';
  static const String recover = '/recover';

  /// Application named routes map.
  static final Map<String, WidgetBuilder> routes = {
    root: (context) => const AuthGate(),
    login: (context) => const LoginScreen(),
    signup: (context) => const SignupScreen(),
    dashboard: (context) => const DashboardScreen(initialRoute: dashboard),
    transactions: (context) => const DashboardScreen(initialRoute: transactions),
    recovery: (context) => const DashboardScreen(initialRoute: recovery),
    simulator: (context) => const DashboardScreen(initialRoute: simulator),
    settings: (context) => const DashboardScreen(initialRoute: settings),
    recover: (context) => const CustomerRecoveryScreen(),
  };

  /// Dynamic route generator for handling deep links (e.g. /recover/:sessionId?token=...).
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final name = settings.name ?? '';
    final uri = Uri.tryParse(name);

    if (uri != null && uri.path.startsWith('/recover')) {
      final segments = uri.pathSegments;
      String? sessionId;
      if (segments.length >= 2) {
        sessionId = segments[1];
      }
      final token = uri.queryParameters['token'];

      return MaterialPageRoute<dynamic>(
        settings: settings,
        builder: (context) => CustomerRecoveryScreen(
          sessionId: sessionId,
          token: token,
        ),
      );
    }

    final builder = routes[name];
    if (builder != null) {
      return MaterialPageRoute<dynamic>(
        settings: settings,
        builder: builder,
      );
    }

    return null;
  }
}

/// Authentication gate widget ensuring protected merchant access.
///
/// If an active Firebase session exists, routes directly to [DashboardScreen].
/// Otherwise, presents the [LoginScreen].
class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    this.authService,
  });

  final AuthService? authService;

  @override
  Widget build(BuildContext context) {
    final service = authService ?? AuthService();

    return StreamBuilder<User?>(
      stream: service.authStateChanges,
      builder: (context, snapshot) {
        // While Firebase is restoring cached session tokens
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF8FAFC),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: Color(0xFF2563EB),
                    strokeWidth: 3,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Initializing Revive Session...',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // If authenticated, grant access to Dashboard
        if (snapshot.hasData && snapshot.data != null) {
          return const DashboardScreen();
        }

        // Otherwise, enforce merchant sign-in
        return const LoginScreen();
      },
    );
  }
}
