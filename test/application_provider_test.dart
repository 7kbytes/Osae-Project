import 'package:flutter_test/flutter_test.dart';
import 'package:local_job_connector/core/models/job_application_model.dart';
import 'package:local_job_connector/core/providers/application_provider.dart';
import 'package:local_job_connector/core/repositories/application_repository.dart';
import 'package:local_job_connector/core/services/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService localStorageService;
  late ApplicationRepository applicationRepository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    localStorageService = LocalStorageService(prefs: prefs);
    applicationRepository = InMemoryApplicationRepository(
      localStorageService: localStorageService,
    );
  });

  group('ApplicationProvider Unit Tests', () {
    test('Initializes with empty cache cleanly', () {
      final provider = ApplicationProvider(
        applicationRepository: applicationRepository,
        localStorageService: localStorageService,
      );

      expect(provider.applications, isEmpty);
      expect(provider.myApplications, isEmpty);
      expect(provider.isLoading, false);
      expect(provider.errorMessage, isNull);
    });

    test('Hydrates applications from LocalStorageService on initialization', () {
      final preloaded = [
        JobApplication(
          id: 'app_pre_1',
          jobId: 'job_001',
          jobTitle: 'Masonry Helper',
          seekerId: 'seeker_001',
          seekerName: 'Kofi Mensah',
          seekerPhone: '+233 24 111 2222',
          posterId: 'poster_001',
          status: ApplicationStatus.pending,
          note: 'Ready to work tomorrow',
          appliedAt: DateTime(2026, 8, 28),
        ),
      ];
      localStorageService.saveApplications(preloaded);

      final provider = ApplicationProvider(
        applicationRepository: applicationRepository,
        localStorageService: localStorageService,
        initialSeekerId: 'seeker_001',
      );

      expect(provider.applications.length, 1);
      expect(provider.applications.first.id, 'app_pre_1');
      expect(provider.myApplications.length, 1);
      expect(provider.hasApplied('job_001', 'seeker_001'), true);
      expect(provider.hasApplied('job_002', 'seeker_001'), false);
    });

    test('submitApplication adds application, notifies, and persists to local storage', () async {
      final provider = ApplicationProvider(
        applicationRepository: applicationRepository,
        localStorageService: localStorageService,
      );

      bool notified = false;
      provider.addListener(() {
        notified = true;
      });

      final success = await provider.submitApplication(
        jobId: 'job_circle_01',
        jobTitle: 'VIP Loading Assistant',
        employerId: 'poster_accra_01',
        applicantId: 'seeker_kwame',
        applicantName: 'Kwame Osei',
        applicantPhone: '+233 24 999 8888',
        coverNote: 'Experienced loader at VIP terminal',
      );

      expect(success, true);
      expect(notified, true);
      expect(provider.applications.length, 1);

      final app = provider.applications.first;
      expect(app.jobId, 'job_circle_01');
      expect(app.jobTitle, 'VIP Loading Assistant');
      expect(app.seekerId, 'seeker_kwame');
      expect(app.seekerName, 'Kwame Osei');
      expect(app.seekerPhone, '+233 24 999 8888');
      expect(app.posterId, 'poster_accra_01');
      expect(app.status, ApplicationStatus.pending);
      expect(app.note, 'Experienced loader at VIP terminal');

      // Verify persistence in LocalStorageService
      final persisted = localStorageService.getApplications();
      expect(persisted.length, 1);
      expect(persisted.first.id, app.id);
    });

    test('Prevents duplicate submissions for same job and seeker', () async {
      final provider = ApplicationProvider(
        applicationRepository: applicationRepository,
        localStorageService: localStorageService,
      );

      final firstSubmit = await provider.submitApplication(
        jobId: 'job_unique_01',
        jobTitle: 'Store Clerk',
        employerId: 'poster_01',
        applicantId: 'seeker_01',
        applicantName: 'Ama',
        applicantPhone: '+233 20 123 4567',
        coverNote: 'First application',
      );
      expect(firstSubmit, true);
      expect(provider.hasApplied('job_unique_01', 'seeker_01'), true);

      // Attempt duplicate submission
      final duplicateSubmit = await provider.submitApplication(
        jobId: 'job_unique_01',
        jobTitle: 'Store Clerk',
        employerId: 'poster_01',
        applicantId: 'seeker_01',
        applicantName: 'Ama',
        applicantPhone: '+233 20 123 4567',
        coverNote: 'Duplicate application attempt',
      );

      expect(duplicateSubmit, false);
      expect(provider.applications.length, 1);
    });

    test('updateApplicationStatus transitions status and persists changes', () async {
      final provider = ApplicationProvider(
        applicationRepository: applicationRepository,
        localStorageService: localStorageService,
      );

      await provider.submitApplication(
        applicationId: 'app_test_status',
        jobId: 'job_market_01',
        jobTitle: 'Produce Packer',
        employerId: 'poster_market',
        applicantId: 'seeker_yaw',
        applicantName: 'Yaw Boateng',
        applicantPhone: '+233 50 111 2222',
        coverNote: 'Fast packer',
      );

      expect(
        provider.applications.first.status,
        ApplicationStatus.pending,
      );

      // Transition to Accepted
      final acceptResult = await provider.updateApplicationStatus(
        'app_test_status',
        ApplicationStatus.accepted,
      );
      expect(acceptResult, true);
      expect(
        provider.applications.first.status,
        ApplicationStatus.accepted,
      );

      // Verify persisted state
      expect(
        localStorageService.getApplications().first.status,
        ApplicationStatus.accepted,
      );

      // Transition to Rejected
      final rejectResult = await provider.updateApplicationStatus(
        'app_test_status',
        ApplicationStatus.rejected,
      );
      expect(rejectResult, true);
      expect(
        provider.applications.first.status,
        ApplicationStatus.rejected,
      );

      // Non-existent id returns false
      final invalidResult = await provider.updateApplicationStatus(
        'non_existent_app_id',
        ApplicationStatus.completed,
      );
      expect(invalidResult, false);
    });

    test('getApplicationsForJob isolates applications by job ID', () async {
      final provider = ApplicationProvider(
        applicationRepository: applicationRepository,
        localStorageService: localStorageService,
      );

      await provider.submitApplication(
        jobId: 'job_accra_1',
        jobTitle: 'Job 1',
        employerId: 'p1',
        applicantId: 's1',
        applicantName: 'Seeker 1',
        applicantPhone: '111',
        coverNote: 'Note 1',
      );

      await provider.submitApplication(
        jobId: 'job_accra_1',
        jobTitle: 'Job 1',
        employerId: 'p1',
        applicantId: 's2',
        applicantName: 'Seeker 2',
        applicantPhone: '222',
        coverNote: 'Note 2',
      );

      await provider.submitApplication(
        jobId: 'job_kumasi_2',
        jobTitle: 'Job 2',
        employerId: 'p2',
        applicantId: 's3',
        applicantName: 'Seeker 3',
        applicantPhone: '333',
        coverNote: 'Note 3',
      );

      final job1Apps = provider.getApplicationsForJob('job_accra_1');
      expect(job1Apps.length, 2);
      expect(job1Apps.map((a) => a.seekerId), containsAll(['s1', 's2']));

      final job2Apps = provider.getApplicationsForJob('job_kumasi_2');
      expect(job2Apps.length, 1);
      expect(job2Apps.first.seekerId, 's3');

      final emptyJobApps = provider.getApplicationsForJob('non_existent_job');
      expect(emptyJobApps, isEmpty);
    });

    test('getApplicationsForSeeker and myApplications filtering', () async {
      final provider = ApplicationProvider(
        applicationRepository: applicationRepository,
        localStorageService: localStorageService,
        initialSeekerId: 'seeker_main',
      );

      await provider.submitApplication(
        jobId: 'job_1',
        jobTitle: 'Job 1',
        employerId: 'p1',
        applicantId: 'seeker_main',
        applicantName: 'Main Seeker',
        applicantPhone: '111',
        coverNote: 'Main seeker note',
      );

      await provider.submitApplication(
        jobId: 'job_2',
        jobTitle: 'Job 2',
        employerId: 'p2',
        applicantId: 'seeker_other',
        applicantName: 'Other Seeker',
        applicantPhone: '222',
        coverNote: 'Other seeker note',
      );

      expect(provider.myApplications.length, 1);
      expect(provider.myApplications.first.seekerId, 'seeker_main');

      final otherApps = provider.getApplicationsForSeeker('seeker_other');
      expect(otherApps.length, 1);
      expect(otherApps.first.seekerId, 'seeker_other');

      provider.setCurrentSeekerId('seeker_other');
      expect(provider.myApplications.length, 1);
      expect(provider.myApplications.first.seekerId, 'seeker_other');
    });

    test('Cold-restart hydration preserves application history across fresh provider instance', () async {
      final provider1 = ApplicationProvider(
        applicationRepository: applicationRepository,
        localStorageService: localStorageService,
      );

      await provider1.submitApplication(
        applicationId: 'app_cold_1',
        jobId: 'job_cold_1',
        jobTitle: 'Cold Test Job',
        employerId: 'poster_cold',
        applicantId: 'seeker_cold',
        applicantName: 'Cold Seeker',
        applicantPhone: '+233 24 000 1111',
        coverNote: 'Cold restart check',
      );

      await provider1.updateApplicationStatus(
        'app_cold_1',
        ApplicationStatus.accepted,
      );

      // Simulate app restart by creating a new provider instance
      final provider2 = ApplicationProvider(
        applicationRepository: applicationRepository,
        localStorageService: localStorageService,
      );

      expect(provider2.applications.length, 1);
      final reloaded = provider2.applications.first;
      expect(reloaded.id, 'app_cold_1');
      expect(reloaded.jobTitle, 'Cold Test Job');
      expect(reloaded.status, ApplicationStatus.accepted);
      expect(reloaded.seekerName, 'Cold Seeker');
    });
  });
}
