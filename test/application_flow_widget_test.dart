import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_job_connector/app/theme.dart';
import 'package:local_job_connector/core/models/job_application_model.dart';
import 'package:local_job_connector/core/models/job_model.dart';
import 'package:local_job_connector/core/models/user_model.dart';
import 'package:local_job_connector/core/providers/application_provider.dart';
import 'package:local_job_connector/core/providers/auth_provider.dart';
import 'package:local_job_connector/core/providers/chat_provider.dart';
import 'package:local_job_connector/core/providers/job_provider.dart';
import 'package:local_job_connector/core/repositories/application_repository.dart';
import 'package:local_job_connector/core/repositories/chat_repository.dart';
import 'package:local_job_connector/core/repositories/job_repository.dart';
import 'package:local_job_connector/core/repositories/user_repository.dart';
import 'package:local_job_connector/core/services/local_storage_service.dart';
import 'package:local_job_connector/features/applications/screens/applicant_review_screen.dart';
import 'package:local_job_connector/features/applications/screens/my_applications_screen.dart';
import 'package:local_job_connector/features/jobs/screens/job_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService localStorageService;
  late ApplicationProvider applicationProvider;
  late JobProvider jobProvider;
  late AuthProvider authProvider;
  late ChatProvider chatProvider;

  final sampleJob = JobPost(
    id: 'job_widget_001',
    title: 'Site Mason Assistant',
    description: 'Help with mortar mixing and bricklaying at Circle.',
    category: 'Construction & Labor',
    payRate: 200.0,
    payUnit: 'per day',
    currency: 'GHS',
    city: 'Accra',
    locationName: 'Circle Interchange',
    latitude: 5.5586,
    longitude: -0.2014,
    posterId: 'poster_accra_01',
    posterName: 'Accra Masonry Ltd',
    posterPhone: '+233 24 111 2222',
    status: JobStatus.open,
    createdAt: DateTime(2026, 8, 29),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    localStorageService = LocalStorageService(prefs: prefs);
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
      initialSeekerId: 'seeker_001',
    );

    jobProvider = JobProvider(
      jobRepository: jobRepo,
      localStorageService: localStorageService,
    );

    authProvider = AuthProvider(
      userRepository: userRepo,
      localStorageService: localStorageService,
    );

    chatProvider = ChatProvider(
      chatRepository: chatRepo,
      localStorageService: localStorageService,
    );
  });

  Widget buildTestApp(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: jobProvider),
        ChangeNotifierProvider.value(value: chatProvider),
        ChangeNotifierProvider.value(value: applicationProvider),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: child,
      ),
    );
  }

  group('JobDetailScreen Application & Status Flow Widget Tests', () {
    testWidgets('Seeker submits application and verifies status badge update', (tester) async {
      jobProvider.setRole(UserRole.seeker);

      await tester.pumpWidget(buildTestApp(const JobDetailScreen(jobId: 'job_widget_001')));
      await tester.pumpAndSettle();

      // Verify Job Details & Apply button rendered
      expect(find.text('Site Mason Assistant'), findsOneWidget);
      expect(find.byKey(const Key('apply_for_job_button')), findsOneWidget);
      expect(find.text('Apply for this Job'), findsOneWidget);

      // Tap Apply for this Job button
      await tester.ensureVisible(find.byKey(const Key('apply_for_job_button')));
      await tester.tap(find.byKey(const Key('apply_for_job_button')));
      await tester.pumpAndSettle();

      // Verify Bottom Sheet Modal
      expect(find.text('Apply for Site Mason Assistant'), findsOneWidget);
      expect(find.byKey(const Key('apply_name_input')), findsOneWidget);
      expect(find.byKey(const Key('apply_phone_input')), findsOneWidget);
      expect(find.byKey(const Key('apply_note_input')), findsOneWidget);

      // Enter cover note
      await tester.enterText(
        find.byKey(const Key('apply_note_input')),
        'I have 4 years experience in masonry work.',
      );

      // Submit application
      await tester.tap(find.byKey(const Key('submit_application_button')));
      await tester.pumpAndSettle();

      // Verify feedback and status badge
      expect(find.text('Application submitted successfully!'), findsOneWidget);
      expect(find.textContaining('Applied: Pending Review'), findsOneWidget);
      expect(find.textContaining('I have 4 years experience in masonry work.'), findsOneWidget);

      // Verify "Apply for this Job" button is no longer visible
      expect(find.byKey(const Key('apply_for_job_button')), findsNothing);
    });

    testWidgets('Employer views applicant count and transitions job status lifecycle', (tester) async {
      jobProvider.setRole(UserRole.poster);

      await tester.pumpWidget(buildTestApp(const JobDetailScreen(jobId: 'job_widget_001')));
      await tester.pumpAndSettle();

      // Employer controls
      expect(find.byKey(const Key('view_applicants_button')), findsOneWidget);
      expect(find.text('View Applicants (0)'), findsOneWidget);
      expect(find.text('Job Lifecycle Status'), findsOneWidget);
      expect(find.byKey(const Key('job_status_open')), findsOneWidget);
      expect(find.byKey(const Key('job_status_in_progress')), findsOneWidget);
      expect(find.byKey(const Key('job_status_completed')), findsOneWidget);

      // Initial status is Open
      expect(find.text('Active / Open'), findsOneWidget);

      // Transition to In Progress
      await tester.ensureVisible(find.byKey(const Key('job_status_in_progress')));
      await tester.tap(find.byKey(const Key('job_status_in_progress')));
      await tester.pumpAndSettle();

      expect(find.text('Job status set to In Progress'), findsOneWidget);
      expect(find.text('In Progress'), findsNWidgets(2)); // Badge + Chip

      // Transition to Completed
      await tester.ensureVisible(find.byKey(const Key('job_status_completed')));
      await tester.tap(find.byKey(const Key('job_status_completed')));
      await tester.pumpAndSettle();

      expect(find.text('Job status set to Completed'), findsOneWidget);
      expect(find.text('Completed'), findsNWidgets(2)); // Badge + Chip
    });
  });

  group('ApplicantReviewScreen Employer Review Widget Tests', () {
    testWidgets('Renders empty state when no applicants exist', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const ApplicantReviewScreen(
            jobId: 'job_widget_001',
            jobTitle: 'Site Mason Assistant',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Applicants: Site Mason Assistant'), findsOneWidget);
      expect(find.text('No Applicants Yet'), findsOneWidget);
      expect(find.byIcon(Icons.people_outline), findsOneWidget);
    });

    testWidgets('Employer reviews applicant and accepts application', (tester) async {
      await applicationProvider.submitApplication(
        applicationId: 'app_review_01',
        jobId: 'job_widget_001',
        jobTitle: 'Site Mason Assistant',
        employerId: 'poster_accra_01',
        applicantId: 'seeker_kofi',
        applicantName: 'Kofi Mensah',
        applicantPhone: '+233 24 123 4567',
        coverNote: 'Available immediately for bricklaying.',
      );

      await tester.pumpWidget(
        buildTestApp(
          const ApplicantReviewScreen(
            jobId: 'job_widget_001',
            jobTitle: 'Site Mason Assistant',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify applicant information
      expect(find.text('Kofi Mensah'), findsOneWidget);
      expect(find.text('+233 24 123 4567'), findsOneWidget);
      expect(find.text('Available immediately for bricklaying.'), findsOneWidget);
      expect(find.text('Pending Review'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);

      // Tap Accept
      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();

      expect(find.text('Accepted Kofi Mensah for this job!'), findsOneWidget);
      expect(find.text('Applicant Accepted'), findsOneWidget);
      expect(applicationProvider.applications.first.status, ApplicationStatus.accepted);
    });

    testWidgets('Employer reviews applicant and rejects application', (tester) async {
      await applicationProvider.submitApplication(
        applicationId: 'app_review_02',
        jobId: 'job_widget_001',
        jobTitle: 'Site Mason Assistant',
        employerId: 'poster_accra_01',
        applicantId: 'seeker_ama',
        applicantName: 'Ama Serwaa',
        applicantPhone: '+233 20 999 8888',
        coverNote: 'Looking for part time work.',
      );

      await tester.pumpWidget(
        buildTestApp(
          const ApplicantReviewScreen(
            jobId: 'job_widget_001',
            jobTitle: 'Site Mason Assistant',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ama Serwaa'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);

      // Tap Reject
      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();

      expect(find.text('Application for Ama Serwaa rejected.'), findsOneWidget);
      expect(find.text('Application Rejected'), findsOneWidget);
      expect(applicationProvider.applications.first.status, ApplicationStatus.rejected);
    });
  });

  group('MyApplicationsScreen Seeker Tracking Widget Tests', () {
    testWidgets('Renders empty state when seeker has no applications', (tester) async {
      await tester.pumpWidget(buildTestApp(const MyApplicationsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('My Applications'), findsOneWidget);
      expect(find.text('No Applications Yet'), findsOneWidget);
      expect(find.text('Browse Available Jobs'), findsOneWidget);
    });

    testWidgets('Renders submitted applications list with status badges and navigation', (tester) async {
      await applicationProvider.submitApplication(
        applicationId: 'app_mine_01',
        jobId: 'job_widget_001',
        jobTitle: 'Site Mason Assistant',
        employerId: 'poster_01',
        applicantId: 'seeker_001',
        applicantName: 'Kofi Mensah',
        applicantPhone: '+233 24 123 4567',
        coverNote: 'Experienced helper',
      );

      await tester.pumpWidget(buildTestApp(const MyApplicationsScreen()));
      await tester.pumpAndSettle();

      // Verify application card
      expect(find.text('Site Mason Assistant'), findsOneWidget);
      expect(find.text('Pending Review'), findsOneWidget);
      expect(find.text('Note: "Experienced helper"'), findsOneWidget);
      expect(find.text('View Job'), findsOneWidget);

      // Tap View Job button
      await tester.tap(find.text('View Job'));
      await tester.pumpAndSettle();

      // Navigated to JobDetailScreen
      expect(find.text('Job Details'), findsOneWidget);
      expect(find.text('Job Description'), findsOneWidget);
    });
  });
}
