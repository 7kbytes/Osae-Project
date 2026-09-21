import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_job_connector/app/theme.dart';
import 'package:local_job_connector/core/models/job_application_model.dart';
import 'package:local_job_connector/core/models/job_model.dart';
import 'package:local_job_connector/core/models/user_model.dart';
import 'package:local_job_connector/core/providers/application_provider.dart';
import 'package:local_job_connector/core/providers/auth_provider.dart';
import 'package:local_job_connector/core/providers/chat_provider.dart';
import 'package:local_job_connector/core/providers/connectivity_provider.dart';
import 'package:local_job_connector/core/providers/job_provider.dart';
import 'package:local_job_connector/core/repositories/application_repository.dart';
import 'package:local_job_connector/core/repositories/chat_repository.dart';
import 'package:local_job_connector/core/repositories/job_repository.dart';
import 'package:local_job_connector/core/repositories/user_repository.dart';
import 'package:local_job_connector/core/services/local_storage_service.dart';
import 'package:local_job_connector/core/utils/form_validators.dart';
import 'package:local_job_connector/core/utils/input_sanitizer.dart';
import 'package:local_job_connector/core/widgets/global_error_boundary.dart';
import 'package:local_job_connector/core/widgets/offline_banner.dart';
import 'package:local_job_connector/core/widgets/safe_image.dart';
import 'package:local_job_connector/features/applications/screens/applicant_review_screen.dart';
import 'package:local_job_connector/features/applications/screens/my_applications_screen.dart';
import 'package:local_job_connector/features/auth/screens/login_screen.dart';
import 'package:local_job_connector/features/jobs/screens/create_job_screen.dart';
import 'package:local_job_connector/features/jobs/screens/job_detail_screen.dart';
import 'package:local_job_connector/features/map/screens/map_view_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService localStorageService;
  late ApplicationProvider applicationProvider;
  late JobProvider jobProvider;
  late AuthProvider authProvider;
  late ChatProvider chatProvider;
  late ConnectivityProvider connectivityProvider;

  final sampleJob = JobPost(
    id: 'job_challenger_001',
    title: 'Circle VIP Porter',
    description: 'Help travelers with luggage at Circle VIP terminal.',
    category: 'Transport',
    payRate: 150.0,
    payUnit: 'per day',
    currency: 'GHS',
    city: 'Accra',
    locationName: 'Circle VIP Terminal',
    latitude: 5.5586,
    longitude: -0.2014,
    posterId: 'employer_accra_01',
    posterName: 'Accra VIP Transport Ltd',
    posterPhone: '+233 24 111 3333',
    status: JobStatus.open,
    createdAt: DateTime(2026, 8, 29),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    localStorageService = LocalStorageService(prefs: prefs);
    LocalStorageService.instance.setPreferences(prefs);
    await localStorageService.saveJobs([sampleJob]);

    final appRepo = InMemoryApplicationRepository(
      localStorageService: localStorageService,
    );
    final jobRepo = InMemoryJobRepository(initialJobs: [sampleJob]);
    final userRepo = InMemoryUserRepository();
    final chatRepo = InMemoryChatRepository();

    applicationProvider = ApplicationProvider(
      applicationRepository: appRepo,
      localStorageService: localStorageService,
      initialSeekerId: 'seeker_challenger_01',
    );

    jobProvider = JobProvider(
      jobRepository: jobRepo,
      localStorageService: localStorageService,
    );

    authProvider = AuthProvider(
      userRepository: userRepo,
      localStorageService: localStorageService,
      startAuthenticated: true,
    );

    chatProvider = ChatProvider(
      currentUserId: 'seeker_001',
      chatRepository: chatRepo,
      localStorageService: localStorageService,
    );

    connectivityProvider = ConnectivityProvider(initialOnline: true);
  });

  Widget buildChallengerApp(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: jobProvider),
        ChangeNotifierProvider.value(value: chatProvider),
        ChangeNotifierProvider.value(value: applicationProvider),
        ChangeNotifierProvider.value(value: connectivityProvider),
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: child),
    );
  }

  // =========================================================================
  // MISSION ITEM 1: End-to-End Workflow & Lifecycle Transitions
  // =========================================================================
  group(
    'Mission 1: End-to-End Seeker Application -> Review -> Status Lifecycle',
    () {
      testWidgets(
        'Full Workflow: Seeker apply -> Employer review -> Accept -> inProgress -> Complete',
        (tester) async {
          // 1. Seeker mode: JobDetailScreen
          jobProvider.setRole(UserRole.seeker);
          await tester.pumpWidget(
            buildChallengerApp(
              const JobDetailScreen(jobId: 'job_challenger_001'),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Circle VIP Porter'), findsOneWidget);
          expect(find.byKey(const Key('apply_for_job_button')), findsOneWidget);

          // Scroll to and open Apply Bottom Sheet
          await tester.ensureVisible(
            find.byKey(const Key('apply_for_job_button')),
          );
          await tester.tap(find.byKey(const Key('apply_for_job_button')));
          await tester.pumpAndSettle();

          // Enter application note
          await tester.enterText(
            find.byKey(const Key('apply_note_input')),
            'Available every day from 6 AM.',
          );

          // Submit
          await tester.tap(find.byKey(const Key('submit_application_button')));
          await tester.pumpAndSettle();

          // Verify success message & status card
          expect(
            find.text('Application submitted successfully!'),
            findsOneWidget,
          );
          expect(
            find.textContaining('Applied: Pending Review'),
            findsOneWidget,
          );
          expect(find.byKey(const Key('apply_for_job_button')), findsNothing);

          // 2. Seeker checks MyApplicationsScreen
          await tester.pumpWidget(
            buildChallengerApp(const MyApplicationsScreen()),
          );
          await tester.pumpAndSettle();

          expect(find.text('My Applications'), findsOneWidget);
          expect(find.text('Circle VIP Porter'), findsOneWidget);
          expect(find.text('Pending Review'), findsOneWidget);
          expect(
            find.text('Note: "Available every day from 6 AM."'),
            findsOneWidget,
          );

          // 3. Switch to Employer mode: ApplicantReviewScreen
          jobProvider.setRole(UserRole.poster);
          await tester.pumpWidget(
            buildChallengerApp(
              const ApplicantReviewScreen(
                jobId: 'job_challenger_001',
                jobTitle: 'Circle VIP Porter',
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Applicants: Circle VIP Porter'), findsOneWidget);
          expect(find.text('Accept'), findsOneWidget);
          expect(find.text('Reject'), findsOneWidget);

          // Employer taps Accept
          await tester.tap(find.text('Accept'));
          await tester.pumpAndSettle();

          expect(find.textContaining('Accepted'), findsWidgets);
          expect(find.text('Applicant Accepted'), findsOneWidget);
          expect(
            jobProvider.allJobs
                .firstWhere((j) => j.id == 'job_challenger_001')
                .status,
            JobStatus.inProgress,
          );
          expect(
            jobProvider.allJobs
                .firstWhere((j) => j.id == 'job_challenger_001')
                .isFilled,
            true,
          );

          // 4. Employer transitions job status in JobDetailScreen
          jobProvider.setRole(UserRole.poster);
          await tester.pumpWidget(
            buildChallengerApp(
              const JobDetailScreen(jobId: 'job_challenger_001'),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Job Lifecycle Status'), findsOneWidget);
          expect(find.byKey(const Key('job_status_completed')), findsOneWidget);

          await tester.ensureVisible(
            find.byKey(const Key('job_status_completed')),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('job_status_completed')));
          await tester.pumpAndSettle();

          expect(
            jobProvider.allJobs
                .firstWhere((j) => j.id == 'job_challenger_001')
                .status,
            JobStatus.completed,
          );
          expect(
            jobProvider.allJobs
                .firstWhere((j) => j.id == 'job_challenger_001')
                .isFilled,
            true,
          );

          // 5. Seeker verifies completed status in MyApplicationsScreen
          jobProvider.setRole(UserRole.seeker);
          await applicationProvider.updateApplicationStatus(
            applicationProvider.applications.first.id,
            ApplicationStatus.completed,
          );
          await tester.pumpWidget(
            buildChallengerApp(const MyApplicationsScreen()),
          );
          await tester.pumpAndSettle();

          expect(find.text('Job Completed'), findsOneWidget);
        },
      );

      test('Duplicate application attempt is rejected idempotently', () async {
        final success1 = await applicationProvider.submitApplication(
          jobId: 'job_challenger_001',
          jobTitle: 'Circle VIP Porter',
          employerId: 'employer_accra_01',
          applicantId: 'seeker_unique_01',
          applicantName: 'Kwesi Appiah',
          applicantPhone: '+233 24 000 1111',
          coverNote: 'First application',
        );
        expect(success1, true);

        final success2 = await applicationProvider.submitApplication(
          jobId: 'job_challenger_001',
          jobTitle: 'Circle VIP Porter',
          employerId: 'employer_accra_01',
          applicantId: 'seeker_unique_01',
          applicantName: 'Kwesi Appiah',
          applicantPhone: '+233 24 000 1111',
          coverNote: 'Duplicate application should return false',
        );
        expect(success2, false);
        expect(
          applicationProvider
              .getApplicationsForJob('job_challenger_001')
              .length,
          1,
        );
      });

      test(
        'Reopening a completed job resets isFilled to false cleanly',
        () async {
          await jobProvider.updateJobStatus(
            'job_challenger_001',
            JobStatus.completed,
          );
          expect(jobProvider.allJobs.first.isFilled, true);

          await jobProvider.updateJobStatus(
            'job_challenger_001',
            JobStatus.open,
          );
          expect(jobProvider.allJobs.first.status, JobStatus.open);
          expect(jobProvider.allJobs.first.isFilled, false);
        },
      );
    },
  );

  // =========================================================================
  // MISSION ITEM 2: UI Error Boundaries & Fallbacks
  // =========================================================================
  group('Mission 2: UI Error Boundaries & Fallbacks', () {
    testWidgets(
      'GlobalErrorBoundary catches exceptions, displays recovery UI, and handles retry & home',
      (tester) async {
        final boundaryKey = GlobalKey<GlobalErrorBoundaryState>();

        await tester.pumpWidget(
          buildChallengerApp(
            GlobalErrorBoundary(
              key: boundaryKey,
              child: const Text('Intact Child UI'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Intact Child UI'), findsOneWidget);

        // Trigger error
        boundaryKey.currentState?.catchError(
          FlutterErrorDetails(
            exception: Exception('Challenger 2 simulated render exception'),
            stack: StackTrace.current,
          ),
        );
        await tester.pumpAndSettle();

        // Verify recovery screen
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

        // Tap Retry
        await tester.tap(find.byKey(const Key('global_error_retry_button')));
        await tester.pumpAndSettle();

        expect(find.text('Intact Child UI'), findsOneWidget);
        expect(find.text('Something Went Wrong'), findsNothing);
      },
    );

    testWidgets(
      'OfflineBanner reacts to connectivity drops and recoveries seamlessly',
      (tester) async {
        await tester.pumpWidget(
          buildChallengerApp(
            const OfflineBanner(
              child: Scaffold(body: Text('Protected Screen Content')),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Online: no banner
        expect(find.byKey(const Key('offline_banner_container')), findsNothing);

        // Drop connection
        connectivityProvider.setOnline(false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Offline: banner visible
        expect(
          find.byKey(const Key('offline_banner_container')),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
        expect(find.textContaining('Offline Mode'), findsOneWidget);

        // Reconnect
        connectivityProvider.setOnline(true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Online: banner removed
        expect(find.byKey(const Key('offline_banner_container')), findsNothing);
      },
    );

    testWidgets(
      'SafeNetworkImage gracefully renders fallbacks across all invalid URL patterns',
      (tester) async {
        await tester.pumpWidget(
          buildChallengerApp(
            const Column(
              children: [
                SafeNetworkImage(imageUrl: null, width: 50, height: 50),
                SafeNetworkImage(imageUrl: '', width: 50, height: 50),
                SafeNetworkImage(
                  imageUrl: 'ftp://bad-protocol.com/img.png',
                  width: 50,
                  height: 50,
                ),
                SafeNetworkImage(
                  imageUrl: 'random_text_not_url',
                  width: 50,
                  height: 50,
                ),
                SafeNetworkImage(
                  imageUrl: null,
                  fallbackWidget: Text('Custom Fallback UI'),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byIcon(Icons.image_not_supported_outlined),
          findsNWidgets(4),
        );
        expect(find.text('Custom Fallback UI'), findsOneWidget);
      },
    );

    testWidgets(
      'JobDetailScreen gracefully handles non-existent or deleted jobId',
      (tester) async {
        await tester.pumpWidget(
          buildChallengerApp(
            const JobDetailScreen(jobId: 'non_existent_job_999999'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Job Not Found'), findsOneWidget);
        expect(find.byIcon(Icons.search_off), findsOneWidget);
        expect(
          find.byKey(const Key('return_to_jobs_feed_button')),
          findsOneWidget,
        );
      },
    );

    testWidgets('MapViewScreen renders fallback and city switchers safely', (
      tester,
    ) async {
      await tester.pumpWidget(buildChallengerApp(const MapViewScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Map Explorer'), findsOneWidget);
      expect(find.text('Accra'), findsOneWidget);
      expect(find.text('Kumasi'), findsOneWidget);
      expect(find.text('Tema'), findsOneWidget);
    });
  });

  // =========================================================================
  // MISSION ITEM 3: Ghana Phone Formatting & Input Sanitization
  // =========================================================================
  group('Mission 3: Ghana Phone Formatting & Input Sanitization Matrix', () {
    test(
      'Ghana phone validation accepts all valid Ghanaian network telco prefixes',
      () {
        final validGhanaianPhones = [
          '+233 24 123 4567', // MTN (+233)
          '+233 54 987 6543', // MTN (+233)
          '+233 55 111 2222', // MTN (+233)
          '+233 59 333 4444', // MTN (+233)
          '+233 20 555 6666', // Telecel/Vodafone (+233)
          '+233 50 777 8888', // Telecel/Vodafone (+233)
          '+233 27 999 0000', // AT/AirtelTigo (+233)
          '+233 57 222 3333', // AT/AirtelTigo (+233)
          '+233 26 444 5555', // AT/AirtelTigo (+233)
          '+233 28 666 7777', // Expresso (+233)
          '+233 23 888 9999', // Glo/AT (+233)
          '0241234567', // Local MTN (024)
          '0541234567', // Local MTN (054)
          '0551234567', // Local MTN (055)
          '0591234567', // Local MTN (059)
          '0201234567', // Local Telecel (020)
          '0501234567', // Local Telecel (050)
          '0271234567', // Local AT (027)
          '0571234567', // Local AT (057)
          '0261234567', // Local AT (026)
          '0281234567', // Local (028)
          '0231234567', // Local (023)
          '+233-24-123-4567', // Hyphenated
          '024-123-4567', // Hyphenated local
          ' (024) 123 4567 ', // Parenthesized & spaced
        ];

        for (final phone in validGhanaianPhones) {
          final error = FormValidators.validateGhanaPhone(phone);
          expect(
            error,
            isNull,
            reason: 'Expected $phone to be valid Ghana phone',
          );
        }
      },
    );

    test(
      'Ghana phone validation rejects foreign numbers and malformed inputs',
      () {
        final invalidPhones = [
          null,
          '',
          '   ',
          '12345',
          '+1 555 123 4567', // USA
          '+44 7911 123456', // UK
          '+234 80 1234 5678', // Nigeria
          '0123456789', // Invalid prefix 01
          '0801234567', // Invalid prefix 08
          '0901234567', // Invalid prefix 09
          '+233 24 123 45', // 7 digits (too short)
          '+233 24 123 45678', // 10 digits (too long)
          '02412345', // 8 digits (too short)
          '02412345678', // 11 digits (too long)
          'phone-number',
          '<script>alert(1)</script>',
        ];

        for (final phone in invalidPhones) {
          final error = FormValidators.validateGhanaPhone(phone);
          expect(
            error,
            isNotNull,
            reason: 'Expected $phone to be invalid Ghana phone',
          );
        }
      },
    );

    test(
      'InputSanitizer neutralizes scripts, HTML tags, and control characters',
      () {
        expect(
          InputSanitizer.sanitize('<script>alert("hacked")</script>Job Title'),
          'Job Title',
        );
        expect(
          InputSanitizer.sanitize('<b>Mason</b> <i>Helper</i>'),
          'Mason Helper',
        );
        expect(
          InputSanitizer.sanitize('javascript:maliciousCode()'),
          'maliciousCode()',
        );
        expect(
          InputSanitizer.sanitize('Accra\x00Market\x08Gig'),
          'AccraMarketGig',
        );
        expect(
          InputSanitizer.sanitizePhone(' +233 (24) 123-4567 '),
          '+233241234567',
        );
        expect(InputSanitizer.sanitizePhone('024 123 4567'), '0241234567');
        expect(
          InputSanitizer.sanitizeEmail('  Kofi.Mensah@Ug.Edu.Gh  '),
          'kofi.mensah@ug.edu.gh',
        );
        expect(InputSanitizer.sanitizeNumeric('  GHS 250.75  '), '250.75');
        expect(InputSanitizer.sanitizeNumeric('12.34.56.78'), '12.345678');
      },
    );

    testWidgets(
      'LoginScreen form strictly enforces email, phone, and password validators',
      (tester) async {
        await tester.pumpWidget(buildChallengerApp(const LoginScreen()));
        await tester.pumpAndSettle();

        // Toggle to Sign Up mode
        final toggleButton = find.text("Don't have an account? Register Now");
        await tester.ensureVisible(toggleButton);
        await tester.tap(toggleButton);
        await tester.pumpAndSettle();

        expect(find.text('Create Account'), findsOneWidget);

        // Scroll to and tap Create Account button
        final createAccountBtn = find.text('Create Account');
        await tester.ensureVisible(createAccountBtn);
        await tester.tap(createAccountBtn);
        await tester.pumpAndSettle();

        expect(find.text('Enter full name'), findsOneWidget);
        expect(find.text('Enter phone number'), findsOneWidget);
        expect(find.text('Enter valid email'), findsOneWidget);
        expect(find.text('Password must be at least 6 chars'), findsOneWidget);
      },
    );

    testWidgets(
      'CreateJobScreen form enforces numeric pay rate, location, and title validators',
      (tester) async {
        await tester.pumpWidget(buildChallengerApp(const CreateJobScreen()));
        await tester.pumpAndSettle();

        final publishBtn = find.text('Publish Job Posting');
        await tester.ensureVisible(publishBtn);
        await tester.tap(publishBtn);
        await tester.pumpAndSettle();

        expect(find.text('Please enter a title'), findsOneWidget);
        expect(find.text('Enter pay'), findsOneWidget);
        expect(find.text('Please enter job description'), findsOneWidget);
      },
    );
  });
}
