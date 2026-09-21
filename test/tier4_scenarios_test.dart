import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_job_connector/app/theme.dart';
import 'package:local_job_connector/core/models/job_model.dart';
import 'package:local_job_connector/core/models/user_model.dart';
import 'package:local_job_connector/core/providers/auth_provider.dart';
import 'package:local_job_connector/core/providers/chat_provider.dart';
import 'package:local_job_connector/core/providers/job_provider.dart';
import 'package:local_job_connector/core/repositories/chat_repository.dart';
import 'package:local_job_connector/core/repositories/job_repository.dart';
import 'package:local_job_connector/core/repositories/user_repository.dart';
import 'package:local_job_connector/core/services/location_service.dart';
import 'package:local_job_connector/features/chat/screens/chat_room_screen.dart';
import 'package:local_job_connector/features/favorites/screens/favorites_screen.dart';
import 'package:local_job_connector/features/jobs/screens/create_job_screen.dart';
import 'package:local_job_connector/features/jobs/screens/job_detail_screen.dart';
import 'package:local_job_connector/features/jobs/widgets/job_card.dart';
import 'package:provider/provider.dart';

Widget createScenarioTestApp(
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
  group('Ghana Coordinates & LocationService Verification', () {
    test('Verify exact latitude and longitude for Accra, Kumasi, and Tema', () {
      // Accra Center: Circle VIP / Kwame Nkrumah Overpass
      expect(LocationService.accraCenter.latitude, 5.5586);
      expect(LocationService.accraCenter.longitude, -0.2014);

      // Kumasi Center: Kejetia Market Complex
      expect(LocationService.kumasiCenter.latitude, 6.6961);
      expect(LocationService.kumasiCenter.longitude, -1.6234);

      // Tema Center: Community 1 Main Market
      expect(LocationService.temaCenter.latitude, 5.6424);
      expect(LocationService.temaCenter.longitude, 0.0050);

      // Verify getCityCoordinates lookup function
      expect(
        LocationService.getCityCoordinates('Accra'),
        LocationService.accraCenter,
      );
      expect(
        LocationService.getCityCoordinates('accra'),
        LocationService.accraCenter,
      );
      expect(
        LocationService.getCityCoordinates('ACCRA'),
        LocationService.accraCenter,
      );
      expect(
        LocationService.getCityCoordinates('Kumasi'),
        LocationService.kumasiCenter,
      );
      expect(
        LocationService.getCityCoordinates('kumasi'),
        LocationService.kumasiCenter,
      );
      expect(
        LocationService.getCityCoordinates('Tema'),
        LocationService.temaCenter,
      );
      expect(
        LocationService.getCityCoordinates('tema'),
        LocationService.temaCenter,
      );
      expect(
        LocationService.getCityCoordinates('UnknownCity'),
        LocationService.accraCenter,
      );
    });

    test(
      'Distance calculation between Accra and Kumasi is approximately ~200 km',
      () {
        final distanceKm = LocationService.calculateDistanceKm(
          startLatitude: LocationService.accraCenter.latitude,
          startLongitude: LocationService.accraCenter.longitude,
          endLatitude: LocationService.kumasiCenter.latitude,
          endLongitude: LocationService.kumasiCenter.longitude,
        );

        expect(distanceKm, greaterThan(180.0));
        expect(distanceKm, lessThan(220.0));

        final formatted = LocationService.formatDistance(distanceKm);
        expect(formatted.contains('km away'), true);
      },
    );

    test(
      'Distance calculation between Accra and Tema is approximately ~25 km',
      () {
        final distanceKm = LocationService.calculateDistanceKm(
          startLatitude: LocationService.accraCenter.latitude,
          startLongitude: LocationService.accraCenter.longitude,
          endLatitude: LocationService.temaCenter.latitude,
          endLongitude: LocationService.temaCenter.longitude,
        );

        expect(distanceKm, greaterThan(15.0));
        expect(distanceKm, lessThan(35.0));
        expect(
          LocationService.formatDistance(distanceKm).contains('km away'),
          true,
        );
      },
    );

    test(
      'Distance formatting handles short meters and standard kilometers',
      () {
        expect(LocationService.formatDistance(0.45), '450 m away');
        expect(LocationService.formatDistance(1.234), '1.2 km away');
        expect(LocationService.formatDistance(0.0), '');
        expect(LocationService.formatDistance(-1.0), '');
      },
    );
  });

  group('Tier 4 Scenario 1: Accra Construction Laborer Flow', () {
    test(
      'Integration: Sign up as Seeker in Accra -> Filter Feed -> Favorite Circle VIP -> Initiate Chat -> Send Inquiry',
      () async {
        final userRepo = InMemoryUserRepository();
        final jobRepo = InMemoryJobRepository();
        final chatRepo = InMemoryChatRepository();

        final authProvider = AuthProvider(
          userRepository: userRepo,
          startAuthenticated: false,
        );
        final jobProvider = JobProvider(jobRepository: jobRepo);
        final chatProvider = ChatProvider(chatRepository: chatRepo);

        // 1. Sign up as Seeker in Accra
        final signupSuccess = await authProvider.signUpWithEmail(
          displayName: 'Kofi Mensah Laborer',
          email: 'kofi.laborer@gmail.com',
          password: 'password123',
          phone: '+233 24 123 4567',
          role: UserRole.seeker,
          city: 'Accra',
        );
        expect(signupSuccess, true);
        expect(authProvider.isAuthenticated, true);
        expect(authProvider.currentUser!.city, 'Accra');
        expect(authProvider.currentUser!.role, UserRole.seeker);

        // 2. Filter feed by Accra and Construction
        jobProvider.setCityFilter('Accra');
        jobProvider.setCategoryFilter('Construction & Labor');
        final filtered = jobProvider.filteredJobs;
        expect(filtered.isNotEmpty, true);
        expect(filtered.first.id, 'job_101');
        expect(filtered.first.title, 'Market Offloader & Heavy Carrier');
        expect(filtered.first.city, 'Accra');
        expect(filtered.first.payRate, 180.0);
        expect(filtered.first.latitude, 5.5586);
        expect(filtered.first.longitude, -0.2014);

        // 3. Save Circle VIP job to favorites
        expect(jobProvider.isFavorite('job_101'), false);
        await jobProvider.toggleFavorite('job_101');
        expect(jobProvider.isFavorite('job_101'), true);
        expect(jobProvider.favoriteJobs.any((j) => j.id == 'job_101'), true);

        // 4. Initiate Chat with employer
        final roomId = chatProvider.getOrCreateRoom(
          jobId: 'job_101',
          jobTitle: 'Market Offloader & Heavy Carrier',
          seekerId: authProvider.currentUser!.id,
          seekerName: authProvider.currentUser!.displayName,
          posterId: filtered.first.posterId,
          posterName: filtered.first.posterName,
        );
        expect(roomId.isNotEmpty, true);

        // 5. Send inquiry message
        chatProvider.sendMessage(
          roomId: roomId,
          senderId: authProvider.currentUser!.id,
          senderName: authProvider.currentUser!.displayName,
          text: 'Hello Madam Akosua, I am ready for the Circle VIP gig.',
        );

        final messages = chatProvider.getMessages(roomId);
        expect(
          messages.last.text,
          'Hello Madam Akosua, I am ready for the Circle VIP gig.',
        );
        expect(messages.last.senderName, 'Kofi Mensah Laborer');
      },
    );

    testWidgets(
      'Widget flow: JobDetailScreen allows Seeker to favorite and chat with employer',
      (WidgetTester tester) async {
        final jobProvider = JobProvider(jobRepository: InMemoryJobRepository());
        final chatProvider = ChatProvider(
          chatRepository: InMemoryChatRepository(),
        );

        await tester.pumpWidget(
          createScenarioTestApp(
            const JobDetailScreen(jobId: 'job_101'),
            job: jobProvider,
            chat: chatProvider,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Market Offloader & Heavy Carrier'), findsOneWidget);
        expect(find.text('GHS 180 '), findsOneWidget);
        expect(find.text('Akosua Wholesale'), findsOneWidget);
        expect(find.text('Start Chat with Employer'), findsOneWidget);

        // Toggle favorite
        expect(jobProvider.isFavorite('job_101'), false);
        await tester.tap(find.byIcon(Icons.favorite_border));
        await tester.pumpAndSettle();
        expect(jobProvider.isFavorite('job_101'), true);
      },
    );

    testWidgets(
      'Widget flow: ChatRoomScreen renders messages and sends new inquiry',
      (WidgetTester tester) async {
        final chatProvider = ChatProvider(
          chatRepository: InMemoryChatRepository(),
        );

        await tester.pumpWidget(
          createScenarioTestApp(
            const ChatRoomScreen(
              roomId: 'chat_101',
              jobTitle: 'Market Offloader & Heavy Carrier',
              otherUserName: 'Akosua Wholesale',
            ),
            chat: chatProvider,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Akosua Wholesale'), findsOneWidget);
        expect(find.text('Market Offloader & Heavy Carrier'), findsOneWidget);

        await tester.enterText(
          find.byType(TextField),
          'I am at Circle VIP Terminal Container 14.',
        );
        await tester.tap(find.byIcon(Icons.send));
        await tester.pumpAndSettle();

        expect(
          find.text('I am at Circle VIP Terminal Container 14.'),
          findsOneWidget,
        );
      },
    );
  });

  group('Tier 4 Scenario 2: Kumasi Market Employer Flow', () {
    test(
      'Integration: Employer role -> Create Kejetia Market cleaning gig for 120 GHS -> Appears on feed & map coords',
      () async {
        final jobRepo = InMemoryJobRepository();
        final userRepo = InMemoryUserRepository();

        final authProvider = AuthProvider(
          userRepository: userRepo,
          startAuthenticated: true,
        );
        final jobProvider = JobProvider(jobRepository: jobRepo);

        // 1. Switch to Employer role
        await authProvider.switchRole(UserRole.poster);
        jobProvider.setRole(UserRole.poster);
        expect(authProvider.currentUser!.role, UserRole.poster);
        expect(jobProvider.currentUserRole, UserRole.poster);

        // 2. Post Kejetia Market cleaning gig for 120 GHS/day
        final newJob = JobPost(
          id: 'job_kumasi_clean_01',
          title: 'Kejetia Market Evening Cleaner',
          description:
              'Urgent cleaner required for evening store cleanup and sweeping at Kejetia.',
          category: 'Cleaning',
          payRate: 120.0,
          payUnit: 'per day',
          currency: 'GHS',
          city: 'Kumasi',
          locationName: 'Kejetia Central Market Stall 45, Kumasi',
          latitude: LocationService.kumasiCenter.latitude,
          longitude: LocationService.kumasiCenter.longitude,
          posterId: authProvider.currentUser!.id,
          posterName: authProvider.currentUser!.displayName,
          posterPhone: authProvider.currentUser!.phone,
          createdAt: DateTime.now(),
        );

        await jobProvider.addJob(newJob);

        // 3. Verify in feed & coordinates
        expect(
          jobProvider.allJobs.first.title,
          'Kejetia Market Evening Cleaner',
        );
        expect(jobProvider.allJobs.first.latitude, 6.6961);
        expect(jobProvider.allJobs.first.longitude, -1.6234);

        jobProvider.setCityFilter('Kumasi');
        expect(
          jobProvider.filteredJobs.any((j) => j.id == 'job_kumasi_clean_01'),
          true,
        );
      },
    );

    testWidgets(
      'Widget flow: CreateJobScreen validates form and posts job with Kumasi coordinates',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final jobProvider = JobProvider(jobRepository: InMemoryJobRepository());
        final initialCount = jobProvider.allJobs.length;

        await tester.pumpWidget(
          createScenarioTestApp(const CreateJobScreen(), job: jobProvider),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Job Title'),
          'Kejetia Evening Sweeper',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Pay Amount (GHS)'),
          '120',
        );

        // Select Kumasi City
        await tester.tap(
          find.widgetWithText(DropdownButtonFormField<String>, 'City'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Kumasi').last);
        await tester.pumpAndSettle();

        // Select Cleaning Category
        await tester.tap(
          find.widgetWithText(DropdownButtonFormField<String>, 'Category'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cleaning').last);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Exact Location / Landmark'),
          'Kejetia Central Market',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Job Description & Requirements'),
          'Evening cleanup required.',
        );

        await tester.ensureVisible(find.text('Publish Job Posting'));
        await tester.tap(find.text('Publish Job Posting'));
        await tester.pumpAndSettle();

        expect(jobProvider.allJobs.length, initialCount + 1);
        final created = jobProvider.allJobs.first;
        expect(created.title, 'Kejetia Evening Sweeper');
        expect(created.city, 'Kumasi');
        expect(created.latitude, 6.6961);
        expect(created.longitude, -1.6234);
      },
    );
  });

  group('Tier 4 Scenario 3: Tema Logistics Cross-Role Flow', () {
    test(
      'Integration: Seeker in Tema -> Switch role to Employer -> View Job (warning) -> Post Tema gig -> Switch to Seeker',
      () async {
        final userRepo = InMemoryUserRepository();
        final jobRepo = InMemoryJobRepository();

        final authProvider = AuthProvider(
          userRepository: userRepo,
          startAuthenticated: true,
        );
        final jobProvider = JobProvider(jobRepository: jobRepo);

        // 1. Seeker in Tema
        jobProvider.setCityFilter('Tema');
        expect(jobProvider.filteredJobs.isNotEmpty, true);
        expect(jobProvider.filteredJobs.first.city, 'Tema');

        // 2. Switch to Employer
        await authProvider.switchRole(UserRole.poster);
        jobProvider.setRole(UserRole.poster);
        expect(jobProvider.currentUserRole, UserRole.poster);

        // 3. Post new transport gig in Tema Port
        final temaJob = JobPost(
          id: 'job_tema_logistics_01',
          title: 'Tema Port Container Offloader',
          description: 'Offload electronics containers at Tema Port Gate 2.',
          category: 'Transport',
          payRate: 250.0,
          payUnit: 'per day',
          currency: 'GHS',
          city: 'Tema',
          locationName: 'Tema Port Gate 2',
          latitude: LocationService.temaCenter.latitude,
          longitude: LocationService.temaCenter.longitude,
          posterId: authProvider.currentUser!.id,
          posterName: authProvider.currentUser!.displayName,
          posterPhone: authProvider.currentUser!.phone,
          createdAt: DateTime.now(),
        );
        await jobProvider.addJob(temaJob);

        // 4. Switch back to Seeker
        await authProvider.switchRole(UserRole.seeker);
        jobProvider.setRole(UserRole.seeker);
        expect(jobProvider.currentUserRole, UserRole.seeker);

        // 5. Seeker sees new Tema gig in feed
        jobProvider.setCityFilter('Tema');
        expect(
          jobProvider.filteredJobs.first.title,
          'Tema Port Container Offloader',
        );
        expect(jobProvider.filteredJobs.first.latitude, 5.6424);
        expect(jobProvider.filteredJobs.first.longitude, 0.0050);
      },
    );

    testWidgets(
      'Widget flow: ProfileScreen role switch dynamically changes JobDetailScreen CTA / Warning Banner',
      (WidgetTester tester) async {
        final authProvider = AuthProvider(
          userRepository: InMemoryUserRepository(),
          startAuthenticated: true,
        );
        final jobProvider = JobProvider(jobRepository: InMemoryJobRepository());

        // 1. Initial Seeker mode
        expect(jobProvider.currentUserRole, UserRole.seeker);

        await tester.pumpWidget(
          createScenarioTestApp(
            const JobDetailScreen(jobId: 'job_105'),
            auth: authProvider,
            job: jobProvider,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Start Chat with Employer'), findsOneWidget);
        expect(find.textContaining('Employer mode'), findsNothing);

        // 2. Switch to Employer mode
        jobProvider.setRole(UserRole.poster);

        await tester.pumpWidget(
          createScenarioTestApp(
            const JobDetailScreen(jobId: 'job_105'),
            auth: authProvider,
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
  });

  group('Tier 4 Scenario 4: Favorites Persistence & Filter Isolation', () {
    test(
      'Integration: Save 3 jobs -> Filter feed -> Favorites list unchanged -> Unfavorite 1 -> Updates reactive count',
      () async {
        final jobProvider = JobProvider(jobRepository: InMemoryJobRepository());

        // Save 3 jobs
        await jobProvider.toggleFavorite('job_101');
        await jobProvider.toggleFavorite('job_102');
        await jobProvider.toggleFavorite('job_103');

        expect(jobProvider.favoriteJobs.length, 3);
        expect(jobProvider.isFavorite('job_101'), true);
        expect(jobProvider.isFavorite('job_102'), true);
        expect(jobProvider.isFavorite('job_103'), true);

        // Filter feed to Tema (which has 1 job and none of 101, 102, 103)
        jobProvider.setCityFilter('Tema');
        expect(jobProvider.filteredJobs.length, 1);

        // Favorites must still contain all 3 saved jobs (isolated from feed filters)
        expect(jobProvider.favoriteJobs.length, 3);

        // Unfavorite 1 job
        await jobProvider.toggleFavorite('job_102');
        expect(jobProvider.favoriteJobs.length, 2);
        expect(jobProvider.isFavorite('job_102'), false);
      },
    );

    testWidgets(
      'Widget flow: FavoritesScreen displays all saved jobs and updates reactively on unfavorite',
      (WidgetTester tester) async {
        final jobProvider = JobProvider(jobRepository: InMemoryJobRepository());

        await jobProvider.toggleFavorite('job_101');
        await jobProvider.toggleFavorite('job_102');
        await jobProvider.toggleFavorite('job_103');

        // Set feed filter to Tema
        jobProvider.setCityFilter('Tema');

        await tester.pumpWidget(
          createScenarioTestApp(const FavoritesScreen(), job: jobProvider),
        );
        await tester.pumpAndSettle();

        expect(find.text('Saved Jobs / Favorites'), findsOneWidget);
        expect(find.byType(JobCard), findsNWidgets(3));
        expect(find.text('Market Offloader & Heavy Carrier'), findsOneWidget);
        expect(find.text('Casual Restaurant Waiter / Server'), findsOneWidget);
        expect(find.text('Store Cleaner & Goods Packager'), findsOneWidget);

        // Unfavorite job_102
        await jobProvider.toggleFavorite('job_102');
        await tester.pumpAndSettle();

        expect(find.byType(JobCard), findsNWidgets(2));
        expect(find.text('Casual Restaurant Waiter / Server'), findsNothing);
      },
    );
  });

  group('Tier 4 Scenario 5: Map View Explorer & City Navigation', () {
    test(
      'Integration: Ghana coordinates matching for Kejetia, Circle VIP, and Tema Port',
      () {
        final jobProvider = JobProvider(jobRepository: InMemoryJobRepository());

        // Kejetia job
        final kejetia = jobProvider.allJobs.firstWhere(
          (j) => j.id == 'job_103',
        );
        expect(kejetia.city, 'Kumasi');
        expect(kejetia.latitude, 6.6961);
        expect(kejetia.longitude, -1.6234);
        expect(kejetia.payRate, 150.0);

        // Circle VIP job
        final circle = jobProvider.allJobs.firstWhere((j) => j.id == 'job_101');
        expect(circle.city, 'Accra');
        expect(circle.latitude, 5.5586);
        expect(circle.longitude, -0.2014);
        expect(circle.payRate, 180.0);

        // Tema Port job
        final tema = jobProvider.allJobs.firstWhere((j) => j.id == 'job_105');
        expect(tema.city, 'Tema');
        expect(tema.latitude, 5.6424);
        expect(tema.longitude, 0.0050);
        expect(tema.payRate, 200.0);
      },
    );

    testWidgets(
      'Widget flow: JobDetailScreen for Kejetia marker shows complete metadata and employer contact',
      (WidgetTester tester) async {
        final jobProvider = JobProvider(jobRepository: InMemoryJobRepository());

        await tester.pumpWidget(
          createScenarioTestApp(
            const JobDetailScreen(jobId: 'job_103'),
            job: jobProvider,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Store Cleaner & Goods Packager'), findsOneWidget);
        expect(find.text('GHS 150 '), findsOneWidget);
        expect(find.text('Kejetia New Market, Kumasi, Kumasi'), findsOneWidget);
        expect(find.text('Osei Textiles'), findsOneWidget);
        expect(find.text('+233 27 333 4455'), findsOneWidget);
      },
    );
  });
}
