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
import 'package:local_job_connector/features/favorites/screens/favorites_screen.dart';
import 'package:local_job_connector/features/jobs/screens/create_job_screen.dart';
import 'package:local_job_connector/features/jobs/screens/job_detail_screen.dart';
import 'package:local_job_connector/features/jobs/screens/job_feed_screen.dart';
import 'package:local_job_connector/features/jobs/widgets/job_card.dart';
import 'package:provider/provider.dart';

Widget createJobTestApp(
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
            chat ??
            ChatProvider(
              currentUserId: 'seeker_001',
              chatRepository: InMemoryChatRepository(),
            ),
      ),
    ],
    child: MaterialApp(theme: AppTheme.lightTheme, home: homeWidget),
  );
}

void main() {
  group('JobFeedScreen & JobCard Widget Tests', () {
    testWidgets(
      'JobFeedScreen renders search bar, city chips, category chips, and job cards',
      (WidgetTester tester) async {
        final jobProvider = JobProvider(jobRepository: InMemoryJobRepository());

        await tester.pumpWidget(
          createJobTestApp(const JobFeedScreen(), job: jobProvider),
        );
        await tester.pumpAndSettle();

        expect(find.text('Local Job Connector'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);

        // Verify City Chips
        expect(find.text('All'), findsWidgets);
        expect(find.text('Accra'), findsWidgets);
        expect(find.text('Kumasi'), findsWidgets);
        expect(find.text('Tema'), findsWidgets);

        // Verify Category Chips
        expect(find.text('Construction & Labor'), findsWidgets);
        expect(find.text('Hospitality'), findsWidgets);

        // Verify JobCards rendered
        expect(find.byType(JobCard), findsWidgets);
      },
    );

    testWidgets('Filtering feed by city chip updates job list', (
      WidgetTester tester,
    ) async {
      final jobProvider = JobProvider(jobRepository: InMemoryJobRepository());

      await tester.pumpWidget(
        createJobTestApp(const JobFeedScreen(), job: jobProvider),
      );
      await tester.pumpAndSettle();

      // Tap Kumasi city chip
      await tester.tap(find.widgetWithText(ChoiceChip, 'Kumasi'));
      await tester.pumpAndSettle();

      expect(jobProvider.selectedCity, 'Kumasi');
      for (final job in jobProvider.filteredJobs) {
        expect(job.city, 'Kumasi');
      }
    });

    testWidgets(
      'Search query filters jobs and shows zero state when no match',
      (WidgetTester tester) async {
        final jobProvider = JobProvider(jobRepository: InMemoryJobRepository());

        await tester.pumpWidget(
          createJobTestApp(const JobFeedScreen(), job: jobProvider),
        );
        await tester.pumpAndSettle();

        // Enter search query with match
        await tester.enterText(find.byType(TextField), 'Kejetia');
        await tester.pumpAndSettle();
        expect(find.textContaining('Kejetia'), findsWidgets);

        // Enter query with 0 matches
        await tester.enterText(find.byType(TextField), 'NonexistentJob12345');
        await tester.pumpAndSettle();
        expect(
          find.text('No jobs found matching your criteria.'),
          findsOneWidget,
        );

        // Clear search
        await tester.tap(find.byIcon(Icons.clear));
        await tester.pumpAndSettle();
        expect(jobProvider.searchQuery, '');
      },
    );
  });

  group('JobDetailScreen Widget Tests', () {
    testWidgets('JobDetailScreen displays metadata and Seeker chat button', (
      WidgetTester tester,
    ) async {
      final jobProvider = JobProvider(jobRepository: InMemoryJobRepository());
      final targetJob = jobProvider.allJobs.first;

      await tester.pumpWidget(
        createJobTestApp(
          JobDetailScreen(jobId: targetJob.id),
          job: jobProvider,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Job Details'), findsOneWidget);
      expect(find.text(targetJob.title), findsOneWidget);
      expect(find.text(targetJob.category), findsOneWidget);
      expect(
        find.text('GHS ${targetJob.payRate.toStringAsFixed(0)} '),
        findsOneWidget,
      );
      expect(find.text(targetJob.posterName), findsOneWidget);
      expect(find.text(targetJob.description), findsOneWidget);

      // Role is Seeker -> Chat button is visible
      expect(find.text('Start Chat with Employer'), findsOneWidget);
    });

    testWidgets(
      'JobDetailScreen displays Employer warning banner when role is poster',
      (WidgetTester tester) async {
        final jobProvider = JobProvider(jobRepository: InMemoryJobRepository());
        jobProvider.setRole(UserRole.poster);
        final targetJob = jobProvider.allJobs.first;

        await tester.pumpWidget(
          createJobTestApp(
            JobDetailScreen(jobId: targetJob.id),
            job: jobProvider,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('You are viewing this listing in Employer mode'),
          findsOneWidget,
        );
        expect(find.text('Start Chat with Employer'), findsNothing);
      },
    );

    testWidgets('Toggle favorite button in JobDetailScreen updates state', (
      WidgetTester tester,
    ) async {
      final jobProvider = JobProvider(jobRepository: InMemoryJobRepository());
      final targetJob = jobProvider.allJobs.first;

      await tester.pumpWidget(
        createJobTestApp(
          JobDetailScreen(jobId: targetJob.id),
          job: jobProvider,
        ),
      );
      await tester.pumpAndSettle();

      expect(jobProvider.isFavorite(targetJob.id), false);

      // Tap favorite icon button in AppBar
      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pumpAndSettle();

      expect(jobProvider.isFavorite(targetJob.id), true);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });
  });

  group('CreateJobScreen Widget Tests', () {
    testWidgets('CreateJobScreen validates form and submits new job', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final jobProvider = JobProvider(jobRepository: InMemoryJobRepository());
      final initialCount = jobProvider.allJobs.length;

      await tester.pumpWidget(
        createJobTestApp(const CreateJobScreen(), job: jobProvider),
      );
      await tester.pumpAndSettle();

      expect(find.text('Post Informal Job'), findsOneWidget);

      // Fill in Form
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Job Title'),
        'Painter and Decorator',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Pay Amount (GHS)'),
        '200',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Exact Location / Landmark'),
        'Circle Overpass',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Job Description & Requirements'),
        'Need 2 painters for residential house.',
      );

      await tester.ensureVisible(find.text('Publish Job Posting'));
      await tester.tap(find.text('Publish Job Posting'));
      await tester.pumpAndSettle();

      expect(jobProvider.allJobs.length, initialCount + 1);
      expect(jobProvider.allJobs.first.title, 'Painter and Decorator');
      expect(find.text('Job posting created successfully!'), findsOneWidget);
    });
  });

  group('FavoritesScreen Widget Tests', () {
    testWidgets('FavoritesScreen displays empty state when 0 favorites', (
      WidgetTester tester,
    ) async {
      final jobProvider = JobProvider(jobRepository: InMemoryJobRepository());

      await tester.pumpWidget(
        createJobTestApp(const FavoritesScreen(), job: jobProvider),
      );
      await tester.pumpAndSettle();

      expect(find.text('Saved Jobs / Favorites'), findsOneWidget);
      expect(find.text('No saved jobs yet.'), findsOneWidget);
      expect(find.byType(JobCard), findsNothing);
    });

    testWidgets('FavoritesScreen displays favorited job cards', (
      WidgetTester tester,
    ) async {
      final jobProvider = JobProvider(jobRepository: InMemoryJobRepository());
      final firstJob = jobProvider.allJobs.first;
      await jobProvider.toggleFavorite(firstJob.id);

      await tester.pumpWidget(
        createJobTestApp(const FavoritesScreen(), job: jobProvider),
      );
      await tester.pumpAndSettle();

      expect(find.byType(JobCard), findsOneWidget);
      expect(find.text(firstJob.title), findsOneWidget);
    });
  });
}
