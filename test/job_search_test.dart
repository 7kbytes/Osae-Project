import 'package:flutter_test/flutter_test.dart';
import 'package:local_job_connector/core/models/job_model.dart';
import 'package:local_job_connector/core/providers/job_provider.dart';
import 'package:local_job_connector/core/repositories/job_repository.dart';
import 'package:local_job_connector/core/services/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

JobPost _job({
  required String id,
  required String title,
  String city = 'Accra',
}) => JobPost(
  id: id,
  title: title,
  description: 'Work description',
  category: 'Cleaning',
  payRate: 50,
  city: city,
  locationName: 'Osu',
  latitude: 5.5,
  longitude: -0.2,
  posterId: 'poster1',
  posterName: 'Poster',
  posterPhone: '0241234567',
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  group('search keywords', () {
    test('stores word prefixes so partial typing matches', () {
      final terms = _job(id: 'j1', title: 'Cleaning office').searchTerms;

      expect(terms, contains('cle'));
      expect(terms, contains('clean'));
      expect(terms, contains('cleaning'));
      expect(terms, contains('office'));
      // The city and category are searchable too.
      expect(terms, contains('accra'));
    });

    test('long words are capped, and so is the term searched for', () {
      final terms = JobPost.buildSearchTerms(['extraordinarily']);

      expect(terms.every((t) => t.length <= JobPost.maxTermLength), isTrue);
      expect(
        JobPost.searchTermFor('extraordinarily')!.length,
        JobPost.maxTermLength,
      );
    });

    test('queries shorter than three letters do not filter the backend', () {
      expect(JobPost.searchTermFor('ab'), isNull);
      expect(JobPost.searchTermFor('  '), isNull);
      expect(JobPost.searchTermFor('a cleaning job'), 'cleaning');
    });

    test('keywords are written to the document', () {
      final map = _job(id: 'j1', title: 'Cleaning office').toMap();
      expect(map['searchTerms'], contains('clean'));
    });
  });

  group('search runs as a backend query', () {
    late JobProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final storage = LocalStorageService(
        prefs: await SharedPreferences.getInstance(),
      );
      provider = JobProvider(
        jobRepository: InMemoryJobRepository(
          initialJobs: [
            _job(id: 'j1', title: 'Cleaning office'),
            _job(id: 'j2', title: 'Security guard', city: 'Kumasi'),
            _job(id: 'j3', title: 'Cleaner for shop'),
          ],
        ),
        localStorageService: storage,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });

    test('a partly typed word matches, after the debounce', () async {
      provider.setSearchQuery('clean');
      await Future<void>.delayed(
        JobProvider.searchDebounce + const Duration(milliseconds: 40),
      );

      final ids = provider.filteredJobs.map((j) => j.id).toList();
      expect(ids, containsAll(<String>['j1', 'j3']));
      expect(ids, isNot(contains('j2')));
    });

    test('clearing the search restores the full feed', () async {
      provider.setSearchQuery('security');
      await Future<void>.delayed(
        JobProvider.searchDebounce + const Duration(milliseconds: 40),
      );
      expect(provider.filteredJobs.map((j) => j.id), ['j2']);

      provider.setSearchQuery('');
      await Future<void>.delayed(
        JobProvider.searchDebounce + const Duration(milliseconds: 40),
      );
      expect(provider.filteredJobs.length, 3);
    });
  });
}
