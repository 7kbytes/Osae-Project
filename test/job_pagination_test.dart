import 'package:flutter_test/flutter_test.dart';
import 'package:local_job_connector/core/models/job_model.dart';
import 'package:local_job_connector/core/providers/job_provider.dart';
import 'package:local_job_connector/core/repositories/job_repository.dart';
import 'package:local_job_connector/core/services/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

JobPost _job(int i) => JobPost(
  id: 'job_$i',
  title: 'Job $i',
  description: 'd',
  category: 'Cleaning',
  payRate: 50,
  city: 'Accra',
  locationName: 'Osu',
  latitude: 5.5,
  longitude: -0.2,
  posterId: 'poster1',
  posterName: 'Poster',
  posterPhone: '0241234567',
  createdAt: DateTime(2026, 1, 1).subtract(Duration(minutes: i)),
);

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  late LocalStorageService storage;
  late JobProvider provider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalStorageService(prefs: await SharedPreferences.getInstance());
    provider = JobProvider(
      jobRepository: InMemoryJobRepository(
        initialJobs: [for (var i = 0; i < 45; i++) _job(i)],
      ),
      localStorageService: storage,
    );
    await _settle();
  });

  test('feed loads one page at a time until exhausted', () async {
    expect(provider.filteredJobs.length, JobProvider.pageSize);
    expect(provider.hasMore, isTrue);

    provider.loadMore();
    await _settle();
    expect(provider.filteredJobs.length, 2 * JobProvider.pageSize);
    expect(provider.hasMore, isTrue);

    provider.loadMore();
    await _settle();
    expect(provider.filteredJobs.length, 45);
    expect(provider.hasMore, isFalse);
  });

  test('a job outside the loaded page can be fetched by id', () async {
    expect(provider.allJobs.any((j) => j.id == 'job_44'), isFalse);

    final job = await provider.ensureJob('job_44');

    expect(job?.id, 'job_44');
    expect(provider.allJobs.any((j) => j.id == 'job_44'), isTrue);
    // The feed itself still shows only the loaded page.
    expect(provider.filteredJobs.length, JobProvider.pageSize);
  });

  test('unknown job ids resolve to null without refetching', () async {
    expect(await provider.ensureJob('nope'), isNull);
    expect(await provider.ensureJob('nope'), isNull);
  });

  test('status changes work on a job fetched by id', () async {
    await provider.ensureJob('job_40');

    await provider.updateJobStatus('job_40', JobStatus.completed);

    final job = provider.allJobs.firstWhere((j) => j.id == 'job_40');
    expect(job.status, JobStatus.completed);
  });

  test('favourites include saved jobs outside the loaded page', () async {
    await provider.toggleFavorite('job_42', userId: 'seeker1');
    provider.favoriteJobs; // triggers the fetch
    await _settle();

    expect(provider.favoriteJobs.map((j) => j.id), contains('job_42'));
  });

  group("filters run as backend queries", () {
    late JobProvider mixed;

    setUp(() async {
      mixed = JobProvider(
        jobRepository: InMemoryJobRepository(
          initialJobs: [
            for (var i = 0; i < 45; i++)
              _job(i).copyWith(city: i.isEven ? "Accra" : "Kumasi"),
          ],
        ),
        localStorageService: storage,
      );
      await _settle();
    });

    test("a city filter queries that city and restarts paging", () async {
      mixed.loadMore();
      await _settle();
      expect(mixed.filteredJobs.length, 2 * JobProvider.pageSize);

      mixed.setCityFilter("Kumasi");
      await _settle();

      // Back to page one, and every job comes from the filtered query.
      expect(mixed.filteredJobs.length, JobProvider.pageSize);
      expect(mixed.filteredJobs.every((j) => j.city == "Kumasi"), isTrue);
    });

    test("paging continues within a filter", () async {
      mixed.setCityFilter("Kumasi");
      await _settle();
      mixed.loadMore();
      await _settle();

      // 22 Kumasi jobs in total, so the second page is the last.
      expect(mixed.filteredJobs.length, 22);
      expect(mixed.filteredJobs.every((j) => j.city == "Kumasi"), isTrue);
      expect(mixed.hasMore, isFalse);
    });
  });
}
