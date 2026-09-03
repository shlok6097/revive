import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../features/auth/login/login_screen.dart';
import '../features/auth/signup/signup_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
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
  };
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
