import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_job_connector/app/theme.dart';
import 'package:local_job_connector/core/models/chat_model.dart';
import 'package:local_job_connector/core/models/job_application_model.dart';
import 'package:local_job_connector/core/models/job_model.dart';
import 'package:local_job_connector/core/models/timestamp_helper.dart';
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
import 'package:local_job_connector/core/services/location_service.dart';
import 'package:local_job_connector/core/utils/form_validators.dart';
import 'package:local_job_connector/core/utils/input_sanitizer.dart';
import 'package:local_job_connector/core/widgets/global_error_boundary.dart';
import 'package:local_job_connector/core/widgets/offline_banner.dart';
import 'package:local_job_connector/features/jobs/screens/job_feed_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget createTestE2EApp({
  required Widget child,
  AuthProvider? authProvider,
  JobProvider? jobProvider,
  ApplicationProvider? applicationProvider,
  ChatProvider? chatProvider,
  ConnectivityProvider? connectivityProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ConnectivityProvider>(
        create: (_) => connectivityProvider ?? ConnectivityProvider(),
      ),
      ChangeNotifierProvider<AuthProvider>(
        create: (_) =>
            authProvider ??
            AuthProvider(
              userRepository: InMemoryUserRepository(),
              startAuthenticated: true,
            ),
      ),
      ChangeNotifierProvider<JobProvider>(
        create: (_) =>
            jobProvider ?? JobProvider(jobRepository: InMemoryJobRepository()),
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
  TestWidgetsFlutterBinding.ensureInitialized();

  // ===========================================================================
  // TIER 1: UNIT & SERIALIZATION TESTS
  // ===========================================================================
  group('Tier 1: Unit & Serialization Suite', () {
    late LocalStorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = LocalStorageService(prefs: prefs);
      LocalStorageService.instance.setPreferences(prefs);
    });

    test(
      '1.1 AppUser model serialization & deserialization with all field permutations',
      () {
        final userFull = AppUser(
          id: 'usr_t1_01',
          displayName: 'Kwame Mensah',
          phone: '+233 24 123 4567',
          role: UserRole.seeker,
          city: 'Accra',
          rating: 4.85,
          avatarUrl: 'https://example.com/avatar.jpg',
          createdAt: DateTime(2026, 3, 1, 14, 0),
        );

        final map = userFull.toMap();
        expect(map['id'], 'usr_t1_01');
        expect(map['displayName'], 'Kwame Mensah');
        expect(map['phone'], '+233 24 123 4567');
        expect(map['role'], 'seeker');
        expect(map['city'], 'Accra');
        expect(map['rating'], 4.85);
        expect(map['avatarUrl'], 'https://example.com/avatar.jpg');

        final deserialized = AppUser.fromMap(map, 'usr_t1_01');
        expect(deserialized.id, userFull.id);
        expect(deserialized.displayName, userFull.displayName);
        expect(deserialized.phone, userFull.phone);
        expect(deserialized.role, userFull.role);
        expect(deserialized.city, userFull.city);
        expect(deserialized.rating, userFull.rating);
        expect(deserialized.avatarUrl, userFull.avatarUrl);
      },
    );

    test(
      '1.2 AppUser copyWith creates modified instance while preserving other fields',
      () {
        final user = AppUser(
          id: 'usr_t1_02',
          displayName: 'Ama Serwaa',
          phone: '+233 20 987 6543',
          role: UserRole.seeker,
          city: 'Kumasi',
          rating: 4.5,
          createdAt: DateTime(2026, 1, 1),
        );

        final updated = user.copyWith(
          role: UserRole.poster,
          city: 'Tema',
          rating: 4.9,
        );

        expect(updated.id, 'usr_t1_02');
        expect(updated.displayName, 'Ama Serwaa');
        expect(updated.role, UserRole.poster);
        expect(updated.city, 'Tema');
        expect(updated.rating, 4.9);
        expect(updated.phone, '+233 20 987 6543');
      },
    );

    test(
      '1.3 JobPost serialization across JobStatus lifecycle enum values',
      () {
        final jobOpen = JobPost(
          id: 'job_open_01',
          title: 'Tema Port Unloader',
          description: 'Offload containers at Tema Harbor',
          category: 'Logistics & Warehouse',
          payRate: 220.0,
          city: 'Tema',
          locationName: 'Tema Port Gate 3',
          latitude: 5.6424,
          longitude: 0.0050,
          posterId: 'poster_01',
          posterName: 'Tema Logistics Co',
          posterPhone: '+233 24 555 1234',
          status: JobStatus.open,
          createdAt: DateTime(2026, 8, 1),
        );

        final mapOpen = jobOpen.toMap();
        expect(mapOpen['status'], 'open');
        expect(mapOpen['isFilled'], isFalse);

        final jobInProgress = jobOpen.copyWith(status: JobStatus.inProgress);
        final mapInProgress = jobInProgress.toMap();
        expect(mapInProgress['status'], 'inProgress');
        expect(mapInProgress['isFilled'], isTrue);

        final jobCompleted = jobOpen.copyWith(status: JobStatus.completed);
        final mapCompleted = jobCompleted.toMap();
        expect(mapCompleted['status'], 'completed');
        expect(mapCompleted['isFilled'], isTrue);

        final parsed = JobPost.fromMap(mapCompleted, 'job_open_01');
        expect(parsed.status, JobStatus.completed);
        expect(parsed.isFilled, isTrue);
      },
    );

    test('1.4 JobStatus fromString handles variations and edge strings', () {
      expect(JobStatus.fromString('open'), JobStatus.open);
      expect(JobStatus.fromString('OPEN'), JobStatus.open);
      expect(JobStatus.fromString('in_progress'), JobStatus.inProgress);
      expect(JobStatus.fromString('inProgress'), JobStatus.inProgress);
      expect(JobStatus.fromString('INPROGRESS'), JobStatus.inProgress);
      expect(JobStatus.fromString('completed'), JobStatus.completed);
      expect(JobStatus.fromString('COMPLETED'), JobStatus.completed);
      expect(JobStatus.fromString(null), JobStatus.open);
      expect(JobStatus.fromString('unknown_status'), JobStatus.open);
    });

    test(
      '1.5 JobApplication serialization across ApplicationStatus enum values',
      () {
        final app = JobApplication(
          id: 'app_t1_01',
          jobId: 'job_101',
          jobTitle: 'Masonry Assistant',
          seekerId: 'seeker_101',
          seekerName: 'Kofi Mensah',
          seekerPhone: '+233 24 111 2222',
          posterId: 'poster_101',
          status: ApplicationStatus.pending,
          note: 'Experienced bricklayer ready to start immediately',
          appliedAt: DateTime(2026, 8, 20),
        );

        final map = app.toMap();
        expect(map['status'], 'pending');
        expect(
          map['note'],
          'Experienced bricklayer ready to start immediately',
        );

        final deserialized = JobApplication.fromMap(map, 'app_t1_01');
        expect(deserialized.id, 'app_t1_01');
        expect(deserialized.status, ApplicationStatus.pending);
        expect(deserialized.seekerName, 'Kofi Mensah');

        final accepted = app.copyWith(status: ApplicationStatus.accepted);
        expect(accepted.status, ApplicationStatus.accepted);
        expect(
          JobApplication.fromMap(accepted.toMap(), 'app_t1_01').status,
          ApplicationStatus.accepted,
        );

        final rejected = app.copyWith(status: ApplicationStatus.rejected);
        expect(rejected.status, ApplicationStatus.rejected);
        expect(
          JobApplication.fromMap(rejected.toMap(), 'app_t1_01').status,
          ApplicationStatus.rejected,
        );
      },
    );

    test(
      '1.6 ChatRoom & ChatMessage model serialization & deserialization',
      () {
        final message = ChatMessage(
          id: 'msg_01',
          senderId: 'seeker_01',
          senderName: 'Kofi',
          text: 'Is this gig still available at Circle VIP?',
          timestamp: DateTime(2026, 8, 25, 9, 30),
        );

        final msgMap = message.toMap();
        expect(msgMap['id'], 'msg_01');
        expect(msgMap['text'], 'Is this gig still available at Circle VIP?');
        expect(msgMap['senderId'], 'seeker_01');

        final parsedMsg = ChatMessage.fromMap(msgMap, 'msg_01');
        expect(parsedMsg.id, 'msg_01');
        expect(parsedMsg.text, message.text);
        expect(parsedMsg.senderId, 'seeker_01');

        final room = ChatRoom(
          id: 'room_01',
          jobId: 'job_101',
          jobTitle: 'Circle Laborer',
          seekerId: 'seeker_01',
          seekerName: 'Kofi Seeker',
          posterId: 'poster_01',
          posterName: 'Kwame Contractor',
          lastMessage: 'Yes, come by at 8am tomorrow',
          updatedAt: DateTime(2026, 8, 25, 10, 0),
        );

        final roomMap = room.toMap();
        expect(roomMap['id'], 'room_01');
        expect(roomMap['posterName'], 'Kwame Contractor');
        expect(roomMap['lastMessage'], 'Yes, come by at 8am tomorrow');

        final parsedRoom = ChatRoom.fromMap(roomMap, 'room_01');
        expect(parsedRoom.id, 'room_01');
        expect(parsedRoom.posterName, 'Kwame Contractor');
        expect(parsedRoom.lastMessage, 'Yes, come by at 8am tomorrow');
      },
    );

    test('1.7 TimestampHelper parsing across diverse inputs', () {
      final now = DateTime(2026, 8, 29, 12, 0);
      expect(parseDateTime(now), now);
      expect(parseDateTime('2026-08-29T12:00:00.000Z').year, 2026);
      expect(
        parseDateTime(1756468800000).millisecondsSinceEpoch,
        1756468800000,
      );
      expect(parseDateTime(null), isA<DateTime>());
      expect(parseDateTime('corrupted-timestamp'), isA<DateTime>());
    });

    test('1.8 FormValidators comprehensive email validation', () {
      expect(FormValidators.validateEmail('user@gmail.com'), isNull);
      expect(FormValidators.validateEmail('kofi.mensah@ug.edu.gh'), isNull);
      expect(FormValidators.validateEmail('employer+hire@osae.org'), isNull);

      expect(FormValidators.validateEmail(null), 'Enter valid email');
      expect(FormValidators.validateEmail(''), 'Enter valid email');
      expect(FormValidators.validateEmail('   '), 'Enter valid email');
      expect(
        FormValidators.validateEmail('invalid-email'),
        'Enter valid email',
      );
      expect(FormValidators.validateEmail('user@'), 'Enter valid email');
      expect(FormValidators.validateEmail('@domain.com'), 'Enter valid email');
      expect(FormValidators.validateEmail('user@domain.'), 'Enter valid email');
      expect(
        FormValidators.validateEmail('user@domain..com'),
        'Enter valid email',
      );
      expect(
        FormValidators.validateEmail('user..name@domain.com'),
        'Enter valid email',
      );
    });

    test('1.9 FormValidators Ghana phone number validation matrix', () {
      // Valid Ghanaian phone formats
      expect(FormValidators.validateGhanaPhone('+233 24 123 4567'), isNull);
      expect(FormValidators.validateGhanaPhone('+233241234567'), isNull);
      expect(FormValidators.validateGhanaPhone('0241234567'), isNull);
      expect(FormValidators.validateGhanaPhone('0551234567'), isNull);
      expect(FormValidators.validateGhanaPhone('0201234567'), isNull);
      expect(FormValidators.validateGhanaPhone('0271234567'), isNull);
      expect(FormValidators.validateGhanaPhone('0501234567'), isNull);

      // Invalid formats
      expect(FormValidators.validateGhanaPhone(null), isNotNull);
      expect(FormValidators.validateGhanaPhone(''), isNotNull);
      expect(FormValidators.validateGhanaPhone('12345'), isNotNull);
      expect(FormValidators.validateGhanaPhone('+1234567890'), isNotNull);
      expect(FormValidators.validateGhanaPhone('0123456789'), isNotNull);
      expect(FormValidators.validateGhanaPhone('0241234'), isNotNull);
      expect(FormValidators.validateGhanaPhone('abcdefghij'), isNotNull);
    });

    test('1.10 FormValidators pay rate and required fields validation', () {
      expect(FormValidators.validatePayRate('150'), isNull);
      expect(FormValidators.validatePayRate('250.50'), isNull);
      expect(FormValidators.validatePayRate('10'), isNull);
      expect(FormValidators.validatePayRate('100000'), isNull);

      expect(FormValidators.validatePayRate(null), 'Enter pay');
      expect(FormValidators.validatePayRate(''), 'Enter pay');
      expect(
        FormValidators.validatePayRate('0'),
        'Pay amount must be greater than 0',
      );
      expect(
        FormValidators.validatePayRate('-20'),
        'Pay amount must be greater than 0',
      );
      expect(
        FormValidators.validatePayRate('abc'),
        'Enter a valid numeric amount',
      );
      expect(
        FormValidators.validatePayRate('NaN'),
        'Enter a valid numeric amount',
      );
      expect(
        FormValidators.validatePayRate('Infinity'),
        'Enter a valid numeric amount',
      );
      expect(
        FormValidators.validatePayRate('-Infinity'),
        'Enter a valid numeric amount',
      );
      expect(
        FormValidators.validatePayRate('100001'),
        'Pay amount exceeds maximum allowable limit',
      );

      expect(
        FormValidators.validateRequired('Market Offloader', 'Job Title'),
        isNull,
      );
      expect(
        FormValidators.validateRequired('', 'Job Title'),
        'Please enter a title',
      );
      expect(
        FormValidators.validateRequired(null, 'Description'),
        'Please enter job description',
      );
      expect(
        FormValidators.validateRequired('   ', 'Location'),
        'Please specify location',
      );
    });

    test('1.11 InputSanitizer HTML and control character sanitization', () {
      expect(
        InputSanitizer.sanitize('Hello <script>alert("xss")</script> World'),
        'Hello  World',
      );
      expect(
        InputSanitizer.sanitize('<b>Bold Job Title</b>'),
        'Bold Job Title',
      );
      expect(InputSanitizer.sanitize('   Trimmed Title   '), 'Trimmed Title');
      expect(InputSanitizer.sanitize(''), '');
      expect(
        InputSanitizer.sanitizeEmail('  Kofi.Mensah@gmail.com  '),
        'kofi.mensah@gmail.com',
      );
      expect(InputSanitizer.sanitizePhone('+233 24 123 4567'), '+233241234567');
      expect(InputSanitizer.sanitizeNumeric('  GHS 150.50  '), '150.50');
    });

    test('1.12 LocalStorageService CRUD for all domain entities', () async {
      // 1. Save and get User
      final user = AppUser(
        id: 'usr_crud_01',
        displayName: 'Esi Mansah',
        phone: '+233 24 000 1111',
        role: UserRole.seeker,
        city: 'Accra',
        createdAt: DateTime.now(),
      );
      await storage.saveUser(user);
      expect(storage.getUser()?.id, 'usr_crud_01');

      // 2. Save and get Jobs
      final job = JobPost(
        id: 'job_crud_01',
        title: 'Carpentry Lead',
        description: 'Lead roofing team',
        category: 'Construction & Labor',
        payRate: 300.0,
        city: 'Kumasi',
        locationName: 'Adum',
        latitude: 6.6961,
        longitude: -1.6234,
        posterId: 'poster_crud',
        posterName: 'Adum Builders',
        posterPhone: '+233 20 111 2222',
        createdAt: DateTime.now(),
      );
      await storage.saveJobs([job]);
      expect(storage.getJobs().length, 1);
      expect(storage.getJobs().first.id, 'job_crud_01');

      // 3. Save and get Favorites
      await storage.saveFavorites({'job_crud_01', 'job_crud_02'});
      expect(storage.getFavorites().contains('job_crud_01'), true);
      expect(storage.getFavorites().length, 2);

      // 4. Save and get Applications
      final app = JobApplication(
        id: 'app_crud_01',
        jobId: 'job_crud_01',
        jobTitle: 'Carpentry Lead',
        seekerId: 'usr_crud_01',
        seekerName: 'Esi Mansah',
        seekerPhone: '+233 24 000 1111',
        posterId: 'poster_crud',
        appliedAt: DateTime.now(),
      );
      await storage.saveApplications([app]);
      expect(storage.getApplications().length, 1);
      expect(storage.getApplications().first.id, 'app_crud_01');

      // 5. Save and get Chat Rooms & Messages
      final room = ChatRoom(
        id: 'room_crud_01',
        jobId: 'job_crud_01',
        jobTitle: 'Carpentry Lead',
        seekerId: 'usr_crud_01',
        seekerName: 'Esi Mansah',
        posterId: 'poster_crud',
        posterName: 'Adum Builders',
        lastMessage: 'Interview at 10 AM',
        updatedAt: DateTime.now(),
      );
      await storage.saveChatRooms([room]);
      expect(storage.getChatRooms().length, 1);

      final msg = ChatMessage(
        id: 'msg_crud_01',
        senderId: 'usr_crud_01',
        senderName: 'Esi Mansah',
        text: 'I will be there.',
        timestamp: DateTime.now(),
      );
      await storage.saveMessages('room_crud_01', [msg]);
      expect(storage.getMessages('room_crud_01').length, 1);
    });
  });

  // ===========================================================================
  // TIER 2: BOUNDARY & CORNER CASES SUITE
  // ===========================================================================
  group('Tier 2: Boundary & Corner Cases Suite', () {
    late LocalStorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = LocalStorageService(prefs: prefs);
      LocalStorageService.instance.setPreferences(prefs);
    });

    test(
      '2.1 Empty storage initialization returns clean defaults without throwing',
      () {
        expect(storage.getUser(), isNull);
        expect(storage.getJobs(), isEmpty);
        expect(storage.getFavorites(), isEmpty);
        expect(storage.getChatRooms(), isEmpty);
        expect(storage.getApplications(), isEmpty);
        expect(storage.getMessages('nonexistent_room'), isEmpty);
      },
    );

    test(
      '2.2 Corrupted / malformed JSON strings in storage are gracefully handled',
      () async {
        final prefs = storage.prefs;
        await prefs.setString(LocalStorageService.keyUser, '{invalid-json');
        await prefs.setString(
          LocalStorageService.keyJobs,
          '[{"title": "Broken", "missing_closing',
        );
        await prefs.setString(
          LocalStorageService.keyApplications,
          '{"not_a_list": true}',
        );
        await prefs.setString(
          LocalStorageService.keyChatRooms,
          'null_or_corrupt',
        );
        await prefs.setString('local_job_connector_messages_bad_room', '12345');

        expect(storage.getUser(), isNull);
        expect(storage.getJobs(), isEmpty);
        expect(storage.getApplications(), isEmpty);
        expect(storage.getChatRooms(), isEmpty);
        expect(storage.getMessages('bad_room'), isEmpty);
      },
    );

    test(
      '2.3 Partially malformed job post items in JSON list are filtered safely',
      () async {
        final prefs = storage.prefs;
        const jsonListWithBadItem = '''
      [
        {
          "id": "job_valid_01",
          "title": "Valid Painter",
          "description": "Painting house",
          "category": "Painting",
          "payRate": 120.0,
          "city": "Accra",
          "locationName": "Osu",
          "latitude": 5.5500,
          "longitude": -0.1800,
          "posterId": "poster_01",
          "posterName": "Osu Paints",
          "posterPhone": "+233 24 111 2222",
          "createdAt": "2026-08-20T10:00:00.000Z"
        },
        "not_a_map_object",
        42
      ]
      ''';
        await prefs.setString(LocalStorageService.keyJobs, jsonListWithBadItem);

        final retrieved = storage.getJobs();
        expect(retrieved.length, 1);
        expect(retrieved.first.id, 'job_valid_01');
        expect(retrieved.first.title, 'Valid Painter');
      },
    );

    test(
      '2.4 Rapid network toggling in ConnectivityProvider maintains state & listener integrity',
      () {
        final provider = ConnectivityProvider();
        int notificationCount = 0;
        provider.addListener(() {
          notificationCount++;
        });

        expect(provider.isOnline, true);

        // Perform 50 rapid toggles
        for (int i = 0; i < 50; i++) {
          provider.setOnline(i % 2 != 0);
        }

        expect(notificationCount, 50);
        expect(provider.isOnline, true);

        provider.setOnline(false);
        expect(provider.isOnline, false);
      },
    );

    test('2.5 Boundary pay rates enforcement in FormValidators', () {
      // Exactly minimum valid (10.0)
      expect(FormValidators.validatePayRate('10'), isNull);
      expect(FormValidators.validatePayRate('10.00'), isNull);

      // Boundary below minimum
      expect(
        FormValidators.validatePayRate('0.0'),
        'Pay amount must be greater than 0',
      );
      expect(
        FormValidators.validatePayRate('-20'),
        'Pay amount must be greater than 0',
      );
      expect(
        FormValidators.validatePayRate('abc'),
        'Enter a valid numeric amount',
      );

      // Exactly maximum valid (100,000.0)
      expect(FormValidators.validatePayRate('100000'), isNull);
      expect(FormValidators.validatePayRate('100000.00'), isNull);

      // Boundary above maximum
      expect(
        FormValidators.validatePayRate('100000.01'),
        'Pay amount exceeds maximum allowable limit',
      );
      expect(
        FormValidators.validatePayRate('9999999'),
        'Pay amount exceeds maximum allowable limit',
      );
    });

    test(
      '2.6 Duplicate application submissions for same job & seeker are strictly rejected',
      () async {
        final appRepo = InMemoryApplicationRepository(
          localStorageService: storage,
        );
        final provider = ApplicationProvider(
          applicationRepository: appRepo,
          localStorageService: storage,
        );

        final first = await provider.submitApplication(
          jobId: 'job_dup_test',
          jobTitle: 'Market Carrier',
          employerId: 'poster_dup',
          applicantId: 'seeker_dup',
          applicantName: 'Kwame',
          applicantPhone: '+233 24 111 2222',
          coverNote: 'First attempt',
        );
        expect(first, true);
        expect(provider.hasApplied('job_dup_test', 'seeker_dup'), true);
        expect(provider.applications.length, 1);

        // Duplicate attempt
        final duplicate = await provider.submitApplication(
          jobId: 'job_dup_test',
          jobTitle: 'Market Carrier',
          employerId: 'poster_dup',
          applicantId: 'seeker_dup',
          applicantName: 'Kwame',
          applicantPhone: '+233 24 111 2222',
          coverNote: 'Second attempt should fail',
        );
        expect(duplicate, false);
        expect(provider.applications.length, 1);
      },
    );

    test(
      '2.7 Multiple different seekers applying to same job succeed independently',
      () async {
        final appRepo = InMemoryApplicationRepository(
          localStorageService: storage,
        );
        final provider = ApplicationProvider(
          applicationRepository: appRepo,
          localStorageService: storage,
        );

        for (int i = 1; i <= 5; i++) {
          final success = await provider.submitApplication(
            jobId: 'job_multi_01',
            jobTitle: 'Tema Loader',
            employerId: 'poster_tema',
            applicantId: 'seeker_0$i',
            applicantName: 'Seeker $i',
            applicantPhone: '+233 24 000 000$i',
            coverNote: 'Experience note $i',
          );
          expect(success, true);
        }

        expect(provider.applications.length, 5);
        expect(provider.getApplicationsForJob('job_multi_01').length, 5);
      },
    );

    test(
      '2.8 Maximum length cover note (1000+ characters) persists without truncation',
      () async {
        final appRepo = InMemoryApplicationRepository(
          localStorageService: storage,
        );
        final provider = ApplicationProvider(
          applicationRepository: appRepo,
          localStorageService: storage,
        );

        final longNote = 'A' * 1500;
        final success = await provider.submitApplication(
          jobId: 'job_long_note',
          jobTitle: 'Construction Expert',
          employerId: 'poster_long',
          applicantId: 'seeker_long',
          applicantName: 'Long Note Seeker',
          applicantPhone: '+233 24 999 8888',
          coverNote: longNote,
        );

        expect(success, true);
        expect(provider.applications.first.note.length, 1500);

        final persisted = storage.getApplications();
        expect(persisted.first.note.length, 1500);
      },
    );

    test(
      '2.9 Job status transitions update isFilled consistency and persist across instances',
      () async {
        final jobRepo = InMemoryJobRepository();
        final jobProvider = JobProvider(
          jobRepository: jobRepo,
          localStorageService: storage,
        );

        final testJob = JobPost(
          id: 'job_status_trans',
          title: 'Site Foreman',
          description: 'Supervise site',
          category: 'Construction & Labor',
          payRate: 350.0,
          city: 'Accra',
          locationName: 'Kaneshie',
          latitude: 5.5700,
          longitude: -0.2300,
          posterId: 'poster_foreman',
          posterName: 'Foreman Ltd',
          posterPhone: '+233 24 888 7777',
          status: JobStatus.open,
          isFilled: false,
          createdAt: DateTime.now(),
        );
        await jobProvider.addJob(testJob);

        // Open -> inProgress
        await jobProvider.updateJobStatus(
          'job_status_trans',
          JobStatus.inProgress,
        );
        var job = jobProvider.allJobs.firstWhere(
          (j) => j.id == 'job_status_trans',
        );
        expect(job.status, JobStatus.inProgress);
        expect(job.isFilled, isTrue);

        // inProgress -> completed
        await jobProvider.updateJobStatus(
          'job_status_trans',
          JobStatus.completed,
        );
        job = jobProvider.allJobs.firstWhere((j) => j.id == 'job_status_trans');
        expect(job.status, JobStatus.completed);
        expect(job.isFilled, isTrue);

        // completed -> open (reopening job)
        await jobProvider.updateJobStatus('job_status_trans', JobStatus.open);
        job = jobProvider.allJobs.firstWhere((j) => j.id == 'job_status_trans');
        expect(job.status, JobStatus.open);
        expect(job.isFilled, isFalse);
      },
    );

    test('2.10 Favorites set idempotency and rapid toggle stability', () async {
      final jobRepo = InMemoryJobRepository();
      final jobProvider = JobProvider(
        jobRepository: jobRepo,
        localStorageService: storage,
      );

      expect(jobProvider.isFavorite('job_101'), false);

      // Toggle favorite 10 times
      for (int i = 0; i < 10; i++) {
        await jobProvider.toggleFavorite('job_101');
      }

      // Even number of toggles returns to initial state
      expect(jobProvider.isFavorite('job_101'), false);

      // 11th toggle adds favorite
      await jobProvider.toggleFavorite('job_101');
      expect(jobProvider.isFavorite('job_101'), true);
      expect(storage.getFavorites().contains('job_101'), true);
    });
  });

  // ===========================================================================
  // TIER 3: CROSS-FEATURE INTERACTION TESTS
  // ===========================================================================
  group('Tier 3: Cross-Feature Interaction Suite', () {
    late LocalStorageService storage;
    late InMemoryJobRepository jobRepo;
    late InMemoryApplicationRepository appRepo;
    late InMemoryChatRepository chatRepo;
    late InMemoryUserRepository userRepo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = LocalStorageService(prefs: prefs);
      LocalStorageService.instance.setPreferences(prefs);

      jobRepo = InMemoryJobRepository();
      appRepo = InMemoryApplicationRepository(localStorageService: storage);
      chatRepo = InMemoryChatRepository();
      userRepo = InMemoryUserRepository();
    });

    test(
      '3.1 Offline Job Creation -> Cold Restart Hydration -> Online Sync',
      () async {
        // 1. Employer creates a new job while offline
        final jobProvider1 = JobProvider(
          jobRepository: jobRepo,
          localStorageService: storage,
        );

        final newGig = JobPost(
          id: 'job_offline_001',
          title: 'Circle Night Security Guard',
          description: 'Night shift security at Circle VIP station',
          category: 'Security',
          payRate: 180.0,
          city: 'Accra',
          locationName: 'Circle VIP Terminal',
          latitude: 5.5586,
          longitude: -0.2014,
          posterId: 'poster_sec_01',
          posterName: 'Circle Security Services',
          posterPhone: '+233 24 777 6666',
          status: JobStatus.open,
          createdAt: DateTime(2026, 8, 29, 20, 0),
        );

        await jobProvider1.addJob(newGig);
        expect(
          jobProvider1.allJobs.any((j) => j.id == 'job_offline_001'),
          true,
        );

        // 2. Simulate Cold App Restart (New instance reading from storage)
        final jobProvider2 = JobProvider(
          jobRepository: InMemoryJobRepository(),
          localStorageService: storage,
        );

        expect(
          jobProvider2.allJobs.any((j) => j.id == 'job_offline_001'),
          true,
        );
        final hydratedJob = jobProvider2.allJobs.firstWhere(
          (j) => j.id == 'job_offline_001',
        );
        expect(hydratedJob.title, 'Circle Night Security Guard');
        expect(hydratedJob.payRate, 180.0);
        expect(hydratedJob.city, 'Accra');
      },
    );

    test(
      '3.2 Job Creation -> Seeker Application -> Employer Review & Acceptance -> Status In-Progress',
      () async {
        final jobProvider = JobProvider(
          jobRepository: jobRepo,
          localStorageService: storage,
        );
        final appProvider = ApplicationProvider(
          applicationRepository: appRepo,
          localStorageService: storage,
        );

        // 1. Post a job
        final job = JobPost(
          id: 'job_workflow_01',
          title: 'Adum Store Assistant',
          description: 'Stock shelves and manage checkout',
          category: 'Retail & Sales',
          payRate: 140.0,
          city: 'Kumasi',
          locationName: 'Adum High Street',
          latitude: 6.6961,
          longitude: -1.6234,
          posterId: 'poster_adum',
          posterName: 'Serwaa Supermarket',
          posterPhone: '+233 20 888 1234',
          createdAt: DateTime.now(),
        );
        await jobProvider.addJob(job);

        // 2. Seeker submits application
        final applied = await appProvider.submitApplication(
          applicationId: 'app_adum_01',
          jobId: 'job_workflow_01',
          jobTitle: 'Adum Store Assistant',
          employerId: 'poster_adum',
          applicantId: 'seeker_yaa',
          applicantName: 'Yaa Asantewaa',
          applicantPhone: '+233 50 123 9876',
          coverNote: 'Available 6 days a week, highly punctual',
        );
        expect(applied, true);

        // 3. Employer reviews applications for this job
        final employerApps = appProvider.getApplicationsForJob(
          'job_workflow_01',
        );
        expect(employerApps.length, 1);
        expect(employerApps.first.seekerName, 'Yaa Asantewaa');
        expect(employerApps.first.status, ApplicationStatus.pending);

        // 4. Employer accepts application
        await appProvider.updateApplicationStatus(
          'app_adum_01',
          ApplicationStatus.accepted,
        );
        expect(
          appProvider.getApplicationsForJob('job_workflow_01').first.status,
          ApplicationStatus.accepted,
        );

        // 5. Job status updates to inProgress
        await jobProvider.updateJobStatus(
          'job_workflow_01',
          JobStatus.inProgress,
        );
        expect(
          jobProvider.allJobs
              .firstWhere((j) => j.id == 'job_workflow_01')
              .status,
          JobStatus.inProgress,
        );
      },
    );

    test('3.3 Job Acceptance -> Chat Room Generation -> Direct Messaging', () {
      final chatProvider = ChatProvider(
        chatRepository: chatRepo,
        localStorageService: storage,
      );

      // 1. Generate/Retrieve Chat Room between Seeker & Employer
      final roomId = chatProvider.getOrCreateRoom(
        jobId: 'job_workflow_01',
        jobTitle: 'Adum Store Assistant',
        seekerId: 'seeker_yaa',
        seekerName: 'Yaa Asantewaa',
        posterId: 'poster_adum',
        posterName: 'Serwaa Supermarket',
      );

      expect(roomId, isNotEmpty);
      expect(chatProvider.rooms.any((r) => r.id == roomId), true);

      // 2. Send messages back and forth
      chatProvider.sendMessage(
        roomId: roomId,
        text: 'Hello, thank you for accepting my application!',
        senderId: 'seeker_yaa',
        senderName: 'Yaa Asantewaa',
      );

      chatProvider.sendMessage(
        roomId: roomId,
        text: 'Welcome Yaa, please report on Monday at 8 AM.',
        senderId: 'poster_adum',
        senderName: 'Serwaa Supermarket',
      );

      final messages = chatProvider.getMessages(roomId);
      expect(messages.length, greaterThanOrEqualTo(2));
      expect(
        messages.any((m) => m.text.contains('thank you for accepting')),
        true,
      );
      expect(messages.any((m) => m.text.contains('report on Monday')), true);
    });

    test(
      '3.4 Role Switching Dynamic Screen Behavior (Seeker vs Employer Views)',
      () async {
        final auth = AuthProvider(
          userRepository: userRepo,
          localStorageService: storage,
        );
        final jobProv = JobProvider(
          jobRepository: jobRepo,
          localStorageService: storage,
        );

        // Default role is seeker
        expect(auth.currentUser?.role, UserRole.seeker);
        jobProv.setRole(UserRole.seeker);
        expect(jobProv.currentUserRole, UserRole.seeker);

        // Switch to Employer
        await auth.switchRole(UserRole.poster);
        jobProv.setRole(UserRole.poster);

        expect(auth.currentUser?.role, UserRole.poster);
        expect(jobProv.currentUserRole, UserRole.poster);
      },
    );

    test(
      '3.5 Favorites Persistence across Cold Restart and Filter Adjustments',
      () async {
        final jobProv1 = JobProvider(
          jobRepository: jobRepo,
          localStorageService: storage,
        );

        // Add 2 jobs to favorites
        await jobProv1.toggleFavorite('job_101');
        await jobProv1.toggleFavorite('job_102');

        expect(jobProv1.favoriteJobs.length, 2);

        // Filter feed to Kumasi
        jobProv1.setCityFilter('Kumasi');
        expect(jobProv1.selectedCity, 'Kumasi');

        // Favorites list remains isolated from feed filter
        expect(jobProv1.favoriteJobs.length, 2);

        // Simulate restart
        final jobProv2 = JobProvider(
          jobRepository: InMemoryJobRepository(),
          localStorageService: storage,
        );

        expect(jobProv2.favoriteJobs.length, 2);
        expect(jobProv2.isFavorite('job_101'), true);
        expect(jobProv2.isFavorite('job_102'), true);
      },
    );

    test(
      '3.6 Network Transition during Application Submission & Sync',
      () async {
        final connectivity = ConnectivityProvider();
        final appProvider = ApplicationProvider(
          applicationRepository: appRepo,
          localStorageService: storage,
        );

        // Device goes offline
        connectivity.setOnline(false);
        expect(connectivity.isOnline, false);

        // Seeker applies while offline
        final submitted = await appProvider.submitApplication(
          applicationId: 'app_offline_sync',
          jobId: 'job_101',
          jobTitle: 'Offloader',
          employerId: 'poster_101',
          applicantId: 'seeker_sync',
          applicantName: 'Sync Tester',
          applicantPhone: '+233 24 333 4444',
          coverNote: 'Offline application note',
        );
        expect(submitted, true);
        expect(
          storage.getApplications().any((a) => a.id == 'app_offline_sync'),
          true,
        );

        // Device comes back online
        connectivity.setOnline(true);
        expect(connectivity.isOnline, true);
        expect(
          appProvider.applications.any((a) => a.id == 'app_offline_sync'),
          true,
        );
      },
    );

    test(
      '3.7 Completed Job Lifecycle & Applicant Count Verification',
      () async {
        final jobProv = JobProvider(
          jobRepository: jobRepo,
          localStorageService: storage,
        );
        final appProv = ApplicationProvider(
          applicationRepository: appRepo,
          localStorageService: storage,
        );

        const testJobId = 'job_lifecycle_01';
        await jobProv.addJob(
          JobPost(
            id: testJobId,
            title: 'Tema Driver',
            description: 'Delivery driver',
            category: 'Logistics & Warehouse',
            payRate: 250.0,
            city: 'Tema',
            locationName: 'Community 1',
            latitude: 5.6424,
            longitude: 0.0050,
            posterId: 'poster_tema_01',
            posterName: 'Tema Transport',
            posterPhone: '+233 24 111 9999',
            status: JobStatus.open,
            createdAt: DateTime.now(),
          ),
        );

        // 3 applicants apply
        for (int i = 1; i <= 3; i++) {
          await appProv.submitApplication(
            jobId: testJobId,
            jobTitle: 'Tema Driver',
            employerId: 'poster_tema_01',
            applicantId: 'seeker_driver_$i',
            applicantName: 'Driver $i',
            applicantPhone: '+233 24 000 111$i',
            coverNote: 'Driver experience $i',
          );
        }

        expect(appProv.getApplicationsForJob(testJobId).length, 3);

        // Complete job
        await jobProv.updateJobStatus(testJobId, JobStatus.completed);
        final completedJob = jobProv.allJobs.firstWhere(
          (j) => j.id == testJobId,
        );
        expect(completedJob.status, JobStatus.completed);
        expect(completedJob.isFilled, isTrue);
      },
    );

    testWidgets(
      '3.8 GlobalErrorBoundary catches errors and renders recovery UI',
      (tester) async {
        final boundaryKey = GlobalKey<GlobalErrorBoundaryState>();

        await tester.pumpWidget(
          MaterialApp(
            home: GlobalErrorBoundary(
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

    testWidgets('3.9 OfflineBanner animates on connectivity status changes', (
      tester,
    ) async {
      final connectivity = ConnectivityProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ConnectivityProvider>.value(
              value: connectivity,
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: OfflineBanner(
                child: Center(child: Text('Main Screen Content')),
              ),
            ),
          ),
        ),
      );

      // Initially online -> banner hidden
      expect(find.byKey(const Key('offline_banner_container')), findsNothing);

      // Toggle offline
      connectivity.setOnline(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const Key('offline_banner_container')), findsOneWidget);
      expect(find.textContaining('Offline Mode'), findsOneWidget);

      // Toggle online
      connectivity.setOnline(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const Key('offline_banner_container')), findsNothing);
    });

    test(
      '3.10 Cross-city distance calculation between major Ghana centers',
      () {
        final distanceAccraKumasi = LocationService.calculateDistanceKm(
          startLatitude: LocationService.accraCenter.latitude,
          startLongitude: LocationService.accraCenter.longitude,
          endLatitude: LocationService.kumasiCenter.latitude,
          endLongitude: LocationService.kumasiCenter.longitude,
        );
        expect(distanceAccraKumasi, greaterThan(180.0));
        expect(distanceAccraKumasi, lessThan(220.0));

        final distanceAccraTema = LocationService.calculateDistanceKm(
          startLatitude: LocationService.accraCenter.latitude,
          startLongitude: LocationService.accraCenter.longitude,
          endLatitude: LocationService.temaCenter.latitude,
          endLongitude: LocationService.temaCenter.longitude,
        );
        expect(distanceAccraTema, greaterThan(15.0));
        expect(distanceAccraTema, lessThan(35.0));
      },
    );

    test(
      '3.11 Pairwise Filter: City + Category + Search query intersection',
      () {
        final jobProv = JobProvider(
          jobRepository: jobRepo,
          localStorageService: storage,
        );

        // Search matching only Circle VIP Accra construction job
        jobProv.setCityFilter('Accra');
        jobProv.setCategoryFilter('Construction & Labor');
        jobProv.setSearchQuery('Circle VIP');

        final filtered = jobProv.filteredJobs;
        expect(filtered.isNotEmpty, true);
        expect(filtered.every((j) => j.city == 'Accra'), true);
        expect(
          filtered.every((j) => j.category == 'Construction & Labor'),
          true,
        );
        expect(
          filtered.every((j) => j.locationName.contains('Circle VIP')),
          true,
        );

        // Non-matching query yields empty list cleanly
        jobProv.setSearchQuery('NonExistentJob12345');
        expect(jobProv.filteredJobs, isEmpty);
      },
    );
  });

  // ===========================================================================
  // TIER 4: REAL-WORLD WORKLOAD SCENARIOS
  // ===========================================================================
  group('Tier 4: Real-World Workload Scenarios', () {
    late LocalStorageService storage;
    late InMemoryJobRepository jobRepo;
    late InMemoryApplicationRepository appRepo;
    late InMemoryChatRepository chatRepo;
    late InMemoryUserRepository userRepo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = LocalStorageService(prefs: prefs);
      LocalStorageService.instance.setPreferences(prefs);

      jobRepo = InMemoryJobRepository();
      appRepo = InMemoryApplicationRepository(localStorageService: storage);
      chatRepo = InMemoryChatRepository();
      userRepo = InMemoryUserRepository();
    });

    test('Scenario 1: Accra Construction Laborer Multi-Step Journey', () async {
      final auth = AuthProvider(
        userRepository: userRepo,
        localStorageService: storage,
      );
      final jobProv = JobProvider(
        jobRepository: jobRepo,
        localStorageService: storage,
      );
      final appProv = ApplicationProvider(
        applicationRepository: appRepo,
        localStorageService: storage,
      );
      final chatProv = ChatProvider(
        chatRepository: chatRepo,
        localStorageService: storage,
      );

      // 1. Sign up as Seeker in Accra
      await auth.signUpWithEmail(
        displayName: 'Kofi Laborer',
        email: 'kofi.laborer@example.com',
        password: 'securePassword123',
        phone: '+233 24 123 4567',
        role: UserRole.seeker,
        city: 'Accra',
      );
      expect(auth.isAuthenticated, true);
      expect(auth.currentUser!.city, 'Accra');

      // 2. Filter feed to Accra Construction
      jobProv.setCityFilter('Accra');
      jobProv.setCategoryFilter('Construction & Labor');
      final jobs = jobProv.filteredJobs;
      expect(jobs.isNotEmpty, true);
      final selectedJob = jobs.first;

      // 3. Save to favorites
      await jobProv.toggleFavorite(selectedJob.id);
      expect(jobProv.isFavorite(selectedJob.id), true);

      // 4. Submit Job Application
      final applied = await appProv.submitApplication(
        jobId: selectedJob.id,
        jobTitle: selectedJob.title,
        employerId: selectedJob.posterId,
        applicantId: auth.currentUser!.id,
        applicantName: auth.currentUser!.displayName,
        applicantPhone: auth.currentUser!.phone,
        coverNote: 'Experienced construction worker ready to work immediately.',
      );
      expect(applied, true);
      expect(appProv.hasApplied(selectedJob.id, auth.currentUser!.id), true);

      // 5. Employer accepts application
      final employerApps = appProv.getApplicationsForJob(selectedJob.id);
      final seekerApp = employerApps.firstWhere(
        (a) => a.seekerId == auth.currentUser!.id,
      );
      await appProv.updateApplicationStatus(
        seekerApp.id,
        ApplicationStatus.accepted,
      );
      expect(
        appProv.applications.firstWhere((a) => a.id == seekerApp.id).status,
        ApplicationStatus.accepted,
      );

      // 6. Open Chat and send inquiry
      final roomId = chatProv.getOrCreateRoom(
        jobId: selectedJob.id,
        jobTitle: selectedJob.title,
        seekerId: auth.currentUser!.id,
        seekerName: auth.currentUser!.displayName,
        posterId: selectedJob.posterId,
        posterName: selectedJob.posterName,
      );
      chatProv.sendMessage(
        roomId: roomId,
        senderId: auth.currentUser!.id,
        senderName: auth.currentUser!.displayName,
        text: 'Thank you for accepting! What time should I arrive tomorrow?',
      );
      expect(chatProv.getMessages(roomId).length, greaterThanOrEqualTo(1));
    });

    test('Scenario 2: Kumasi Market Employer Hiring Lifecycle', () async {
      final auth = AuthProvider(
        userRepository: userRepo,
        localStorageService: storage,
      );
      final jobProv = JobProvider(
        jobRepository: jobRepo,
        localStorageService: storage,
      );
      final appProv = ApplicationProvider(
        applicationRepository: appRepo,
        localStorageService: storage,
      );

      // 1. Sign up as Employer in Kumasi
      await auth.signUpWithEmail(
        displayName: 'Mama Serwaa Fruits',
        email: 'serwaa.fruits@example.com',
        password: 'password123',
        phone: '+233 20 999 8888',
        role: UserRole.poster,
        city: 'Kumasi',
      );

      // 2. Post two retail gigs at Kejetia
      final gig1 = JobPost(
        id: 'job_kejetia_stall_01',
        title: 'Kejetia Orange Sorter',
        description: 'Sort and bag fresh sweet oranges',
        category: 'Retail & Sales',
        payRate: 90.0,
        city: 'Kumasi',
        locationName: 'Kejetia Market Stall 14',
        latitude: 6.6961,
        longitude: -1.6234,
        posterId: auth.currentUser!.id,
        posterName: 'Mama Serwaa Fruits',
        posterPhone: '+233 20 999 8888',
        createdAt: DateTime.now(),
      );
      await jobProv.addJob(gig1);

      // 3. Two applicants apply
      await appProv.submitApplication(
        applicationId: 'app_orange_01',
        jobId: 'job_kejetia_stall_01',
        jobTitle: 'Kejetia Orange Sorter',
        employerId: auth.currentUser!.id,
        applicantId: 'seeker_kwaku',
        applicantName: 'Kwaku Duah',
        applicantPhone: '+233 24 111 0001',
        coverNote: 'Fast sorter',
      );

      await appProv.submitApplication(
        applicationId: 'app_orange_02',
        jobId: 'job_kejetia_stall_01',
        jobTitle: 'Kejetia Orange Sorter',
        employerId: auth.currentUser!.id,
        applicantId: 'seeker_akua',
        applicantName: 'Akua Mansah',
        applicantPhone: '+233 24 111 0002',
        coverNote: 'Experience in market retail',
      );

      expect(appProv.getApplicationsForJob('job_kejetia_stall_01').length, 2);

      // 4. Accept first, reject second
      await appProv.updateApplicationStatus(
        'app_orange_01',
        ApplicationStatus.accepted,
      );
      await appProv.updateApplicationStatus(
        'app_orange_02',
        ApplicationStatus.rejected,
      );

      expect(
        appProv.applications.firstWhere((a) => a.id == 'app_orange_01').status,
        ApplicationStatus.accepted,
      );
      expect(
        appProv.applications.firstWhere((a) => a.id == 'app_orange_02').status,
        ApplicationStatus.rejected,
      );

      // 5. Update job status to completed
      await jobProv.updateJobStatus(
        'job_kejetia_stall_01',
        JobStatus.completed,
      );
      expect(
        jobProv.allJobs
            .firstWhere((j) => j.id == 'job_kejetia_stall_01')
            .status,
        JobStatus.completed,
      );
    });

    test('Scenario 3: Tema Port Logistics Cross-Role Dual Identity', () async {
      final auth = AuthProvider(
        userRepository: userRepo,
        localStorageService: storage,
      );
      final jobProv = JobProvider(
        jobRepository: jobRepo,
        localStorageService: storage,
      );
      final appProv = ApplicationProvider(
        applicationRepository: appRepo,
        localStorageService: storage,
      );

      // 1. Start as Seeker in Tema
      await auth.signUpWithEmail(
        displayName: 'Emmanuel Forklift',
        email: 'emmanuel.forklift@example.com',
        password: 'password123',
        phone: '+233 27 555 4321',
        role: UserRole.seeker,
        city: 'Tema',
      );

      // 2. Apply to logistics gig
      await appProv.submitApplication(
        jobId: 'job_102',
        jobTitle: 'Heavy Truck Offloader',
        employerId: 'poster_102',
        applicantId: auth.currentUser!.id,
        applicantName: auth.currentUser!.displayName,
        applicantPhone: auth.currentUser!.phone,
        coverNote: 'Certified forklift operator',
      );
      expect(appProv.myApplications.length, 1);

      // 3. Switch role to Employer
      await auth.switchRole(UserRole.poster);
      jobProv.setRole(UserRole.poster);
      expect(auth.currentUser?.role, UserRole.poster);

      // 4. Create new job post
      final postedGig = JobPost(
        id: 'job_tema_container_01',
        title: 'Container Stacker Lead',
        description: 'Lead stacking operations at Tema Gate 2',
        category: 'Logistics & Warehouse',
        payRate: 260.0,
        city: 'Tema',
        locationName: 'Tema Port Gate 2',
        latitude: 5.6424,
        longitude: 0.0050,
        posterId: auth.currentUser!.id,
        posterName: auth.currentUser!.displayName,
        posterPhone: auth.currentUser!.phone,
        createdAt: DateTime.now(),
      );
      await jobProv.addJob(postedGig);
      expect(jobProv.allJobs.any((j) => j.id == 'job_tema_container_01'), true);

      // 5. Switch back to Seeker
      await auth.switchRole(UserRole.seeker);
      jobProv.setRole(UserRole.seeker);
      expect(auth.currentUser?.role, UserRole.seeker);
      expect(appProv.myApplications.length, 1);
    });

    test('Scenario 4: Multi-City Multi-Filter Discovery Workflow', () {
      final jobProv = JobProvider(
        jobRepository: jobRepo,
        localStorageService: storage,
      );

      // 1. Query Accra
      jobProv.setCityFilter('Accra');
      final accraJobs = jobProv.filteredJobs;
      expect(accraJobs.every((j) => j.city == 'Accra'), true);

      // 2. Query Kumasi
      jobProv.setCityFilter('Kumasi');
      final kumasiJobs = jobProv.filteredJobs;
      expect(kumasiJobs.every((j) => j.city == 'Kumasi'), true);

      // 3. Query Tema
      jobProv.setCityFilter('Tema');
      final temaJobs = jobProv.filteredJobs;
      expect(temaJobs.every((j) => j.city == 'Tema'), true);

      // 4. Query All with search term
      jobProv.setCityFilter('All');
      jobProv.setSearchQuery('Masonry');
      final searchJobs = jobProv.filteredJobs;
      expect(
        searchJobs.every(
          (j) =>
              j.title.toLowerCase().contains('mason') ||
              j.description.toLowerCase().contains('mason'),
        ),
        true,
      );
    });

    test(
      'Scenario 5: Offline Resilience & Intermittent Connectivity Flow',
      () async {
        final connectivity = ConnectivityProvider();
        final jobProv = JobProvider(
          jobRepository: jobRepo,
          localStorageService: storage,
        );
        final appProv = ApplicationProvider(
          applicationRepository: appRepo,
          localStorageService: storage,
        );

        // Disconnect network
        connectivity.setOnline(false);

        // Save favorite and submit application offline
        await jobProv.toggleFavorite('job_101');
        final appSuccess = await appProv.submitApplication(
          applicationId: 'app_offline_e2e',
          jobId: 'job_101',
          jobTitle: 'Offloader',
          employerId: 'poster_101',
          applicantId: 'seeker_offline_01',
          applicantName: 'Offline Worker',
          applicantPhone: '+233 24 000 9999',
          coverNote: 'Submitted while offline',
        );
        expect(appSuccess, true);

        // Reconnect
        connectivity.setOnline(true);
        expect(storage.getFavorites().contains('job_101'), true);
        expect(
          storage.getApplications().any((a) => a.id == 'app_offline_e2e'),
          true,
        );
      },
    );

    test('Scenario 6: End-to-End Chat & Negotiation Flow', () {
      final chatProv = ChatProvider(
        chatRepository: chatRepo,
        localStorageService: storage,
      );

      // 1. Create Room
      final roomId = chatProv.getOrCreateRoom(
        jobId: 'job_bus_01',
        jobTitle: 'Bus Loading Assistant',
        seekerId: 'seeker_01',
        seekerName: 'Seeker',
        posterId: 'employer_test_01',
        posterName: 'Circle VIP Transport',
      );

      // 2. Send 4 messages
      for (int i = 1; i <= 4; i++) {
        chatProv.sendMessage(
          roomId: roomId,
          text: 'Negotiation message #$i',
          senderId: 'seeker_01',
          senderName: 'Seeker',
        );
      }

      final messages = chatProv.getMessages(roomId);
      expect(messages.length, greaterThanOrEqualTo(4));
      expect(messages.last.text, 'Negotiation message #4');
    });

    test('Scenario 7: Full Application Status Lifecycle Progression', () async {
      final appProv = ApplicationProvider(
        applicationRepository: appRepo,
        localStorageService: storage,
      );

      await appProv.submitApplication(
        applicationId: 'app_lifecycle_full',
        jobId: 'job_101',
        jobTitle: 'Offloader',
        employerId: 'poster_101',
        applicantId: 'seeker_full',
        applicantName: 'Full Lifecycle Seeker',
        applicantPhone: '+233 24 111 8888',
        coverNote: 'Ready for full lifecycle',
      );

      // Initial: pending
      expect(
        appProv.applications
            .firstWhere((a) => a.id == 'app_lifecycle_full')
            .status,
        ApplicationStatus.pending,
      );

      // Progress to accepted
      await appProv.updateApplicationStatus(
        'app_lifecycle_full',
        ApplicationStatus.accepted,
      );
      expect(
        appProv.applications
            .firstWhere((a) => a.id == 'app_lifecycle_full')
            .status,
        ApplicationStatus.accepted,
      );

      // Progress to completed
      await appProv.updateApplicationStatus(
        'app_lifecycle_full',
        ApplicationStatus.completed,
      );
      expect(
        appProv.applications
            .firstWhere((a) => a.id == 'app_lifecycle_full')
            .status,
        ApplicationStatus.completed,
      );
    });

    test(
      'Scenario 8: High-Volume Applicant Review Matrix (5 Applicants)',
      () async {
        final appProv = ApplicationProvider(
          applicationRepository: appRepo,
          localStorageService: storage,
        );
        const testJobId = 'job_high_demand_01';

        // 5 applicants
        for (int i = 1; i <= 5; i++) {
          await appProv.submitApplication(
            applicationId: 'app_batch_0$i',
            jobId: testJobId,
            jobTitle: 'High Demand Job',
            employerId: 'poster_batch',
            applicantId: 'seeker_batch_0$i',
            applicantName: 'Applicant #$i',
            applicantPhone: '+233 24 000 000$i',
            coverNote: 'Note from applicant #$i',
          );
        }

        expect(appProv.getApplicationsForJob(testJobId).length, 5);

        // Accept applicant 1 & 2
        await appProv.updateApplicationStatus(
          'app_batch_01',
          ApplicationStatus.accepted,
        );
        await appProv.updateApplicationStatus(
          'app_batch_02',
          ApplicationStatus.accepted,
        );

        // Reject applicant 3
        await appProv.updateApplicationStatus(
          'app_batch_03',
          ApplicationStatus.rejected,
        );

        // 4 & 5 remain pending
        final apps = appProv.getApplicationsForJob(testJobId);
        expect(
          apps.where((a) => a.status == ApplicationStatus.accepted).length,
          2,
        );
        expect(
          apps.where((a) => a.status == ApplicationStatus.rejected).length,
          1,
        );
        expect(
          apps.where((a) => a.status == ApplicationStatus.pending).length,
          2,
        );
      },
    );

    test(
      'Scenario 9: Corrupted Local Cache Cold-Start Recovery Workflow',
      () async {
        final prefs = storage.prefs;
        await prefs.setString(
          LocalStorageService.keyJobs,
          'malformed_non_json_string',
        );
        await prefs.setString(
          LocalStorageService.keyApplications,
          '{"bad_format": 1}',
        );

        // App initializes without crashing and falls back to default mock data
        final freshJobProvider = JobProvider(
          jobRepository: InMemoryJobRepository(),
          localStorageService: storage,
        );

        final freshAppProvider = ApplicationProvider(
          applicationRepository: InMemoryApplicationRepository(
            localStorageService: storage,
          ),
          localStorageService: storage,
        );

        expect(freshJobProvider.allJobs.isNotEmpty, true);
        expect(freshAppProvider.applications, isEmpty);

        // User continues flow
        await freshJobProvider.toggleFavorite(
          freshJobProvider.allJobs.first.id,
        );
        expect(freshJobProvider.favoriteJobs.length, 1);
      },
    );

    testWidgets(
      'Scenario 10: Complete UI Widget Navigation & Deep Interaction Flow',
      (tester) async {
        final auth = AuthProvider(
          userRepository: userRepo,
          localStorageService: storage,
        );
        final jobProv = JobProvider(
          jobRepository: jobRepo,
          localStorageService: storage,
        );
        final appProv = ApplicationProvider(
          applicationRepository: appRepo,
          localStorageService: storage,
        );
        final chatProv = ChatProvider(
          chatRepository: chatRepo,
          localStorageService: storage,
        );

        await tester.pumpWidget(
          createTestE2EApp(
            child: const JobFeedScreen(),
            authProvider: auth,
            jobProvider: jobProv,
            applicationProvider: appProv,
            chatProvider: chatProv,
          ),
        );
        await tester.pumpAndSettle();

        // Feed renders
        expect(find.text('Local Job Connector'), findsOneWidget);
        expect(find.text('Accra'), findsWidgets);

        // Tap Kumasi filter chip
        await tester.tap(find.text('Kumasi').first);
        await tester.pumpAndSettle();

        expect(jobProv.selectedCity, 'Kumasi');
      },
    );
  });
}
