import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:local_job_connector/app/theme.dart';
import 'package:local_job_connector/core/models/chat_model.dart';
import 'package:local_job_connector/core/models/job_application_model.dart';
import 'package:local_job_connector/core/models/job_model.dart';
import 'package:local_job_connector/core/models/timestamp_helper.dart';
import 'package:local_job_connector/core/models/user_model.dart';
import 'package:local_job_connector/core/providers/auth_provider.dart';
import 'package:local_job_connector/core/providers/chat_provider.dart';
import 'package:local_job_connector/core/providers/job_provider.dart';
import 'package:local_job_connector/core/repositories/chat_repository.dart';
import 'package:local_job_connector/core/repositories/job_repository.dart';
import 'package:local_job_connector/core/repositories/user_repository.dart';
import 'package:local_job_connector/features/chat/screens/chat_list_screen.dart';
import 'package:local_job_connector/features/favorites/screens/favorites_screen.dart';
import 'package:local_job_connector/features/jobs/screens/create_job_screen.dart';
import 'package:local_job_connector/features/jobs/screens/job_detail_screen.dart';
import 'package:local_job_connector/features/jobs/screens/job_feed_screen.dart';

void main() {
  group(
    'Empirical Challenge 1: Role Switching Stress & Concurrent State Transitions',
    () {
      late InMemoryUserRepository userRepo;
      late AuthProvider authProvider;
      late InMemoryJobRepository jobRepo;
      late JobProvider jobProvider;

      setUp(() {
        userRepo = InMemoryUserRepository();
        authProvider = AuthProvider(
          userRepository: userRepo,
          startAuthenticated: true,
        );
        jobRepo = InMemoryJobRepository();
        jobProvider = JobProvider(jobRepository: jobRepo);
      });

      test(
        'Rapid concurrent switching between Seeker and Employer (100 toggles)',
        () async {
          expect(authProvider.currentUser!.role, UserRole.seeker);
          expect(jobProvider.currentUserRole, UserRole.seeker);

          // Perform 100 rapid role switches concurrently and sequentially
          for (int i = 0; i < 100; i++) {
            final targetRole = i % 2 == 0 ? UserRole.poster : UserRole.seeker;
            await authProvider.switchRole(targetRole);
            jobProvider.setRole(targetRole);

            expect(authProvider.currentUser!.role, targetRole);
            expect(jobProvider.currentUserRole, targetRole);
          }

          // Check repository persistence after 100 toggles
          final savedUser = await userRepo.getUser(
            authProvider.currentUser!.id,
          );
          expect(savedUser, isNotNull);
          expect(savedUser!.role, UserRole.seeker);
        },
      );

      test(
        'Role switching while concurrently adding and filtering jobs',
        () async {
          for (int i = 0; i < 20; i++) {
            final targetRole = i % 2 == 0 ? UserRole.poster : UserRole.seeker;
            authProvider.switchRole(targetRole);
            jobProvider.setRole(targetRole);

            // Concurrently add a job
            final job = JobPost(
              id: 'stress_job_$i',
              title: 'Stress Job $i',
              description: 'Stress description $i',
              category: i % 2 == 0 ? 'Cleaning' : 'Construction & Labor',
              payRate: 100.0 + i,
              city: i % 2 == 0 ? 'Accra' : 'Kumasi',
              locationName: 'Landmark $i',
              latitude: 5.5,
              longitude: -0.2,
              posterId: 'poster_$i',
              posterName: 'Poster $i',
              posterPhone: '+233 24 111 222$i',
              createdAt: DateTime.now(),
            );

            await jobProvider.addJob(job);
            jobProvider.setCityFilter(i % 2 == 0 ? 'Accra' : 'Kumasi');
            jobProvider.setSearchQuery('Stress');

            expect(jobProvider.filteredJobs.isNotEmpty, true);
            expect(jobProvider.currentUserRole, targetRole);
          }
        },
      );

      test(
        'Role switching after signOut does not throw and handles gracefully',
        () async {
          authProvider.signOut();
          expect(authProvider.isAuthenticated, false);
          expect(authProvider.currentUser, isNull);

          // Calling switchRole on signed out user
          await expectLater(
            authProvider.switchRole(UserRole.poster),
            completes,
          );
          expect(authProvider.currentUser, isNull);
        },
      );
    },
  );

  group('Empirical Challenge 2: Extreme Inputs & Adversarial Validation', () {
    test(
      'Ghana phone validation comprehensive matrix (Valid and Invalid formats)',
      () {
        // Valid Ghanaian network prefixes: MTN (024, 054, 055, 059), Telecel/Vodafone (020, 050), AT/AirtelTigo (027, 057, 026)
        final validPhones = [
          '+233 24 123 4567',
          '+233 54 999 8888',
          '+233 55 000 1111',
          '+233 59 222 3333',
          '+233 20 444 5555',
          '+233 50 666 7777',
          '+233 27 888 9999',
          '+233 57 111 2222',
          '+233 26 333 4444',
          '+233 28 555 6666',
          '+233 23 777 8888',
          '+233241234567',
          '+233-24-123-4567',
          '0241234567',
          '0541234567',
          '0551234567',
          '0591234567',
          '0201234567',
          '0501234567',
          '0271234567',
          '0571234567',
          '0261234567',
          '0281234567',
          '0231234567',
          ' 024 123 4567 ',
          '024-123-4567',
        ];

        for (final phone in validPhones) {
          expect(
            AuthProvider.isValidGhanaPhone(phone),
            true,
            reason: 'Expected $phone to be valid Ghana phone',
          );
        }

        final invalidPhones = [
          '',
          '   ',
          '12345',
          '+1 555 123 4567',
          '+234 80 1234 5678', // Nigeria
          '+44 7911 123456', // UK
          '0123456789', // Invalid prefix 01
          '0801234567', // Invalid prefix 08
          '0901234567', // Invalid prefix 09
          '+233 24 123 45', // Too short (7 local digits)
          '+233 24 123 45678', // Too long (10 local digits)
          '02412345', // Too short (8 digits total)
          '02412345678', // Too long (11 digits total)
          '+233 024 123 4567', // Invalid leading 0 after country code (+2330...)
          'not-a-number',
          '++233241234567',
          '+23324123456a',
          '024123456e',
          '<script>alert(1)</script>',
          "'+233241234567'",
        ];

        for (final phone in invalidPhones) {
          expect(
            AuthProvider.isValidGhanaPhone(phone),
            false,
            reason: 'Expected $phone to be INVALID Ghana phone',
          );
        }
      },
    );

    test(
      'Search queries with regex special chars, unicode, whitespace and edge cases',
      () {
        final jobRepo = InMemoryJobRepository();
        final jobProvider = JobProvider(jobRepository: jobRepo);

        // Search with regex special characters should not crash RegExp or String operations
        final regexSpecialQueries = [
          r'.*',
          r'[a-z]+',
          r'(.*)',
          r'\\',
          r'^.*$',
          r'$',
          r'?',
          r'+',
          r'*',
          r'{1,3}',
          r'|',
          r'()[]{}',
          '<script>alert("xss")</script>',
          "'; DROP TABLE jobs; --",
          '🇬🇭 👷 🛒',
          '   \n\t  ',
        ];

        for (final query in regexSpecialQueries) {
          expect(() => jobProvider.setSearchQuery(query), returnsNormally);
          final results = jobProvider.filteredJobs;
          expect(results, isA<List<JobPost>>());
        }
      },
    );

    test(
      'Extreme pay rates, infinite/negative values, and wage parsing resilience',
      () {
        final extremeJobs = [
          JobPost(
            id: 'pay_zero',
            title: 'Volunteer Labor',
            description: 'Zero pay test',
            category: 'Other',
            payRate: 0.0,
            city: 'Accra',
            locationName: 'Circle',
            latitude: 5.5,
            longitude: -0.2,
            posterId: 'p0',
            posterName: 'P0',
            posterPhone: '+233241234567',
            createdAt: DateTime.now(),
          ),
          JobPost(
            id: 'pay_negative',
            title: 'Negative Pay Edge',
            description: 'Negative pay edge test',
            category: 'Other',
            payRate: -150.0,
            city: 'Kumasi',
            locationName: 'Kejetia',
            latitude: 6.6,
            longitude: -1.6,
            posterId: 'p1',
            posterName: 'P1',
            posterPhone: '+233241234567',
            createdAt: DateTime.now(),
          ),
          JobPost(
            id: 'pay_billion',
            title: 'Billionaire Gig',
            description: 'Huge number test',
            category: 'Retail',
            payRate: 1000000000.0,
            city: 'Tema',
            locationName: 'Community 1',
            latitude: 5.6,
            longitude: 0.0,
            posterId: 'p2',
            posterName: 'P2',
            posterPhone: '+233241234567',
            createdAt: DateTime.now(),
          ),
          JobPost(
            id: 'pay_fractional',
            title: 'Micro Pay',
            description: 'Fractional pay test',
            category: 'Cleaning',
            payRate: 0.005,
            city: 'Accra',
            locationName: 'Osu',
            latitude: 5.5,
            longitude: -0.18,
            posterId: 'p3',
            posterName: 'P3',
            posterPhone: '+233241234567',
            createdAt: DateTime.now(),
          ),
        ];

        for (final job in extremeJobs) {
          final map = job.toMap();
          expect(map['payRate'], isNotNull);
          final reconstructed = JobPost.fromMap(map, job.id);
          expect(reconstructed.payRate, job.payRate);
        }
      },
    );

    test(
      'Chat messaging stress: rapid 50 messages, empty strings, and long payloads',
      () async {
        final chatRepo = InMemoryChatRepository();
        final chatProvider = ChatProvider(chatRepository: chatRepo);

        const roomId = 'stress_room_001';

        // Send 50 rapid messages
        for (int i = 0; i < 50; i++) {
          chatProvider.sendMessage(
            roomId: roomId,
            senderId: i % 2 == 0 ? 'seeker_001' : 'poster_001',
            senderName: i % 2 == 0 ? 'Kofi Mensah' : 'Kwame Employer',
            text: 'Stress message #$i: Hello from Ghana informal market! 🇬🇭',
          );
        }

        final messages = chatProvider.getMessages(roomId);
        expect(messages.length, 50);
        expect(messages.first.text, contains('#0'));
        expect(messages.last.text, contains('#49'));

        // Very long text payload (10,000 characters)
        final longText = 'A' * 10000;
        chatProvider.sendMessage(
          roomId: roomId,
          senderId: 'seeker_001',
          senderName: 'Kofi Mensah',
          text: longText,
        );

        final updatedMessages = chatProvider.getMessages(roomId);
        expect(updatedMessages.length, 51);
        expect(updatedMessages.last.text.length, 10000);
      },
    );

    test(
      'TimestampHelper resilience across dynamic invalid / malformed inputs',
      () {
        final now = DateTime.now();

        expect(parseDateTime(now), now);
        expect(parseDateTime(now.toIso8601String()), isA<DateTime>());
        expect(parseDateTime(now.millisecondsSinceEpoch), isA<DateTime>());
        expect(parseDateTime(null), isA<DateTime>());
        expect(parseDateTime('invalid_date_string_xyz'), isA<DateTime>());
        expect(parseDateTime(123456789), isA<DateTime>());
        expect(parseDateTime(false), isA<DateTime>());
        expect(parseDateTime([]), isA<DateTime>());
        expect(parseDateTime({}), isA<DateTime>());
      },
    );

    test('Model fromMap fallbacks on missing and corrupted keys', () {
      // Corrupted JobPost map (missing non-nullable string/num fields)
      final corruptJob = JobPost.fromMap({
        'title': null,
        'description': null,
        'category': null,
        'payRate': null,
        'payUnit': null,
        'currency': null,
        'city': null,
        'latitude': null,
        'longitude': null,
        'posterName': null,
        'createdAt': 'corrupted_timestamp',
      }, 'fallback_job_001');

      expect(corruptJob.id, 'fallback_job_001');
      expect(corruptJob.title, '');
      expect(corruptJob.category, 'Other');
      expect(corruptJob.payRate, 0.0);
      expect(corruptJob.city, 'Accra');
      expect(corruptJob.posterName, 'Business Owner');
      expect(corruptJob.createdAt, isA<DateTime>());

      // Corrupted AppUser map
      final corruptUser = AppUser.fromMap({
        'displayName': null,
        'phone': null,
        'role': 'non_existent_role_xyz',
        'city': null,
        'rating': null,
        'createdAt': null,
      }, 'fallback_user_001');

      expect(corruptUser.id, 'fallback_user_001');
      expect(corruptUser.displayName, 'User');
      expect(corruptUser.role, UserRole.seeker);
      expect(corruptUser.city, 'Accra');
      expect(corruptUser.rating, 5.0);

      // Corrupted ChatMessage map
      final corruptMessage = ChatMessage.fromMap({
        'senderId': null,
        'senderName': null,
        'text': null,
        'timestamp': null,
      }, 'fallback_msg_001');

      expect(corruptMessage.id, 'fallback_msg_001');
      expect(corruptMessage.text, '');
      expect(corruptMessage.senderName, '');
      expect(corruptMessage.timestamp, isA<DateTime>());

      // Corrupted JobApplication map
      final corruptApp = JobApplication.fromMap({
        'jobId': null,
        'jobTitle': null,
        'seekerId': null,
        'seekerName': null,
        'posterId': null,
        'status': 'unknown_status_code',
        'note': 'some notes',
        'appliedAt': null,
      }, 'fallback_app_001');

      expect(corruptApp.id, 'fallback_app_001');
      expect(corruptApp.status, ApplicationStatus.pending);
      expect(corruptApp.note, 'some notes');
      expect(corruptApp.appliedAt, isA<DateTime>());
    });
  });

  group(
    'Empirical Challenge 3: Filter Combinations & Clean Empty State UI Rendering',
    () {
      Widget buildTestableWidget(
        Widget child, {
        JobProvider? jobProvider,
        ChatProvider? chatProvider,
        AuthProvider? authProvider,
      }) {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(
              create: (_) =>
                  authProvider ?? AuthProvider(startAuthenticated: true),
            ),
            ChangeNotifierProvider<JobProvider>(
              create: (_) => jobProvider ?? JobProvider(),
            ),
            ChangeNotifierProvider<ChatProvider>(
              create: (_) => chatProvider ?? ChatProvider(),
            ),
          ],
          child: MaterialApp(theme: AppTheme.lightTheme, home: child),
        );
      }

      testWidgets(
        'JobFeedScreen renders empty state when city + category + query yields 0 matches',
        (tester) async {
          final jobProvider = JobProvider();
          await tester.pumpWidget(
            buildTestableWidget(
              const JobFeedScreen(),
              jobProvider: jobProvider,
            ),
          );
          await tester.pumpAndSettle();

          // Initial state has jobs
          expect(
            find.text('No jobs found matching your criteria.'),
            findsNothing,
          );
          expect(jobProvider.filteredJobs.isNotEmpty, true);

          // Set combination that yields 0 matches via search text field input
          await tester.enterText(
            find.byType(TextField),
            'NonExistentLandmark99999',
          );
          jobProvider.setCityFilter('Kumasi');
          jobProvider.setCategoryFilter('Transport');
          await tester.pumpAndSettle();

          // Verify empty state is rendered cleanly
          expect(jobProvider.filteredJobs.isEmpty, true);
          expect(find.byIcon(Icons.search_off), findsOneWidget);
          expect(
            find.text('No jobs found matching your criteria.'),
            findsOneWidget,
          );
          expect(
            find.text('Try adjusting your city or search keywords.'),
            findsOneWidget,
          );

          // Clear search via clear icon
          expect(find.byIcon(Icons.clear), findsOneWidget);
          await tester.tap(find.byIcon(Icons.clear));
          await tester.pumpAndSettle();
          expect(jobProvider.searchQuery, '');
        },
      );

      testWidgets(
        'FavoritesScreen renders clean empty state when no jobs are favorited',
        (tester) async {
          final jobProvider = JobProvider();
          await tester.pumpWidget(
            buildTestableWidget(
              const FavoritesScreen(),
              jobProvider: jobProvider,
            ),
          );
          await tester.pumpAndSettle();

          // Verify empty state
          expect(jobProvider.favoriteJobs.isEmpty, true);
          expect(find.byIcon(Icons.favorite_border), findsOneWidget);
          expect(find.text('No saved jobs yet.'), findsOneWidget);
          expect(
            find.text('Tap the heart icon on any job posting to save it here.'),
            findsOneWidget,
          );

          // Add a favorite
          final firstJobId = jobProvider.allJobs.first.id;
          await jobProvider.toggleFavorite(firstJobId);
          await tester.pumpAndSettle();

          // Verify empty state disappears and job card appears
          expect(find.text('No saved jobs yet.'), findsNothing);
          expect(jobProvider.favoriteJobs.length, 1);

          // Remove favorite
          await jobProvider.toggleFavorite(firstJobId);
          await tester.pumpAndSettle();

          // Verify empty state reappears
          expect(find.text('No saved jobs yet.'), findsOneWidget);
        },
      );

      testWidgets(
        'ChatListScreen renders clean empty state when no chat rooms exist',
        (tester) async {
          final chatRepo = InMemoryChatRepository();
          final chatProvider = ChatProvider(chatRepository: chatRepo);
          await tester.pumpWidget(
            buildTestableWidget(
              const ChatListScreen(),
              chatProvider: chatProvider,
            ),
          );
          await tester.pumpAndSettle();

          // Check if chat list shows conversations or empty state
          if (chatProvider.rooms.isEmpty) {
            expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
            expect(find.text('No active chats yet.'), findsOneWidget);
            expect(
              find.text('Tap "Start Chat with Employer" on any job post.'),
              findsOneWidget,
            );
          } else {
            expect(find.text('Messages & Direct Chat'), findsOneWidget);
          }
        },
      );

      testWidgets(
        'CreateJobScreen form input boundary and validation enforcement',
        (tester) async {
          final jobProvider = JobProvider();
          await tester.pumpWidget(
            buildTestableWidget(
              const CreateJobScreen(),
              jobProvider: jobProvider,
            ),
          );
          await tester.pumpAndSettle();

          final submitBtn = find.text('Publish Job Posting');
          expect(submitBtn, findsOneWidget);

          // Scroll until submit button is visible and tap it
          await tester.ensureVisible(submitBtn);
          await tester.pumpAndSettle();
          await tester.tap(submitBtn);
          await tester.pumpAndSettle();

          // Verify validation error messages
          expect(find.text('Please enter a title'), findsOneWidget);
          expect(find.text('Enter pay'), findsOneWidget);
          expect(find.text('Please enter job description'), findsOneWidget);

          // Fill in all required fields
          await tester.enterText(
            find.widgetWithText(TextFormField, 'Job Title'),
            'Tema Port Container Offloader',
          );
          await tester.enterText(
            find.widgetWithText(TextFormField, 'Pay Amount (GHS)'),
            '250',
          );
          await tester.enterText(
            find.widgetWithText(TextFormField, 'Exact Location / Landmark'),
            'Tema Port Berth 2',
          );
          await tester.enterText(
            find.widgetWithText(TextFormField, 'Contact Phone Number'),
            '+233 24 999 8877',
          );
          await tester.enterText(
            find.widgetWithText(
              TextFormField,
              'Job Description & Requirements',
            ),
            'Heavy lifting at container terminal from 7am to 4pm. Cash at end of day.',
          );
          await tester.pumpAndSettle();

          // Submit valid form
          await tester.ensureVisible(submitBtn);
          await tester.pumpAndSettle();
          await tester.tap(submitBtn);
          await tester.pumpAndSettle();

          // Verify SnackBar confirmation and job added
          expect(
            find.text('Job posting created successfully!'),
            findsOneWidget,
          );
          expect(
            jobProvider.allJobs.any(
              (j) => j.title == 'Tema Port Container Offloader',
            ),
            true,
          );
          expect(jobProvider.allJobs.first.payRate, 250.0);
        },
      );

      testWidgets(
        'JobDetailScreen switches role warning banner and chat action reactively',
        (tester) async {
          final jobProvider = JobProvider();
          final firstJob = jobProvider.allJobs.first;

          await tester.pumpWidget(
            buildTestableWidget(
              JobDetailScreen(jobId: firstJob.id),
              jobProvider: jobProvider,
            ),
          );
          await tester.pumpAndSettle();

          // In Seeker mode (default), button to Start Chat with Employer is visible
          expect(find.text('Start Chat with Employer'), findsOneWidget);
          expect(
            find.text(
              'You are viewing this listing in Employer mode. Switch role in Profile to apply.',
            ),
            findsNothing,
          );

          // Switch to Employer mode
          jobProvider.setRole(UserRole.poster);
          await tester.pumpAndSettle();

          // In Employer mode, role warning banner is shown and chat button is hidden
          expect(find.text('Start Chat with Employer'), findsNothing);
          expect(
            find.text(
              'You are viewing this listing in Employer mode. Switch role in Profile to apply.',
            ),
            findsOneWidget,
          );
        },
      );
    },
  );
}
