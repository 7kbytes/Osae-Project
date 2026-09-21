import 'package:flutter_test/flutter_test.dart';
import 'package:local_job_connector/core/models/job_model.dart';
import 'package:local_job_connector/core/models/user_model.dart';
import 'package:local_job_connector/core/providers/job_provider.dart';
import 'package:local_job_connector/core/repositories/job_repository.dart';

void main() {
  group('JobProvider Tests', () {
    late JobProvider jobProvider;
    late InMemoryJobRepository jobRepository;

    setUp(() {
      jobRepository = InMemoryJobRepository();
      jobProvider = JobProvider(jobRepository: jobRepository);
    });

    test('Initial jobs loaded correctly', () {
      expect(jobProvider.allJobs.isNotEmpty, true);
      expect(jobProvider.selectedCity, 'All');
      expect(jobProvider.selectedCategory, 'All');
      expect(jobProvider.searchQuery, '');
    });

    test('Filter jobs by city', () {
      jobProvider.setCityFilter('Accra');
      final accraJobs = jobProvider.filteredJobs;
      expect(accraJobs.isNotEmpty, true);
      expect(accraJobs.every((job) => job.city == 'Accra'), true);

      jobProvider.setCityFilter('Kumasi');
      final kumasiJobs = jobProvider.filteredJobs;
      expect(kumasiJobs.isNotEmpty, true);
      expect(kumasiJobs.every((job) => job.city == 'Kumasi'), true);

      jobProvider.setCityFilter('Tema');
      final temaJobs = jobProvider.filteredJobs;
      expect(temaJobs.isNotEmpty, true);
      expect(temaJobs.every((job) => job.city == 'Tema'), true);

      jobProvider.setCityFilter('All');
      expect(jobProvider.filteredJobs.length, jobProvider.allJobs.length);
    });

    test('Filter jobs by category', () {
      jobProvider.setCategoryFilter('Hospitality');
      final hospitalityJobs = jobProvider.filteredJobs;
      expect(hospitalityJobs.isNotEmpty, true);
      expect(
        hospitalityJobs.every((job) => job.category == 'Hospitality'),
        true,
      );

      jobProvider.setCategoryFilter('Cleaning');
      final cleaningJobs = jobProvider.filteredJobs;
      expect(cleaningJobs.isNotEmpty, true);
      expect(cleaningJobs.every((job) => job.category == 'Cleaning'), true);
    });

    test('Search jobs by title, description, or location landmark', () {
      jobProvider.setSearchQuery('Circle');
      final circleResults = jobProvider.filteredJobs;
      expect(circleResults.isNotEmpty, true);
      expect(
        circleResults.every(
          (job) =>
              job.title.toLowerCase().contains('circle') ||
              job.description.toLowerCase().contains('circle') ||
              job.locationName.toLowerCase().contains('circle'),
        ),
        true,
      );

      jobProvider.setSearchQuery('Kejetia');
      final kejetiaResults = jobProvider.filteredJobs;
      expect(kejetiaResults.isNotEmpty, true);

      jobProvider.setSearchQuery('nonexistentkeyword123');
      expect(jobProvider.filteredJobs.isEmpty, true);

      jobProvider.setSearchQuery('');
      expect(jobProvider.filteredJobs.length, jobProvider.allJobs.length);
    });

    test('Toggle favorite job and verify favoriteJobs getter', () async {
      final firstJobId = jobProvider.allJobs.first.id;
      expect(jobProvider.isFavorite(firstJobId), false);
      expect(jobProvider.favoriteJobs.isEmpty, true);

      await jobProvider.toggleFavorite(firstJobId);
      expect(jobProvider.isFavorite(firstJobId), true);
      expect(jobProvider.favoriteJobs.length, 1);
      expect(jobProvider.favoriteJobs.first.id, firstJobId);

      await jobProvider.toggleFavorite(firstJobId);
      expect(jobProvider.isFavorite(firstJobId), false);
      expect(jobProvider.favoriteJobs.isEmpty, true);
    });

    test('Add new job post', () async {
      final initialCount = jobProvider.allJobs.length;
      final newJob = JobPost(
        id: 'test_job_99',
        title: 'Test Helper in Accra',
        description: 'Testing description for site helper',
        category: 'Cleaning',
        payRate: 150.0,
        payUnit: 'per day',
        currency: 'GHS',
        city: 'Accra',
        locationName: 'Accra Mall',
        latitude: 5.62,
        longitude: -0.18,
        posterId: 'poster_test',
        posterName: 'Test Vendor',
        posterPhone: '+233 24 000 0000',
        createdAt: DateTime.now(),
      );

      await jobProvider.addJob(newJob);
      expect(jobProvider.allJobs.length, initialCount + 1);
      expect(jobProvider.allJobs.first.title, 'Test Helper in Accra');

      // Verify searchable
      jobProvider.setSearchQuery('Accra Mall');
      expect(jobProvider.filteredJobs.first.id, 'test_job_99');
    });

    test('Delete job post', () async {
      final initialCount = jobProvider.allJobs.length;
      final targetId = jobProvider.allJobs.first.id;

      await jobProvider.deleteJob(targetId);
      expect(jobProvider.allJobs.length, initialCount - 1);
      expect(jobProvider.allJobs.any((j) => j.id == targetId), false);
    });

    test('Switch user role', () {
      expect(jobProvider.currentUserRole, UserRole.seeker);
      jobProvider.setRole(UserRole.poster);
      expect(jobProvider.currentUserRole, UserRole.poster);
      jobProvider.setRole(UserRole.seeker);
      expect(jobProvider.currentUserRole, UserRole.seeker);
    });
  });
}
