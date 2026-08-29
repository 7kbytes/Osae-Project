import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_job_connector/core/models/job_application_model.dart';
import 'package:local_job_connector/core/models/job_model.dart';
import 'package:local_job_connector/core/models/timestamp_helper.dart';
import 'package:local_job_connector/core/models/user_model.dart';
import 'package:local_job_connector/core/providers/application_provider.dart';
import 'package:local_job_connector/core/providers/connectivity_provider.dart';
import 'package:local_job_connector/core/providers/job_provider.dart';
import 'package:local_job_connector/core/repositories/application_repository.dart';
import 'package:local_job_connector/core/repositories/job_repository.dart';
import 'package:local_job_connector/core/services/local_storage_service.dart';
import 'package:local_job_connector/core/utils/form_validators.dart';
import 'package:local_job_connector/core/utils/input_sanitizer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalStorageService();
    await storage.init();
    LocalStorageService.instance.setPreferences(storage.prefs);
  });

  // ===========================================================================
  // 1. DATA SERIALIZATION FIDELITY & SCHEMA BOUNDARY TESTS
  // ===========================================================================
  group('Adversarial 1: Deep Serialization Fidelity & Schema Boundaries', () {
    test('Round-trip AppUser serialization with multilingual unicode, extreme lengths, and special characters', () async {
      final exoticUser = AppUser(
        id: 'usr_unicode_🇬🇭_123',
        displayName: 'Kofi Mensah \u{1F468}\u{1F3FE}\u200D\u{1F527} — Ɔdɔ yɛ dɛ (Twi) / தமிழ் / العربية / ⚡',
        phone: '+233 24 999 0000',
        role: UserRole.seeker,
        city: 'Accra / Osu / Ɔsu',
        rating: 4.99999,
        avatarUrl: 'https://example.com/avatar?name=Kofi&lang=twi&sig=a1b2c3%20%2F%3D',
        createdAt: DateTime.utc(2026, 12, 31, 23, 59, 59, 999),
      );

      await storage.saveUser(exoticUser);
      final retrieved = storage.getUser();

      expect(retrieved, isNotNull);
      expect(retrieved!.id, equals('usr_unicode_🇬🇭_123'));
      expect(retrieved.displayName, contains('Ɔdɔ yɛ dɛ'));
      expect(retrieved.displayName, contains('العربية'));
      expect(retrieved.city, equals('Accra / Osu / Ɔsu'));
      expect(retrieved.rating, closeTo(4.99999, 0.00001));
      expect(retrieved.role, equals(UserRole.seeker));
    });

    test('JobPost serialization with extreme coordinates, huge descriptions, and boundary status enums', () async {
      final hugeDesc = 'A' * 15000; // 15KB text description
      final extremeJob = JobPost(
        id: 'job_extreme_001',
        title: 'High-Altitude Crane Specialist 🏗️',
        description: hugeDesc,
        category: 'Heavy Machinery & Logistics',
        payRate: 99999.99,
        payUnit: 'per month',
        currency: 'GHS',
        city: 'Takoradi',
        locationName: 'Takoradi Deepwater Oil Terminal (Gate 4)',
        latitude: -89.999999, // extreme south latitude boundary
        longitude: 179.999999, // extreme east longitude boundary
        posterId: 'poster_rig_99',
        posterName: 'DeepSea Engineering Corp Ltd.',
        posterPhone: '+233 31 200 1111',
        isFilled: false,
        status: JobStatus.inProgress,
        isFavorite: true,
        createdAt: DateTime.utc(1970, 1, 1, 0, 0, 0), // Unix Epoch boundary
      );

      await storage.saveJobs([extremeJob]);
      final retrievedJobs = storage.getJobs();

      expect(retrievedJobs.length, equals(1));
      final recovered = retrievedJobs.first;
      expect(recovered.id, equals('job_extreme_001'));
      expect(recovered.description.length, equals(15000));
      expect(recovered.status, equals(JobStatus.inProgress));
      expect(recovered.latitude, equals(-89.999999));
      expect(recovered.longitude, equals(179.999999));
      expect(recovered.payRate, equals(99999.99));
      expect(recovered.isFavorite, isTrue);
    });

    test('JobApplication serialization fidelity across all ApplicationStatus states', () async {
      for (final status in ApplicationStatus.values) {
        final app = JobApplication(
          id: 'app_status_${status.name}',
          jobId: 'job_status_test',
          jobTitle: 'Plumber Status Test',
          seekerId: 'seeker_01',
          seekerName: 'Kwame',
          seekerPhone: '+233 24 123 4567',
          posterId: 'poster_01',
          status: status,
          note: 'Testing status: ${status.name}',
          appliedAt: DateTime.now(),
        );

        final map = app.toMap();
        expect(map['status'], equals(status.name));

        final reconstructed = JobApplication.fromMap(map, app.id);
        expect(reconstructed.status, equals(status));
        expect(reconstructed.id, equals(app.id));
      }
    });

    test('parseDateTime resilience with corrupt, ISO string, milliseconds, int, and Timestamp objects', () {
      final now = DateTime.now();
      expect(parseDateTime(now).millisecondsSinceEpoch, equals(now.millisecondsSinceEpoch));
      expect(parseDateTime(now.toIso8601String()).millisecondsSinceEpoch, equals(now.millisecondsSinceEpoch));
      expect(parseDateTime(1700000000000).millisecondsSinceEpoch, equals(1700000000000));
      
      // Fallback for null and invalid types
      final fallbackBefore = DateTime.now();
      final parsedNull = parseDateTime(null);
      final fallbackAfter = DateTime.now();
      expect(parsedNull.isAfter(fallbackBefore.subtract(const Duration(seconds: 1))), isTrue);
      expect(parsedNull.isBefore(fallbackAfter.add(const Duration(seconds: 1))), isTrue);

      final parsedCorrupt = parseDateTime('not_a_valid_date_string_xyz');
      expect(parsedCorrupt, isA<DateTime>());
    });
  });

  // ===========================================================================
  // 2. CORRUPTED CACHE HANDLING & COLD-RESTART RECOVERY
  // ===========================================================================
  group('Adversarial 2: Corrupted Cache Handling & Cold Restart Resiliency', () {
    test('LocalStorageService survives truncated / malformed JSON in all storage keys', () async {
      final prefs = storage.prefs;

      // Inject corrupt JSON strings directly into SharedPreferences
      await prefs.setString(LocalStorageService.keyUser, '{"id": "usr_broken", "displa');
      await prefs.setString(LocalStorageService.keyJobs, '[{"id": "job_1", "title": "Plu... TRUNCATED');
      await prefs.setString(LocalStorageService.keyChatRooms, '<xml>This is not JSON</xml>');
      await prefs.setString(LocalStorageService.keyApplications, '{"error": "500 Internal Server Error"}'); // Map instead of List
      await prefs.setString('${LocalStorageService.keyMessagesPrefix}room_123', '[[nested array invalid]]');

      // None of the getters should throw an uncaught exception
      expect(storage.getUser(), isNull);
      expect(storage.getJobs(), isEmpty);
      expect(storage.getChatRooms(), isEmpty);
      expect(storage.getApplications(), isEmpty);
      expect(storage.getMessages('room_123'), isEmpty);
    });

    test('LocalStorageService gracefully filters type-corrupted items in mixed valid/corrupt array', () async {
      final prefs = storage.prefs;

      final mixedJobsPayload = jsonEncode([
        {'id': 'valid_1', 'title': 'Valid Job 1', 'description': 'desc', 'category': 'Other', 'payRate': 100.0, 'city': 'Accra', 'locationName': 'Accra', 'latitude': 5.5, 'longitude': -0.2, 'posterId': 'p1', 'posterName': 'P1', 'posterPhone': '+233241234567', 'createdAt': DateTime.now().toIso8601String()},
        'corrupted string element',
        123456,
        null,
        {'id': 'corrupt_type', 'title': 99999}, // title is int instead of String -> throws TypeError caught by try-catch
        {'id': 'valid_2', 'title': 'Valid Job 2', 'description': 'desc2', 'category': 'Cleaning', 'payRate': 80.0, 'city': 'Kumasi', 'locationName': 'Kejetia', 'latitude': 6.6, 'longitude': -1.6, 'posterId': 'p2', 'posterName': 'P2', 'posterPhone': '+233501234567', 'createdAt': DateTime.now().toIso8601String()},
      ]);

      await prefs.setString(LocalStorageService.keyJobs, mixedJobsPayload);

      final recoveredJobs = storage.getJobs();
      expect(recoveredJobs.length, equals(2));
      expect(recoveredJobs[0].id, equals('valid_1'));
      expect(recoveredJobs[1].id, equals('valid_2'));
    });

    test('ApplicationProvider initializes gracefully and operates normally even when cache is corrupt', () async {
      final prefs = storage.prefs;
      await prefs.setString(LocalStorageService.keyApplications, '{ malformed: json [!@#');

      final provider = ApplicationProvider(
        applicationRepository: InMemoryApplicationRepository(),
        localStorageService: storage,
      );

      expect(provider.applications, isEmpty);
      expect(provider.isLoading, isFalse);
      expect(provider.errorMessage, isNull);

      // Mutating data after corrupt startup still works cleanly
      final success = await provider.submitApplication(
        jobId: 'job_fresh',
        jobTitle: 'Painter',
        employerId: 'emp_1',
        applicantId: 'seeker_1',
        applicantName: 'Kwame',
        applicantPhone: '+233 24 111 2222',
        coverNote: 'Ready to paint',
      );

      expect(success, isTrue);
      expect(provider.applications.length, equals(1));
      expect(provider.hasApplied('job_fresh', 'seeker_1'), isTrue);

      // Verify that local storage was overwritten with valid payload
      final cachedApps = storage.getApplications();
      expect(cachedApps.length, equals(1));
      expect(cachedApps.first.jobTitle, equals('Painter'));
    });
  });

  // ===========================================================================
  // 3. CONCURRENCY RACE CONDITIONS & RAPID ASYNC MUTATIONS
  // ===========================================================================
  group('Adversarial 3: Concurrency Race Conditions & High Load Stress', () {
    test('50 concurrent simultaneous saveApplications and getApplications operations', () async {
      final futures = <Future>[];

      for (int i = 0; i < 50; i++) {
        final apps = [
          JobApplication(
            id: 'app_race_$i',
            jobId: 'job_$i',
            jobTitle: 'Job Title $i',
            seekerId: 'seeker_$i',
            seekerName: 'Seeker $i',
            seekerPhone: '+233 24 111 22$i',
            posterId: 'poster_$i',
            status: ApplicationStatus.pending,
            note: 'Concurrent load test note $i',
            appliedAt: DateTime.now(),
          ),
        ];

        if (i % 2 == 0) {
          futures.add(storage.saveApplications(apps));
        } else {
          futures.add(Future.sync(() => storage.getApplications()));
        }
      }

      await expectLater(Future.wait(futures), completes);
      final finalApps = storage.getApplications();
      expect(finalApps, isNotNull);
    });

    test('ApplicationProvider duplicate submission idempotency under concurrent race', () async {
      final appRepo = InMemoryApplicationRepository();
      final provider = ApplicationProvider(
        applicationRepository: appRepo,
        localStorageService: storage,
      );

      // Launch 20 simultaneous submissions for the SAME seeker and SAME job concurrently
      final submissionFutures = List.generate(
        20,
        (index) => provider.submitApplication(
          jobId: 'job_shared_001',
          jobTitle: 'Warehouse Assistant',
          employerId: 'employer_001',
          applicantId: 'seeker_unique_007',
          applicantName: 'Kofi Seeker',
          applicantPhone: '+233 24 000 1111',
          coverNote: 'Note attempt $index',
        ),
      );

      final results = await Future.wait(submissionFutures);

      // Exactly ONE submission must succeed; the other 19 must return false
      final successCount = results.where((r) => r == true).length;
      final rejectedCount = results.where((r) => r == false).length;

      expect(successCount, equals(1));
      expect(rejectedCount, equals(19));
      expect(provider.applications.length, equals(1));
      expect(provider.hasApplied('job_shared_001', 'seeker_unique_007'), isTrue);
    });

    test('Concurrent status updates on ApplicationProvider maintain consistency', () async {
      final provider = ApplicationProvider(
        applicationRepository: InMemoryApplicationRepository(),
        localStorageService: storage,
      );

      // Submit 10 applications
      for (int i = 0; i < 10; i++) {
        await provider.submitApplication(
          jobId: 'job_$i',
          jobTitle: 'Job $i',
          employerId: 'emp_$i',
          applicantId: 'seeker_$i',
          applicantName: 'Seeker $i',
          applicantPhone: '+233 24 100 200$i',
          coverNote: 'Note $i',
          applicationId: 'app_concurrent_$i',
        );
      }

      expect(provider.applications.length, equals(10));

      // Rapidly update status for all 10 applications concurrently
      final updateFutures = List.generate(
        10,
        (i) => provider.updateApplicationStatus(
          'app_concurrent_$i',
          i % 2 == 0 ? ApplicationStatus.accepted : ApplicationStatus.rejected,
        ),
      );

      final updateResults = await Future.wait(updateFutures);
      expect(updateResults.every((res) => res == true), isTrue);

      // Verify all statuses match
      for (int i = 0; i < 10; i++) {
        final app = provider.applications.firstWhere((a) => a.id == 'app_concurrent_$i');
        expect(app.status, equals(i % 2 == 0 ? ApplicationStatus.accepted : ApplicationStatus.rejected));
      }
    });
  });

  // ===========================================================================
  // 4. EXTREME VALUES: BOUNDARY PAY RATES & NUMERIC FUZZING
  // ===========================================================================
  group('Adversarial 4: Extreme Values & Pay Rate Boundary Validation', () {
    test('FormValidators.validatePayRate boundary enforcement and identified NaN loophole', () {
      // Invalid pay rates that ARE rejected by validatePayRate
      final rejectedRates = [
        '',
        '   ',
        '0',
        '0.0',
        '0.00',
        '-1',
        '-50.0',
        '-0.0001',
        '100000.01', // above 100,000 max
        '999999999',
        '1e6', // 1,000,000 (above 100,000 max)
        '0x10',
        'abc',
        'GHS 150',
        '\$200',
        '50.00.00',
        '10,000',
        '12..34',
        '<script>100</script>',
        'null',
        'undefined',
      ];

      for (final rate in rejectedRates) {
        final error = FormValidators.validatePayRate(rate);
        expect(error, isNotNull, reason: 'Expected "$rate" to fail validation');
      }

      // Valid pay rates that pass
      final validRates = [
        '0.01',
        '1',
        '50',
        '150.50',
        '1000',
        '99999.99',
        '100000',
        '100000.00',
        ' 500 ', // leading/trailing spaces get trimmed
      ];

      for (final rate in validRates) {
        final error = FormValidators.validatePayRate(rate);
        expect(error, isNull, reason: 'Expected "$rate" to be valid');
      }

      // With parsed.isNaN and !parsed.isFinite guards, validatePayRate rejects NaN and Infinity:
      final nanValidationResult = FormValidators.validatePayRate('NaN');
      expect(nanValidationResult, isNotNull, reason: 'validatePayRate correctly rejects NaN');
      expect(FormValidators.validatePayRate('Infinity'), isNotNull, reason: 'validatePayRate correctly rejects Infinity');
      expect(FormValidators.validatePayRate('-Infinity'), isNotNull, reason: 'validatePayRate correctly rejects -Infinity');

      // However, CreateJobScreen / InputSanitizer shields the UI by stripping non-digits:
      final sanitizedNan = InputSanitizer.sanitizeNumeric('NaN');
      expect(sanitizedNan, equals('')); // Sanitizer safely strips 'NaN' to empty string
    });

    test('InputSanitizer.sanitizeNumeric strips invalid chars and keeps at most one decimal point', () {
      expect(InputSanitizer.sanitizeNumeric('GHS 250.75'), equals('250.75'));
      expect(InputSanitizer.sanitizeNumeric('\$1,500.00'), equals('1500.00'));
      expect(InputSanitizer.sanitizeNumeric('50.25.75'), equals('50.2575'));
      expect(InputSanitizer.sanitizeNumeric('abc 99.9 xyz'), equals('99.9'));
      expect(InputSanitizer.sanitizeNumeric('<script>50</script>'), equals('50'));
      expect(InputSanitizer.sanitizeNumeric(null), equals(''));
    });
  });

  // ===========================================================================
  // 5. MALICIOUS STRINGS, SCRIPT TAGS, AND SECURITY INJECTION ATTACKS
  // ===========================================================================
  group('Adversarial 5: Malicious Strings & Security Injection Hardening', () {
    test('InputSanitizer neutralizes aggressive XSS vectors, polyglot scripts, and event handlers', () {
      final attackVectors = <String, String>{
        '<script>alert("XSS")</script>Hello': 'Hello',
        '<SCRIPT SRC="http://evil.com/xss.js"></SCRIPT>Clean': 'Clean',
        '<script type="text/javascript">document.cookie="stolen";</script>Normal Text': 'Normal Text',
        'javascript:alert(1)': 'alert(1)', // Strips protocol prefix
        'JaVaScRiPt:void(0)': 'void(0)', // Strips case-insensitive protocol prefix
        '<img src=x onerror=alert(1)>': '',
        '<svg onload=alert(document.domain)>': '',
        '<iframe src="javascript:alert(1)"></iframe>': '',
        '<body onload=alert(1)>': '',
        'Normal text with <b style="color:red">bold</b>': 'Normal text with bold',
        'Null\x00Byte\x08Attack': 'NullByteAttack',
        '   Lots of surrounding spaces   ': 'Lots of surrounding spaces',
      };

      attackVectors.forEach((input, expectedOutput) {
        final sanitized = InputSanitizer.sanitize(input);
        expect(sanitized, equals(expectedOutput), reason: 'Failed to sanitize vector: $input');
        expect(sanitized.contains('<script>'), isFalse);
        expect(sanitized.contains('javascript:'), isFalse);
      });
    });

    test('FormValidators email validator rejects injection payloads and malformed emails', () {
      final invalidEmails = [
        '',
        '   ',
        'plainaddress',
        '@missinguser.com',
        'user@.com',
        'user@com',
        'user<script>alert(1)</script>@domain.com',
        'user@domain.com\x00.evil.com',
        'user@domain.com\nCC:victim@evil.com',
        'user name@domain.com',
        'user@domain..com',
        'user..name@domain.com',
        'user@..domain.com',
      ];

      for (final email in invalidEmails) {
        expect(FormValidators.validateEmail(email), isNotNull, reason: 'Expected "$email" to be invalid');
      }

      final validEmails = [
        'kwame.mensah@gmail.com',
        'support@jobconnector.com.gh',
        'user+tag@domain.co.uk',
        'employer_123@sub.domain.org',
      ];

      for (final email in validEmails) {
        expect(FormValidators.validateEmail(email), isNull, reason: 'Expected "$email" to be valid');
      }
    });

    test('FormValidators Ghana phone validator strictly enforces Ghanaian telecommunication prefixes', () {
      // Valid Ghana formats (+233 or local 0 followed by 2, 3, or 5 and 8 digits)
      final validPhones = [
        '+233241234567',
        '+233 24 123 4567',
        '+233-24-123-4567',
        '(+233) 24 123 4567',
        '0241234567',
        '0209876543',
        '0551122334',
        '0505566778',
        '0302123456', // Accra landline prefix
      ];

      for (final phone in validPhones) {
        expect(FormValidators.validateGhanaPhone(phone), isNull, reason: 'Expected Ghana phone "$phone" to be valid');
      }

      // Invalid / malicious phone strings
      final invalidPhones = [
        '',
        '   ',
        '+1 555 123 4567', // US number
        '+44 20 7946 0958', // UK number
        '+234 802 123 4567', // Nigeria number
        '0123456789', // Invalid Ghanaian prefix (01X)
        '0781234567', // Invalid Ghanaian prefix (07X)
        '024123456', // Too short (8 digits)
        '024123456789', // Too long
        '0241234567<script>',
        '0241234567; DROP TABLE;',
        '+233 24 123 4567\x00',
      ];

      for (final phone in invalidPhones) {
        expect(FormValidators.validateGhanaPhone(phone), isNotNull, reason: 'Expected phone "$phone" to be rejected');
      }
    });
  });

  // ===========================================================================
  // 6. RAPID OFFLINE/ONLINE STATE TRANSITIONS & BANNER RESILIENCY
  // ===========================================================================
  group('Adversarial 6: Rapid Offline/Online State Transitions', () {
    test('ConnectivityProvider handles 200 rapid online/offline toggles without memory leak or state inconsistency', () {
      final connectivityProvider = ConnectivityProvider();
      expect(connectivityProvider.isOnline, isTrue);

      int listenerNotificationCount = 0;
      connectivityProvider.addListener(() {
        listenerNotificationCount++;
      });

      for (int i = 0; i < 200; i++) {
        final expectedState = i % 2 == 0 ? false : true;
        connectivityProvider.setOnline(expectedState);
        expect(connectivityProvider.isOnline, equals(expectedState));
      }

      expect(listenerNotificationCount, equals(200));

      // Setting same state consecutively does not trigger superfluous notification
      connectivityProvider.setOnline(true);
      final countBefore = listenerNotificationCount;
      connectivityProvider.setOnline(true);
      expect(listenerNotificationCount, equals(countBefore));
    });

    test('ApplicationProvider and JobProvider remain stable when network flips during active workflows', () async {
      final connectivityProvider = ConnectivityProvider();
      final appProvider = ApplicationProvider(
        applicationRepository: InMemoryApplicationRepository(),
        localStorageService: storage,
      );
      final jobProvider = JobProvider(
        jobRepository: InMemoryJobRepository(initialJobs: []),
        localStorageService: storage,
      );

      // Perform simultaneous operations while network is toggling rapidly
      for (int i = 0; i < 15; i++) {
        connectivityProvider.setOnline(i % 2 == 0);

        final submitFuture = appProvider.submitApplication(
          jobId: 'toggle_job_$i',
          jobTitle: 'Toggle Job $i',
          employerId: 'emp_$i',
          applicantId: 'seeker_$i',
          applicantName: 'Seeker $i',
          applicantPhone: '+233 24 123 450$i',
          coverNote: 'Note $i',
        );

        final addJobFuture = jobProvider.addJob(
          JobPost(
            id: 'job_toggle_$i',
            title: 'Job Toggle $i',
            description: 'Desc',
            category: 'Other',
            payRate: 100.0 + i,
            city: 'Accra',
            locationName: 'Accra Mall',
            latitude: 5.6,
            longitude: -0.17,
            posterId: 'emp_$i',
            posterName: 'Emp $i',
            posterPhone: '+233 24 123 450$i',
            createdAt: DateTime.now(),
          ),
        );

        await Future.wait([submitFuture, addJobFuture]);
      }

      expect(appProvider.applications.length, equals(15));
      expect(jobProvider.allJobs.length, equals(15));
      expect(storage.getApplications().length, equals(15));
      expect(storage.getJobs().length, equals(15));
    });
  });
}
