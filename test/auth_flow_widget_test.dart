import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_job_connector/app/theme.dart';
import 'package:local_job_connector/core/models/user_model.dart';
import 'package:local_job_connector/core/providers/auth_provider.dart';
import 'package:local_job_connector/core/providers/chat_provider.dart';
import 'package:local_job_connector/core/providers/job_provider.dart';
import 'package:local_job_connector/core/repositories/chat_repository.dart';
import 'package:local_job_connector/core/repositories/job_repository.dart';
import 'package:local_job_connector/core/repositories/user_repository.dart';
import 'package:local_job_connector/features/auth/screens/login_screen.dart';
import 'package:local_job_connector/features/auth/screens/profile_screen.dart';
import 'package:provider/provider.dart';

Widget createTestApp(
  Widget homeWidget, {
  AuthProvider? auth,
  JobProvider? job,
  ChatProvider? chat,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>(
        create: (_) =>
            auth ??
            AuthProvider(
              userRepository: InMemoryUserRepository(),
              startAuthenticated: true,
            ),
      ),
      ChangeNotifierProvider<JobProvider>(
        create: (_) =>
            job ?? JobProvider(jobRepository: InMemoryJobRepository()),
      ),
      ChangeNotifierProvider<ChatProvider>(
        create: (_) =>
            chat ?? ChatProvider(chatRepository: InMemoryChatRepository()),
      ),
    ],
    child: MaterialApp(theme: AppTheme.lightTheme, home: homeWidget),
  );
}

void main() {
  group('LoginScreen Widget Tests', () {
    testWidgets('Renders LoginScreen initial UI in Sign In mode', (
      WidgetTester tester,
    ) async {
      final authProvider = AuthProvider(
        userRepository: InMemoryUserRepository(),
        startAuthenticated: false,
      );

      await tester.pumpWidget(
        createTestApp(const LoginScreen(), auth: authProvider),
      );
      await tester.pumpAndSettle();

      expect(find.text('Local Job Connector'), findsOneWidget);
      expect(
        find.text('Sign in to access local gig opportunities in Ghana'),
        findsOneWidget,
      );
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text("Don't have an account? Register Now"), findsOneWidget);
    });

    testWidgets('Form validation on empty email and short password', (
      WidgetTester tester,
    ) async {
      final authProvider = AuthProvider(
        userRepository: InMemoryUserRepository(),
        startAuthenticated: false,
      );

      await tester.pumpWidget(
        createTestApp(const LoginScreen(), auth: authProvider),
      );
      await tester.pumpAndSettle();

      // Tap Sign In without filling form
      await tester.ensureVisible(find.text('Sign In'));
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Enter valid email'), findsOneWidget);
      expect(find.text('Password must be at least 6 chars'), findsOneWidget);
    });

    testWidgets(
      'Toggle between Sign In and Sign Up mode with phone validation',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final authProvider = AuthProvider(
          userRepository: InMemoryUserRepository(),
          startAuthenticated: false,
        );

        await tester.pumpWidget(
          createTestApp(const LoginScreen(), auth: authProvider),
        );
        await tester.pumpAndSettle();

        // Switch to Sign Up mode
        await tester.ensureVisible(
          find.text("Don't have an account? Register Now"),
        );
        await tester.tap(find.text("Don't have an account? Register Now"));
        await tester.pumpAndSettle();

        expect(find.text('Full Name'), findsOneWidget);
        expect(find.text('Phone Number'), findsOneWidget);
        expect(find.text('Create Account'), findsOneWidget);

        // Enter invalid phone
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Full Name'),
          'Ama Mensah',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Phone Number'),
          '12345',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Email Address'),
          'ama@gmail.com',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'),
          '123456',
        );

        await tester.ensureVisible(find.text('Create Account'));
        await tester.tap(find.text('Create Account'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Enter valid Ghana phone'), findsOneWidget);

        // Enter valid Ghana phone
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Phone Number'),
          '+233 24 123 4567',
        );
        await tester.ensureVisible(find.text('Create Account'));
        await tester.tap(find.text('Create Account'));
        await tester.pumpAndSettle();

        expect(authProvider.isAuthenticated, true);
      },
    );

    testWidgets('Google sign in button triggers authentication', (
      WidgetTester tester,
    ) async {
      final authProvider = AuthProvider(
        userRepository: InMemoryUserRepository(),
        startAuthenticated: false,
      );

      await tester.pumpWidget(
        createTestApp(const LoginScreen(), auth: authProvider),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Continue with Google'));
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(authProvider.isAuthenticated, true);
      expect(authProvider.authMethod, 'google');
    });
  });

  group('ProfileScreen Widget Tests', () {
    testWidgets(
      'Renders ProfileScreen with student attribution and role toggle',
      (WidgetTester tester) async {
        final authProvider = AuthProvider(
          userRepository: InMemoryUserRepository(),
          startAuthenticated: true,
        );
        final jobProvider = JobProvider(jobRepository: InMemoryJobRepository());

        await tester.pumpWidget(
          createTestApp(
            const ProfileScreen(),
            auth: authProvider,
            job: jobProvider,
          ),
        );
        await tester.pumpAndSettle();

        // Check header info
        expect(find.text('Kofi Mensah'), findsOneWidget);
        expect(find.text('+233 24 123 4567'), findsOneWidget);
        expect(find.text('kofi.mensah@gmail.com'), findsOneWidget);

        // Check UG Academic Project Attribution
        expect(find.textContaining('Emmanuel Duodu Osae'), findsOneWidget);
        expect(find.textContaining('11012457'), findsOneWidget);
        expect(find.textContaining('University of Ghana'), findsOneWidget);
        expect(find.textContaining('Accra, Kumasi, & Tema'), findsOneWidget);

        // Verify Role Switcher
        expect(find.text('Job Seeker'), findsOneWidget);
        expect(find.text('Employer / Poster'), findsOneWidget);

        // Switch to Employer
        await tester.ensureVisible(find.text('Employer / Poster'));
        await tester.tap(find.text('Employer / Poster'));
        await tester.pumpAndSettle();

        expect(jobProvider.currentUserRole, UserRole.poster);
        expect(authProvider.currentUser!.role, UserRole.poster);

        // Switch back to Job Seeker
        await tester.ensureVisible(find.text('Job Seeker'));
        await tester.tap(find.text('Job Seeker'));
        await tester.pumpAndSettle();

        expect(jobProvider.currentUserRole, UserRole.seeker);
        expect(authProvider.currentUser!.role, UserRole.seeker);
      },
    );

    testWidgets('Sign Out button signs out and navigates to LoginScreen', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final authProvider = AuthProvider(
        userRepository: InMemoryUserRepository(),
        startAuthenticated: true,
      );

      await tester.pumpWidget(
        createTestApp(const ProfileScreen(), auth: authProvider),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Sign Out of Account'));
      await tester.tap(find.text('Sign Out of Account'));
      await tester.pumpAndSettle();

      expect(authProvider.isAuthenticated, false);
      expect(find.text('Local Job Connector'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
    });
  });
}
