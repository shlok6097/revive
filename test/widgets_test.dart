import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revive/app/routes.dart';
import 'package:revive/features/auth/login/login_screen.dart';
import 'package:revive/features/auth/signup/signup_screen.dart';
import 'package:revive/features/dashboard/dashboard_screen.dart';
import 'package:revive/models/merchant.dart';
import 'package:revive/repositories/merchant_repository.dart';
import 'package:revive/services/auth_service.dart';
import 'package:revive/widgets/dashboard_sidebar.dart';
import 'package:revive/widgets/metric_card.dart';
import 'package:revive/widgets/status_badge.dart';

class MockAuthService extends AuthService {
  MockAuthService({this.initialUser});

  final User? initialUser;

  @override
  Stream<User?> get authStateChanges => Stream<User?>.value(initialUser);

  @override
  User? get currentUser => initialUser;

  @override
  bool get isAuthenticated => initialUser != null;

  @override
  Future<void> signOut() async {}
}

class MockMerchantRepository extends MerchantRepository {
  MockMerchantRepository({this.mockMerchant});

  final Merchant? mockMerchant;

  @override
  Future<Merchant?> getMerchantProfile(String merchantId) async {
    return mockMerchant ??
        Merchant(
          id: merchantId,
          name: 'Test Merchant Corp',
          email: 'test@merchant.com',
          autonomyMode: 'SEMI_AUTONOMOUS',
          createdAt: DateTime.now(),
        );
  }

  @override
  Future<void> createMerchantProfile(Merchant merchant) async {}
}

void main() {
  group('UI Widgets Tests', () {
    testWidgets('StatusBadge renders correct status and styling', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusBadge(status: 'RECOVERED'),
          ),
        ),
      );

      expect(find.text('RECOVERED'), findsOneWidget);
    });

    testWidgets('MetricCard displays title, value, and trend', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MetricCard(
              title: 'Total Volume',
              value: '₹24,85,200',
              trendText: '+14.2%',
              icon: Icons.account_balance_wallet,
            ),
          ),
        ),
      );

      expect(find.text('TOTAL VOLUME'), findsOneWidget);
      expect(find.text('₹24,85,200'), findsOneWidget);
      expect(find.text('+14.2%'), findsOneWidget);
    });

    testWidgets('DashboardSidebar renders items and merchant info', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardSidebar(
              activeRoute: '/dashboard',
              onNavigate: (_) {},
              merchant: Merchant(
                id: 'uid_test',
                name: 'Acme Merchant',
                email: 'acme@revive.io',
                createdAt: DateTime.now(),
              ),
              onSignOut: () {},
            ),
          ),
        ),
      );

      expect(find.text('REVIVE'), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Transactions'), findsOneWidget);
      expect(find.text('Recovery'), findsOneWidget);
      expect(find.text('Simulator'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Acme Merchant'), findsOneWidget);
    });

    testWidgets('LoginScreen renders fields and validates empty inputs', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(authService: MockAuthService()),
        ),
      );

      expect(find.text('REVIVE'), findsOneWidget);
      expect(find.text('Merchant Sign In'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));

      // Tap Sign In without filling form
      await tester.tap(find.text('Sign In to Dashboard'));
      await tester.pumpAndSettle();

      expect(find.text('Email address is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('SignupScreen validates business name and matching passwords', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SignupScreen(
            authService: MockAuthService(),
            merchantRepository: MockMerchantRepository(),
          ),
        ),
      );

      expect(find.text('Create Your Merchant Account'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(4));

      // Tap Submit without filling form
      await tester.tap(find.text('Complete Registration'));
      await tester.pumpAndSettle();

      expect(find.text('Business name is required'), findsOneWidget);
      expect(find.text('Email address is required'), findsOneWidget);
    });

    testWidgets('DashboardScreen renders fintech metrics and recent transactions table', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            authService: MockAuthService(),
            merchantRepository: MockMerchantRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('REVIVE'), findsOneWidget);
      expect(find.text('LIVE BANKING NETWORK TELEMETRY'), findsOneWidget);
      expect(find.text('Recent Transactions & Recovery Stream'), findsOneWidget);
      expect(find.text('tx_rv_982401'), findsOneWidget);
    });

    testWidgets('AuthGate presents LoginScreen when unauthenticated', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(authService: MockAuthService(initialUser: null)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Merchant Sign In'), findsOneWidget);
    });
  });
}
