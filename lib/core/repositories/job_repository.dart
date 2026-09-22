import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/job_model.dart';
import '../services/mock_data.dart';

abstract class JobRepository {
  Stream<List<JobPost>> getJobsStream({
    String? city,
    String? category,
    String? search,
    int? limit,
  });
  Future<List<JobPost>> getJobs({String? city, String? category});
  Future<JobPost?> getJobById(String jobId);
  Future<void> addJob(JobPost job);
  Future<void> updateJob(JobPost job);
  Future<void> markJobFilled(String jobId, bool isFilled);
  Future<void> deleteJob(String jobId);
  Stream<Set<String>> getFavoriteJobIdsStream(String userId);
  Future<Set<String>> getFavoriteJobIds(String userId);
  Future<void> toggleFavorite(String userId, String jobId);
}

class FirestoreJobRepository implements JobRepository {
  final FirebaseFirestore _firestore;

  FirestoreJobRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _jobsCollection =>
      _firestore.collection('jobs');

  @override
  Stream<List<JobPost>> getJobsStream({
    String? city,
    String? category,
    String? search,
    int? limit,
  }) {
    Query<Map<String, dynamic>> query = _jobsCollection.orderBy(
      'createdAt',
      descending: true,
    );

    if (city != null && city != 'All' && city.isNotEmpty) {
      query = query.where('city', isEqualTo: city);
    }
    if (category != null && category != 'All' && category.isNotEmpty) {
      query = query.where('category', isEqualTo: category);
    }
    if (limit != null) query = query.limit(limit);

    return query.snapshots().map((snapshot) {
      var list = snapshot.docs
          .map((doc) => JobPost.fromMap(doc.data(), doc.id))
          .toList();
      if (search != null && search.trim().isNotEmpty) {
        final queryLower = search.trim().toLowerCase();
        list = list.where((job) {
          return job.title.toLowerCase().contains(queryLower) ||
              job.description.toLowerCase().contains(queryLower) ||
              job.locationName.toLowerCase().contains(queryLower);
        }).toList();
      }
      return list;
    });
  }

  @override
  Future<List<JobPost>> getJobs({String? city, String? category}) async {
    Query<Map<String, dynamic>> query = _jobsCollection.orderBy(
      'createdAt',
      descending: true,
    );
    if (city != null && city != 'All' && city.isNotEmpty) {
      query = query.where('city', isEqualTo: city);
    }
    if (category != null && category != 'All' && category.isNotEmpty) {
      query = query.where('category', isEqualTo: category);
    }
    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => JobPost.fromMap(doc.data(), doc.id))
        .toList();
  }

  @override
  Future<JobPost?> getJobById(String jobId) async {
    final doc = await _jobsCollection.doc(jobId).get();
    if (!doc.exists || doc.data() == null) return null;
    return JobPost.fromMap(doc.data()!, doc.id);
  }

  @override
  Future<void> addJob(JobPost job) async {
    await _jobsCollection.doc(job.id).set(job.toMap());
  }

  @override
  Future<void> updateJob(JobPost job) async {
    await _jobsCollection.doc(job.id).update(job.toMap());
  }

  @override
  Future<void> markJobFilled(String jobId, bool isFilled) async {
    await _jobsCollection.doc(jobId).update({'isFilled': isFilled});
  }

  @override
  Future<void> deleteJob(String jobId) async {
    await _jobsCollection.doc(jobId).delete();
  }

  @override
  Stream<Set<String>> getFavoriteJobIdsStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toSet());
  }

  @override
  Future<Set<String>> getFavoriteJobIds(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .get();
    return snapshot.docs.map((doc) => doc.id).toSet();
  }

  @override
  Future<void> toggleFavorite(String userId, String jobId) async {
    final favRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .doc(jobId);
    final doc = await favRef.get();
    if (doc.exists) {
      await favRef.delete();
    } else {
      await favRef.set({
        'jobId': jobId,
        'savedAt': FieldValue.serverTimestamp(),
      });
    }
  }
}

class InMemoryJobRepository implements JobRepository {
  final List<JobPost> _jobs = [];
  final Map<String, Set<String>> _favoritesPerUser = {};

  final StreamController<List<JobPost>> _jobsStreamController =
      StreamController<List<JobPost>>.broadcast();

  final Map<String, StreamController<Set<String>>> _favoriteControllers = {};

  InMemoryJobRepository({List<JobPost>? initialJobs}) {
    _jobs.addAll(initialJobs ?? MockData.initialJobs);
  }

  void _notifyJobs() {
    if (!_jobsStreamController.isClosed) {
      _jobsStreamController.add(List.unmodifiable(_jobs));
    }
  }

  void _notifyFavorites(String userId) {
    final controller = _favoriteControllers[userId];
    if (controller != null && !controller.isClosed) {
      controller.add(Set.unmodifiable(_favoritesPerUser[userId] ?? {}));
    }
  }

  @override
  Stream<List<JobPost>> getJobsStream({
    String? city,
    String? category,
    String? search,
    int? limit,
  }) {
    // Initial emit
    Timer.run(_notifyJobs);

    return _jobsStreamController.stream.map((list) {
      // Filter first, then page: the same order Firestore applies.
      final matches = list.where((job) {
        final matchesCity = city == null || city == 'All' || job.city == city;
        final matchesCategory =
            category == null || category == 'All' || job.category == category;
        final matchesSearch =
            search == null ||
            search.trim().isEmpty ||
            job.title.toLowerCase().contains(search.toLowerCase()) ||
            job.description.toLowerCase().contains(search.toLowerCase()) ||
            job.locationName.toLowerCase().contains(search.toLowerCase());
        return matchesCity && matchesCategory && matchesSearch;
      }).toList();
      return limit == null ? matches : matches.take(limit).toList();
    });
  }

  @override
  Future<List<JobPost>> getJobs({String? city, String? category}) async {
    return _jobs.where((job) {
      final matchesCity = city == null || city == 'All' || job.city == city;
      final matchesCategory =
          category == null || category == 'All' || job.category == category;
      return matchesCity && matchesCategory;
    }).toList();
  }

  @override
  Future<JobPost?> getJobById(String jobId) async {
    final index = _jobs.indexWhere((j) => j.id == jobId);
    if (index == -1) return null;
    return _jobs[index];
  }

  @override
  Future<void> addJob(JobPost job) async {
    _jobs.insert(0, job);
    _notifyJobs();
  }

  @override
  Future<void> updateJob(JobPost job) async {
    final index = _jobs.indexWhere((j) => j.id == job.id);
    if (index != -1) {
      _jobs[index] = job;
      _notifyJobs();
    }
  }

  @override
  Future<void> markJobFilled(String jobId, bool isFilled) async {
    final index = _jobs.indexWhere((j) => j.id == jobId);
    if (index != -1) {
      _jobs[index] = _jobs[index].copyWith(isFilled: isFilled);
      _notifyJobs();
    }
  }

  @override
  Future<void> deleteJob(String jobId) async {
    _jobs.removeWhere((j) => j.id == jobId);
    _notifyJobs();
  }

  @override
  Stream<Set<String>> getFavoriteJobIdsStream(String userId) {
    if (!_favoriteControllers.containsKey(userId)) {
      _favoriteControllers[userId] = StreamController<Set<String>>.broadcast();
    }
    Timer.run(() => _notifyFavorites(userId));
    return _favoriteControllers[userId]!.stream;
  }

  @override
  Future<Set<String>> getFavoriteJobIds(String userId) async {
    return Set.from(_favoritesPerUser[userId] ?? {});
  }

  @override
  Future<void> toggleFavorite(String userId, String jobId) async {
    if (!_favoritesPerUser.containsKey(userId)) {
      _favoritesPerUser[userId] = {};
    }
    final userFavs = _favoritesPerUser[userId]!;
    if (userFavs.contains(jobId)) {
      userFavs.remove(jobId);
    } else {
      userFavs.add(jobId);
    }
    _notifyFavorites(userId);
  }
}
