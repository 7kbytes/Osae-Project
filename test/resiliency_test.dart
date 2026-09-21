import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_job_connector/app/theme.dart';
import 'package:local_job_connector/core/providers/application_provider.dart';
import 'package:local_job_connector/core/providers/auth_provider.dart';
import 'package:local_job_connector/core/providers/chat_provider.dart';
import 'package:local_job_connector/core/providers/connectivity_provider.dart';
import 'package:local_job_connector/core/providers/job_provider.dart';
import 'package:local_job_connector/core/repositories/application_repository.dart';
import 'package:local_job_connector/core/repositories/chat_repository.dart';
import 'package:local_job_connector/core/repositories/job_repository.dart';
import 'package:local_job_connector/core/repositories/user_repository.dart';
import 'package:local_job_connector/core/services/connectivity_service.dart';
import 'package:local_job_connector/core/utils/form_validators.dart';
import 'package:local_job_connector/core/utils/input_sanitizer.dart';
import 'package:local_job_connector/core/widgets/global_error_boundary.dart';
import 'package:local_job_connector/core/widgets/offline_banner.dart';
import 'package:local_job_connector/core/widgets/safe_image.dart';
import 'package:local_job_connector/features/jobs/screens/job_detail_screen.dart';
import 'package:local_job_connector/features/map/screens/map_view_screen.dart';
import 'package:provider/provider.dart';

Widget buildResiliencyTestApp(
  Widget child, {
  ConnectivityProvider? connectivityProvider,
  JobProvider? jobProvider,
  AuthProvider? authProvider,
  ApplicationProvider? applicationProvider,
  ChatProvider? chatProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ConnectivityProvider>(
        create: (_) => connectivityProvider ?? ConnectivityProvider(),
      ),
      ChangeNotifierProvider<JobProvider>(
        create: (_) =>
            jobProvider ?? JobProvider(jobRepository: InMemoryJobRepository()),
      ),
      ChangeNotifierProvider<AuthProvider>(
        create: (_) =>
            authProvider ??
            AuthProvider(
              userRepository: InMemoryUserRepository(),
              startAuthenticated: true,
            ),
      ),
      ChangeNotifierProvider<ApplicationProvider>(
        create: (_) =>
            applicationProvider ??
            ApplicationProvider(
              applicationRepository: InMemoryApplicationRepository(),
            ),
      ),
      ChangeNotifierProvider<ChatProvider>(
        create: (_) =>
            chatProvider ??
            ChatProvider(chatRepository: InMemoryChatRepository()),
      ),
    ],
    child: MaterialApp(theme: AppTheme.lightTheme, home: child),
  );
}

void main() {
  group('1. FormValidators Unit Tests', () {
    test('validateEmail validates valid and invalid email addresses', () {
      // Valid emails
      expect(FormValidators.validateEmail('user@example.com'), isNull);
      expect(FormValidators.validateEmail('kofi.mensah@ug.edu.gh'), isNull);
      expect(FormValidators.validateEmail('developer+test@osae.org'), isNull);
      expect(FormValidators.validateEmail('employer123@domain.co'), isNull);

      // Invalid emails
      expect(FormValidators.validateEmail(null), isNotNull);
      expect(FormValidators.validateEmail(''), isNotNull);
      expect(FormValidators.validateEmail('   '), isNotNull);
      expect(FormValidators.validateEmail('notanemail'), isNotNull);
      expect(FormValidators.validateEmail('user@'), isNotNull);
      expect(FormValidators.validateEmail('@domain.com'), isNotNull);
      expect(FormValidators.validateEmail('user@.com'), isNotNull);
      expect(FormValidators.validateEmail('user@domain.'), isNotNull);
      expect(FormValidators.validateEmail('user@domain.c'), isNotNull);
      expect(FormValidators.validateEmail('user@domain..com'), isNotNull);
      expect(FormValidators.validateEmail('user..name@domain.com'), isNotNull);
    });

    test('validateGhanaPhone validates Ghanaian phone formats', () {
      // Valid Ghana numbers
      expect(FormValidators.validateGhanaPhone('+233 24 123 4567'), isNull);
      expect(FormValidators.validateGhanaPhone('+233241234567'), isNull);
      expect(FormValidators.validateGhanaPhone('0241234567'), isNull);
      expect(FormValidators.validateGhanaPhone('0551234567'), isNull);
      expect(FormValidators.validateGhanaPhone('0201234567'), isNull);
      expect(FormValidators.validateGhanaPhone('0271234567'), isNull);
      expect(FormValidators.validateGhanaPhone('0501234567'), isNull);
      expect(FormValidators.validateGhanaPhone('+233-54-123-4567'), isNull);

      // Invalid phone numbers
      expect(FormValidators.validateGhanaPhone(null), isNotNull);
      expect(FormValidators.validateGhanaPhone(''), isNotNull);
      expect(FormValidators.validateGhanaPhone('12345'), isNotNull);
      expect(FormValidators.validateGhanaPhone('+1234567890'), isNotNull);
      expect(FormValidators.validateGhanaPhone('0123456789'), isNotNull);
      expect(FormValidators.validateGhanaPhone('abcdefghij'), isNotNull);
      expect(FormValidators.validateGhanaPhone('0241234'), isNotNull);
    });

    test('validatePayRate validates numeric pay constraints', () {
      // Valid pay rates
      expect(FormValidators.validatePayRate('150'), isNull);
      expect(FormValidators.validatePayRate('250.50'), isNull);
      expect(FormValidators.validatePayRate('10'), isNull);
      expect(FormValidators.validatePayRate('100000'), isNull);

      // Invalid pay rates
      expect(FormValidators.validatePayRate(null), isNotNull);
      expect(FormValidators.validatePayRate(''), isNotNull);
      expect(FormValidators.validatePayRate('   '), isNotNull);
      expect(FormValidators.validatePayRate('abc'), isNotNull);
      expect(FormValidators.validatePayRate('-50'), isNotNull);
      expect(FormValidators.validatePayRate('0'), isNotNull);
      expect(FormValidators.validatePayRate('150000'), isNotNull);
      expect(FormValidators.validatePayRate('NaN'), isNotNull);
      expect(FormValidators.validatePayRate('Infinity'), isNotNull);
      expect(FormValidators.validatePayRate('-Infinity'), isNotNull);
    });

    test('validatePassword validates length and whitespace constraints', () {
      // Valid passwords
      expect(FormValidators.validatePassword('123456'), isNull);
      expect(FormValidators.validatePassword('secure_pass_123'), isNull);

      // Invalid passwords
      expect(FormValidators.validatePassword(null), isNotNull);
      expect(FormValidators.validatePassword(''), isNotNull);
      expect(FormValidators.validatePassword('12345'), isNotNull);
      expect(FormValidators.validatePassword('      '), isNotNull);
      expect(FormValidators.validatePassword('a' * 129), isNotNull);
    });

    test('validateRequired enforces field non-emptiness and length bounds', () {
      // Valid inputs
      expect(
        FormValidators.validateRequired('Market Porter', 'Job Title'),
        isNull,
      );
      expect(
        FormValidators.validateRequired('Kwame Nkrumah Circle', 'Location'),
        isNull,
      );

      // Empty / Whitespace inputs
      expect(
        FormValidators.validateRequired(null, 'Job Title'),
        'Please enter a title',
      );
      expect(
        FormValidators.validateRequired('', 'Job Description'),
        'Please enter job description',
      );
      expect(
        FormValidators.validateRequired('   ', 'Location'),
        'Please specify location',
      );
      expect(
        FormValidators.validateRequired('', 'Full Name'),
        'Enter full name',
      );
      expect(
        FormValidators.validateRequired('', 'CustomField'),
        'CustomField is required',
      );

      // Length boundary constraints
      expect(
        FormValidators.validateRequired('ab', 'Title', minLength: 5),
        isNotNull,
      );
      expect(
        FormValidators.validateRequired('a' * 50, 'Title', maxLength: 10),
        isNotNull,
      );
    });
  });

  group('2. InputSanitizer Unit Tests', () {
    test(
      'sanitize strips script tags, HTML elements, and control characters',
      () {
        // Script stripping
        expect(
          InputSanitizer.sanitize('<script>alert("attack")</script>Hello'),
          'Hello',
        );
        expect(
          InputSanitizer.sanitize('<script src="malicious.js"></script>Safe'),
          'Safe',
        );

        // HTML stripping
        expect(InputSanitizer.sanitize('<b>Bold</b> <p>Text</p>'), 'Bold Text');

        // Javascript URI stripping
        expect(
          InputSanitizer.sanitize('javascript:doSomething()'),
          'doSomething()',
        );

        // Null byte & control character stripping
        expect(
          InputSanitizer.sanitize('Clean\x00String\x07With\x1FControl'),
          'CleanStringWithControl',
        );

        // Whitespace trimming
        expect(
          InputSanitizer.sanitize('   Clean Text Here   '),
          'Clean Text Here',
        );
      },
    );

    test('sanitizeEmail formats and lowercases email strings', () {
      expect(
        InputSanitizer.sanitizeEmail('  Kofi.Mensah@UG.EDU.GH  '),
        'kofi.mensah@ug.edu.gh',
      );
      expect(InputSanitizer.sanitizeEmail(null), '');
    });

    test('sanitizePhone cleans extraneous characters and keeps + prefix', () {
      expect(
        InputSanitizer.sanitizePhone(' +233 (24) 123-4567 '),
        '+233241234567',
      );
      expect(InputSanitizer.sanitizePhone('024 123 4567'), '0241234567');
      expect(InputSanitizer.sanitizePhone(null), '');
    });

    test('sanitizeNumeric retains only digits and a single decimal point', () {
      expect(InputSanitizer.sanitizeNumeric(' 250.50 GHS '), '250.50');
      expect(InputSanitizer.sanitizeNumeric('12.34.56'), '12.3456');
      expect(InputSanitizer.sanitizeNumeric(null), '');
    });
  });

  group('3. ConnectivityProvider & OfflineBanner Widget Tests', () {
    testWidgets(
      'OfflineBanner hides when online and displays banner when offline',
      (WidgetTester tester) async {
        final connectivity = ConnectivityProvider(initialOnline: true);

        await tester.pumpWidget(
          buildResiliencyTestApp(
            const OfflineBanner(
              child: Scaffold(body: Center(child: Text('Main App Content'))),
            ),
            connectivityProvider: connectivity,
          ),
        );
        await tester.pumpAndSettle();

        // When online: main content visible, no offline banner container rendered
        expect(find.text('Main App Content'), findsOneWidget);
        expect(find.byKey(const Key('offline_banner_container')), findsNothing);

        // Transition to offline
        connectivity.setOnline(false);
        await tester.pumpAndSettle();

        // When offline: offline banner is rendered with warning text and icon
        expect(
          find.byKey(const Key('offline_banner_container')),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
        expect(find.textContaining('Offline Mode'), findsOneWidget);

        // Transition back to online
        connectivity.setOnline(true);
        await tester.pumpAndSettle();

        // Banner should disappear
        expect(find.byKey(const Key('offline_banner_container')), findsNothing);
      },
    );

    test('ConnectivityService broadcasts updates to listeners', () async {
      final service = ConnectivityService();
      expect(service.isOnline, true);

      bool? received;
      final sub = service.onConnectivityChanged.listen((val) {
        received = val;
      });

      service.setOnline(false);
      await Future.delayed(const Duration(milliseconds: 10));
      expect(received, false);
      expect(service.isOnline, false);

      service.setOnline(true);
      await Future.delayed(const Duration(milliseconds: 10));
      expect(received, true);
      expect(service.isOnline, true);

      await sub.cancel();
    });
  });

  group('4. GlobalErrorBoundary Widget Tests', () {
    testWidgets('GlobalErrorBoundary renders child normally when no error', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildResiliencyTestApp(
          const GlobalErrorBoundary(child: Text('Safe Child Content')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Safe Child Content'), findsOneWidget);
      expect(find.text('Something Went Wrong'), findsNothing);
    });

    testWidgets(
      'GlobalErrorBoundary displays recovery UI and recovers on retry',
      (WidgetTester tester) async {
        final boundaryKey = GlobalKey<GlobalErrorBoundaryState>();

        await tester.pumpWidget(
          buildResiliencyTestApp(
            GlobalErrorBoundary(
              key: boundaryKey,
              child: const Text('Child Before Error'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Child Before Error'), findsOneWidget);

        // Trigger error boundary
        boundaryKey.currentState?.catchError(
          FlutterErrorDetails(
            exception: Exception('Simulated test rendering exception'),
            stack: StackTrace.current,
          ),
        );
        await tester.pumpAndSettle();

        // Verify custom error screen is displayed
        expect(find.text('Something Went Wrong'), findsOneWidget);
        expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
        expect(
          find.byKey(const Key('global_error_retry_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('global_error_home_button')),
          findsOneWidget,
        );

        // Tap Try Again recovery button
        await tester.tap(find.byKey(const Key('global_error_retry_button')));
        await tester.pumpAndSettle();

        // State is reset and child is displayed again
        expect(find.text('Child Before Error'), findsOneWidget);
        expect(find.text('Something Went Wrong'), findsNothing);
      },
    );
  });

  group('5. JobDetailScreen Crash Prevention & Fallback Tests', () {
    testWidgets(
      'JobDetailScreen gracefully renders Job Not Found when job does not exist',
      (WidgetTester tester) async {
        final emptyJobProvider = JobProvider(
          jobRepository: InMemoryJobRepository(initialJobs: []),
        );

        await tester.pumpWidget(
          buildResiliencyTestApp(
            const JobDetailScreen(jobId: 'non_existent_job_12345'),
            jobProvider: emptyJobProvider,
          ),
        );
        await tester.pumpAndSettle();

        // Verify no exception was thrown and Job Not Found UI is rendered
        expect(find.text('Job Not Found'), findsOneWidget);
        expect(find.byIcon(Icons.search_off), findsOneWidget);
        expect(
          find.textContaining('listing is no longer available'),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('return_to_jobs_feed_button')),
          findsOneWidget,
        );
      },
    );
  });

  group('6. SafeNetworkImage Fallback & Placeholder Tests', () {
    testWidgets(
      'SafeNetworkImage renders fallback widget on null or invalid URL',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          buildResiliencyTestApp(
            const Column(
              children: [
                SafeNetworkImage(imageUrl: null, width: 60, height: 60),
                SafeNetworkImage(imageUrl: '', width: 60, height: 60),
                SafeNetworkImage(
                  imageUrl: 'not_a_valid_url',
                  width: 60,
                  height: 60,
                ),
                SafeNetworkImage(
                  imageUrl: null,
                  fallbackWidget: Text('Custom Fallback Text'),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Expect default fallback icons for null/empty/invalid
        expect(
          find.byIcon(Icons.image_not_supported_outlined),
          findsNWidgets(3),
        );
        // Expect custom fallback widget
        expect(find.text('Custom Fallback Text'), findsOneWidget);
      },
    );
  });

  group('7. MapViewScreen Graceful Degradation Tests', () {
    testWidgets(
      'MapViewScreen renders map explorer and handles fallback mode',
      (WidgetTester tester) async {
        final jobProvider = JobProvider(jobRepository: InMemoryJobRepository());

        await tester.pumpWidget(
          buildResiliencyTestApp(
            const MapViewScreen(),
            jobProvider: jobProvider,
          ),
        );
        await tester.pumpAndSettle();

        // Header is rendered
        expect(find.text('Map Explorer'), findsOneWidget);
        expect(find.text('Accra'), findsOneWidget);
        expect(find.text('Kumasi'), findsOneWidget);
        expect(find.text('Tema'), findsOneWidget);
      },
    );
  });
}
