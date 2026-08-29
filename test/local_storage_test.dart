import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_job_connector/core/models/chat_model.dart';
import 'package:local_job_connector/core/models/job_application_model.dart';
import 'package:local_job_connector/core/models/job_model.dart';
import 'package:local_job_connector/core/models/user_model.dart';
import 'package:local_job_connector/core/providers/auth_provider.dart';
import 'package:local_job_connector/core/providers/chat_provider.dart';
import 'package:local_job_connector/core/providers/job_provider.dart';
import 'package:local_job_connector/core/repositories/chat_repository.dart';
import 'package:local_job_connector/core/repositories/job_repository.dart';
import 'package:local_job_connector/core/repositories/user_repository.dart';
import 'package:local_job_connector/core/services/local_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalStorageService();
    await storage.init();
    LocalStorageService.instance.setPreferences(storage.prefs);
  });

  group('LocalStorageService — User Profile Persistence', () {
    test('Saves and retrieves AppUser correctly with full field fidelity', () async {
      final user = AppUser(
        id: 'usr_accra_123',
        displayName: 'Kwame Mensah',
        phone: '+233 24 123 4567',
        role: UserRole.seeker,
        city: 'Accra',
        rating: 4.8,
        avatarUrl: 'https://example.com/avatar.png',
        createdAt: DateTime(2026, 1, 15, 10, 30),
      );

      await storage.saveUser(user);
      final retrieved = storage.getUser();

      expect(retrieved, isNotNull);
      expect(retrieved!.id, equals('usr_accra_123'));
      expect(retrieved.displayName, equals('Kwame Mensah'));
      expect(retrieved.phone, equals('+233 24 123 4567'));
      expect(retrieved.role, equals(UserRole.seeker));
      expect(retrieved.city, equals('Accra'));
      expect(retrieved.rating, equals(4.8));
      expect(retrieved.avatarUrl, equals('https://example.com/avatar.png'));
      expect(retrieved.createdAt.toIso8601String(), equals(user.createdAt.toIso8601String()));
    });

    test('Clears user and returns null', () async {
      final user = AppUser(
        id: 'usr_test',
        displayName: 'Test User',
        phone: '+233 20 000 0000',
        role: UserRole.poster,
        city: 'Kumasi',
        createdAt: DateTime.now(),
      );

      await storage.saveUser(user);
      expect(storage.getUser(), isNotNull);

      await storage.clearUser();
      expect(storage.getUser(), isNull);
    });

    test('Gracefully returns null when storage is uninitialized or empty', () {
      final uninitStorage = LocalStorageService();
      expect(uninitStorage.getUser(), isNull);
    });
  });

  group('LocalStorageService — Job Posts Persistence', () {
    test('Saves and retrieves list of JobPosts with exact metadata', () async {
      final jobs = [
        JobPost(
          id: 'job_001',
          title: 'Heavy Truck Offloader',
          description: 'Offload cement bags at Tema Harbor',
          category: 'Logistics',
          payRate: 150.0,
          payUnit: 'per day',
          currency: 'GHS',
          city: 'Tema',
          locationName: 'Tema Port Gate 2',
          latitude: 5.6424,
          longitude: 0.0050,
          posterId: 'poster_01',
          posterName: 'Tema Logistics Hub',
          posterPhone: '+233 24 999 8888',
          isFilled: false,
          isFavorite: true,
          createdAt: DateTime(2026, 2, 1, 8, 0),
        ),
        JobPost(
          id: 'job_002',
          title: 'Market Fruit Stall Assistant',
          description: 'Sort and bag oranges at Kejetia',
          category: 'Retail',
          payRate: 80.0,
          payUnit: 'per day',
          currency: 'GHS',
          city: 'Kumasi',
          locationName: 'Kejetia Market Lane 4',
          latitude: 6.6961,
          longitude: -1.6234,
          posterId: 'poster_02',
          posterName: 'Mama Serwaa Fruits',
          posterPhone: '+233 50 111 2222',
          isFilled: true,
          isFavorite: false,
          createdAt: DateTime(2026, 2, 2, 9, 30),
        ),
      ];

      await storage.saveJobs(jobs);
      final retrieved = storage.getJobs();

      expect(retrieved.length, equals(2));
      expect(retrieved[0].id, equals('job_001'));
      expect(retrieved[0].title, equals('Heavy Truck Offloader'));
      expect(retrieved[0].payRate, equals(150.0));
      expect(retrieved[0].city, equals('Tema'));
      expect(retrieved[0].isFavorite, isTrue);

      expect(retrieved[1].id, equals('job_002'));
      expect(retrieved[1].title, equals('Market Fruit Stall Assistant'));
      expect(retrieved[1].isFilled, isTrue);
      expect(retrieved[1].isFavorite, isFalse);
    });

    test('Handles cold restart: reloaded service recovers stored jobs', () async {
      final jobs = [
        JobPost(
          id: 'job_persist_test',
          title: 'Cold Restart Job',
          description: 'Persistence validation',
          category: 'Construction',
          payRate: 200.0,
          city: 'Accra',
          locationName: 'Circle VIP',
          latitude: 5.5586,
          longitude: -0.2014,
          posterId: 'poster_vip',
          posterName: 'VIP Transport',
          posterPhone: '+233 24 555 6666',
          createdAt: DateTime.now(),
        ),
      ];

      await storage.saveJobs(jobs);

      // Simulate cold restart by re-initializing storage against same SharedPreferences
      final restartedStorage = LocalStorageService(prefs: storage.prefs);
      final hydratedJobs = restartedStorage.getJobs();

      expect(hydratedJobs.length, equals(1));
      expect(hydratedJobs.first.id, equals('job_persist_test'));
      expect(hydratedJobs.first.title, equals('Cold Restart Job'));
    });
  });

  group('LocalStorageService — Favorites Persistence', () {
    test('Saves, retrieves, and persists favorite IDs set', () async {
      final favoriteIds = {'job_accra_1', 'job_kumasi_2', 'job_tema_3'};
      await storage.saveFavorites(favoriteIds);

      final retrieved = storage.getFavorites();
      expect(retrieved, equals(favoriteIds));

      final restartedStorage = LocalStorageService(prefs: storage.prefs);
      expect(restartedStorage.getFavorites(), equals(favoriteIds));
    });

    test('Returns empty set when no favorites are saved', () {
      expect(storage.getFavorites(), isEmpty);
    });
  });

  group('LocalStorageService — Chat Rooms and Messages Persistence', () {
    test('Saves and retrieves ChatRoom metadata', () async {
      final rooms = [
        ChatRoom(
          id: 'room_101',
          jobId: 'job_001',
          jobTitle: 'Heavy Truck Offloader',
          seekerId: 'seeker_01',
          seekerName: 'Kofi Mensah',
          posterId: 'poster_01',
          posterName: 'Tema Logistics Hub',
          lastMessage: 'Ready to work tomorrow morning!',
          updatedAt: DateTime(2026, 2, 10, 14, 0),
        ),
      ];

      await storage.saveChatRooms(rooms);
      final retrieved = storage.getChatRooms();

      expect(retrieved.length, equals(1));
      expect(retrieved.first.id, equals('room_101'));
      expect(retrieved.first.jobTitle, equals('Heavy Truck Offloader'));
      expect(retrieved.first.lastMessage, equals('Ready to work tomorrow morning!'));
    });

    test('Saves and retrieves ChatMessages isolated by room ID', () async {
      final room1Messages = [
        ChatMessage(
          id: 'msg_1',
          senderId: 'seeker_01',
          senderName: 'Kofi',
          text: 'Hello sir',
          timestamp: DateTime(2026, 2, 10, 14, 0),
          isRead: true,
        ),
        ChatMessage(
          id: 'msg_2',
          senderId: 'poster_01',
          senderName: 'Manager',
          text: 'Welcome Kofi, be at Tema by 7am',
          timestamp: DateTime(2026, 2, 10, 14, 5),
          isRead: true,
        ),
      ];

      final room2Messages = [
        ChatMessage(
          id: 'msg_3',
          senderId: 'seeker_02',
          senderName: 'Ama',
          text: 'Is the fruit stall job still open?',
          timestamp: DateTime(2026, 2, 10, 15, 0),
          isRead: false,
        ),
      ];

      await storage.saveMessages('room_1', room1Messages);
      await storage.saveMessages('room_2', room2Messages);

      final retrievedRoom1 = storage.getMessages('room_1');
      final retrievedRoom2 = storage.getMessages('room_2');

      expect(retrievedRoom1.length, equals(2));
      expect(retrievedRoom1[0].text, equals('Hello sir'));
      expect(retrievedRoom1[1].text, equals('Welcome Kofi, be at Tema by 7am'));

      expect(retrievedRoom2.length, equals(1));
      expect(retrievedRoom2[0].text, equals('Is the fruit stall job still open?'));

      // Non-existent room returns empty list
      expect(storage.getMessages('room_nonexistent'), isEmpty);
    });
  });

  group('LocalStorageService — Job Applications Persistence', () {
    test('Saves and retrieves JobApplication list', () async {
      final applications = [
        JobApplication(
          id: 'app_001',
          jobId: 'job_001',
          jobTitle: 'Heavy Truck Offloader',
          seekerId: 'seeker_01',
          seekerName: 'Kofi Mensah',
          seekerPhone: '+233 24 123 4567',
          posterId: 'poster_01',
          status: ApplicationStatus.pending,
          note: 'I have 5 years experience at Tema harbor.',
          appliedAt: DateTime(2026, 2, 12, 11, 0),
        ),
        JobApplication(
          id: 'app_002',
          jobId: 'job_002',
          jobTitle: 'Market Fruit Stall Assistant',
          seekerId: 'seeker_02',
          seekerName: 'Ama Boateng',
          seekerPhone: '+233 20 987 6543',
          posterId: 'poster_02',
          status: ApplicationStatus.accepted,
          note: 'Available full-time.',
          appliedAt: DateTime(2026, 2, 12, 12, 0),
        ),
      ];

      await storage.saveApplications(applications);
      final retrieved = storage.getApplications();

      expect(retrieved.length, equals(2));
      expect(retrieved[0].id, equals('app_001'));
      expect(retrieved[0].status, equals(ApplicationStatus.pending));
      expect(retrieved[0].note, equals('I have 5 years experience at Tema harbor.'));

      expect(retrieved[1].id, equals('app_002'));
      expect(retrieved[1].status, equals(ApplicationStatus.accepted));
    });
  });

  group('LocalStorageService — Clear All', () {
    test('clearAll() wipes all cached entries', () async {
      await storage.saveUser(AppUser(
        id: 'u1',
        displayName: 'User',
        phone: '123',
        role: UserRole.seeker,
        city: 'Accra',
        createdAt: DateTime.now(),
      ));
      await storage.saveFavorites({'fav1', 'fav2'});
      await storage.saveJobs([
        JobPost(
          id: 'j1',
          title: 'Job 1',
          description: 'Desc',
          category: 'Other',
          payRate: 100,
          city: 'Accra',
          locationName: 'Accra',
          latitude: 5.5,
          longitude: -0.2,
          posterId: 'p1',
          posterName: 'P1',
          posterPhone: '123',
          createdAt: DateTime.now(),
        )
      ]);

      expect(storage.getUser(), isNotNull);
      expect(storage.getFavorites(), isNotEmpty);
      expect(storage.getJobs(), isNotEmpty);

      await storage.clearAll();

      expect(storage.getUser(), isNull);
      expect(storage.getFavorites(), isEmpty);
      expect(storage.getJobs(), isEmpty);
    });
  });

  group('Provider Cold-Restart & Mutation Hydration Tests', () {
    test('AuthProvider hydrates stored user on cold start and persists role changes', () async {
      final savedUser = AppUser(
        id: 'custom_usr_99',
        displayName: 'Abena Star',
        phone: '+233 24 777 8888',
        role: UserRole.poster,
        city: 'Kumasi',
        rating: 4.9,
        createdAt: DateTime.now(),
      );

      await storage.saveUser(savedUser);

      // Create new AuthProvider with the storage
      final authProvider = AuthProvider(
        userRepository: InMemoryUserRepository(),
        localStorageService: storage,
      );

      expect(authProvider.isAuthenticated, isTrue);
      expect(authProvider.currentUser?.id, equals('custom_usr_99'));
      expect(authProvider.currentUser?.displayName, equals('Abena Star'));
      expect(authProvider.currentUser?.role, equals(UserRole.poster));

      // Switch role and verify saved to storage
      await authProvider.switchRole(UserRole.seeker);
      expect(authProvider.currentUser?.role, equals(UserRole.seeker));

      final persistedUser = storage.getUser();
      expect(persistedUser?.role, equals(UserRole.seeker));
    });

    test('JobProvider hydrates stored jobs and favorites and updates storage on mutations', () async {
      final customJob = JobPost(
        id: 'job_custom_007',
        title: 'Electrical Repair in Osu',
        description: 'Fix wiring in restaurant kitchen',
        category: 'Maintenance',
        payRate: 350.0,
        city: 'Accra',
        locationName: 'Oxford Street, Osu',
        latitude: 5.5560,
        longitude: -0.1800,
        posterId: 'poster_osu',
        posterName: 'Osu Bistro',
        posterPhone: '+233 24 333 4444',
        createdAt: DateTime.now(),
      );

      await storage.saveJobs([customJob]);
      await storage.saveFavorites({'job_custom_007'});

      final jobRepo = InMemoryJobRepository(initialJobs: [customJob]);
      final jobProvider = JobProvider(
        jobRepository: jobRepo,
        localStorageService: storage,
      );

      expect(jobProvider.allJobs.length, equals(1));
      expect(jobProvider.allJobs.first.title, equals('Electrical Repair in Osu'));
      expect(jobProvider.isFavorite('job_custom_007'), isTrue);

      // Add another job and verify storage is updated
      final newJob = JobPost(
        id: 'job_custom_008',
        title: 'Carpentry at Ridge',
        description: 'Assemble wooden shelves',
        category: 'Construction',
        payRate: 200.0,
        city: 'Accra',
        locationName: 'Ridge Towers',
        latitude: 5.5600,
        longitude: -0.1900,
        posterId: 'poster_ridge',
        posterName: 'Ridge Estates',
        posterPhone: '+233 20 444 5555',
        createdAt: DateTime.now(),
      );

      await jobProvider.addJob(newJob);
      expect(jobProvider.allJobs.length, equals(2));

      final persistedJobs = storage.getJobs();
      expect(persistedJobs.length, equals(2));
      expect(persistedJobs.any((j) => j.id == 'job_custom_008'), isTrue);
    });

    test('ChatProvider hydrates stored rooms and messages and updates storage on send', () async {
      final room = ChatRoom(
        id: 'chat_persisted_1',
        jobId: 'job_001',
        jobTitle: 'Offloader',
        seekerId: 'seeker_01',
        seekerName: 'Kofi',
        posterId: 'poster_01',
        posterName: 'Akosua',
        lastMessage: 'Let us meet tomorrow',
        updatedAt: DateTime.now(),
      );

      final message = ChatMessage(
        id: 'msg_p1',
        senderId: 'seeker_01',
        senderName: 'Kofi',
        text: 'Let us meet tomorrow',
        timestamp: DateTime.now(),
        isRead: true,
      );

      await storage.saveChatRooms([room]);
      await storage.saveMessages('chat_persisted_1', [message]);

      final chatProvider = ChatProvider(
        chatRepository: InMemoryChatRepository(),
        localStorageService: storage,
        currentUserId: 'seeker_01',
      );

      expect(chatProvider.rooms.length, equals(1));
      expect(chatProvider.rooms.first.id, equals('chat_persisted_1'));

      final messages = chatProvider.getMessages('chat_persisted_1');
      expect(messages.length, equals(1));
      expect(messages.first.text, equals('Let us meet tomorrow'));

      // Send a new message
      chatProvider.sendMessage(
        roomId: 'chat_persisted_1',
        senderId: 'poster_01',
        senderName: 'Akosua',
        text: 'Confirmed, see you at 8am.',
      );

      final updatedMessages = chatProvider.getMessages('chat_persisted_1');
      expect(updatedMessages.length, equals(2));

      final persistedMsgs = storage.getMessages('chat_persisted_1');
      expect(persistedMsgs.length, equals(2));
      expect(persistedMsgs.last.text, equals('Confirmed, see you at 8am.'));
    });
  });
}
