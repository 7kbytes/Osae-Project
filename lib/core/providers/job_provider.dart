import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/job_model.dart';
import '../models/user_model.dart';
import '../repositories/job_repository.dart';
import '../services/firebase_service.dart';
import '../services/local_storage_service.dart';
import '../services/mock_data.dart';

class JobProvider with ChangeNotifier {
  final JobRepository _jobRepository;
  final LocalStorageService _localStorageService;
  StreamSubscription<List<JobPost>>? _jobsSubscription;

  List<JobPost> _jobs = [];
  final Set<String> _favoriteJobIds = {};
  String _selectedCity = 'All';
  String _selectedCategory = 'All';
  String _searchQuery = '';
  UserRole _currentUserRole = UserRole.seeker;

  JobProvider({
    JobRepository? jobRepository,
    LocalStorageService? localStorageService,
  }) : _jobRepository =
           jobRepository ??
           (FirebaseService.isInitialized
               ? FirestoreJobRepository()
               : InMemoryJobRepository()),
       _localStorageService =
           localStorageService ?? LocalStorageService.instance {
    _initData();
  }

  void _initData() {
    // Initial local cache population
    final cachedJobs = _localStorageService.getJobs();
    if (cachedJobs.isNotEmpty) {
      _jobs = List.from(cachedJobs);
    } else if (!FirebaseService.isInitialized) {
      // Demo/test data only; never shown against a real backend.
      _jobs = List.from(MockData.initialJobs);
      _localStorageService.saveJobs(_jobs);
    }

    final cachedFavorites = _localStorageService.getFavorites();
    if (cachedFavorites.isNotEmpty) {
      _favoriteJobIds.addAll(cachedFavorites);
    }

    // Subscribe to repository stream for live updates
    _jobsSubscription?.cancel();
    _jobsSubscription = _jobRepository.getJobsStream().listen((updatedJobs) {
      // Against Firestore an empty list is real (e.g. the last job was deleted).
      if (updatedJobs.isNotEmpty || FirebaseService.isInitialized) {
        _jobs = List.from(updatedJobs);
        _localStorageService.saveJobs(_jobs);
        notifyListeners();
      }
    });
  }

  // Getters
  List<JobPost> get allJobs => List.unmodifiable(_jobs);
  UserRole get currentUserRole => _currentUserRole;
  String get selectedCity => _selectedCity;
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  Set<String> get favoriteJobIds => Set.unmodifiable(_favoriteJobIds);

  List<JobPost> get filteredJobs {
    return _jobs.where((job) {
      final matchesCity = _selectedCity == 'All' || job.city == _selectedCity;
      final matchesCategory =
          _selectedCategory == 'All' || job.category == _selectedCategory;
      final queryLower = _searchQuery.toLowerCase();
      final matchesSearch =
          _searchQuery.isEmpty ||
          job.title.toLowerCase().contains(queryLower) ||
          job.description.toLowerCase().contains(queryLower) ||
          job.locationName.toLowerCase().contains(queryLower);
      return matchesCity && matchesCategory && matchesSearch;
    }).toList();
  }

  List<JobPost> get favoriteJobs {
    return _jobs.where((job) => _favoriteJobIds.contains(job.id)).toList();
  }

  bool isFavorite(String jobId) => _favoriteJobIds.contains(jobId);

  // Actions
  void setRole(UserRole role) {
    _currentUserRole = role;
    notifyListeners();
  }

  void setCityFilter(String city) {
    _selectedCity = city;
    notifyListeners();
  }

  void setCategoryFilter(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  String? _lastError;

  /// Reason the last write to the backend failed, if any.
  String? get lastError => _lastError;

  Future<void> toggleFavorite(
    String jobId, {
    String userId = 'usr_default_01',
  }) async {
    if (_favoriteJobIds.contains(jobId)) {
      _favoriteJobIds.remove(jobId);
    } else {
      _favoriteJobIds.add(jobId);
    }
    await _localStorageService.saveFavorites(_favoriteJobIds);
    notifyListeners();

    if (userId.isEmpty) return;
    try {
      await _jobRepository.toggleFavorite(userId, jobId);
    } catch (e) {
      debugPrint('toggleFavorite failed: $e');
    }
  }

  /// Adds a job. Returns false (and rolls the local change back) if the
  /// backend rejected the write, so the UI never shows a job that isn't saved.
  Future<bool> addJob(JobPost job) async {
    _lastError = null;
    _jobs.insert(0, job);
    await _localStorageService.saveJobs(_jobs);
    notifyListeners();

    try {
      await _jobRepository.addJob(job);
      return true;
    } catch (e) {
      debugPrint('addJob failed: $e');
      _jobs.removeWhere((j) => j.id == job.id);
      await _localStorageService.saveJobs(_jobs);
      _lastError = 'Could not save the job. Please try again.';
      notifyListeners();
      return false;
    }
  }

  Future<void> deleteJob(String jobId) async {
    final removedJob = _jobs.where((j) => j.id == jobId).firstOrNull;
    _jobs.removeWhere((j) => j.id == jobId);
    _favoriteJobIds.remove(jobId);
    await _localStorageService.saveJobs(_jobs);
    await _localStorageService.saveFavorites(_favoriteJobIds);
    notifyListeners();

    try {
      await _jobRepository.deleteJob(jobId);
    } catch (e) {
      debugPrint('deleteJob failed: $e');
      if (removedJob != null) {
        _jobs.insert(0, removedJob);
        await _localStorageService.saveJobs(_jobs);
        _lastError = 'Could not delete the job.';
        notifyListeners();
      }
    }
  }

  Future<void> updateJob(JobPost job) async {
    final index = _jobs.indexWhere((j) => j.id == job.id);
    if (index != -1) {
      final previous = _jobs[index];
      _jobs[index] = job;
      await _localStorageService.saveJobs(_jobs);
      notifyListeners();

      try {
        await _jobRepository.updateJob(job);
      } catch (e) {
        debugPrint('updateJob failed: $e');
        _jobs[index] = previous;
        await _localStorageService.saveJobs(_jobs);
        _lastError = 'Could not update the job.';
        notifyListeners();
      }
    }
  }

  Future<void> updateJobStatus(String jobId, JobStatus status) async {
    final index = _jobs.indexWhere((j) => j.id == jobId);
    if (index != -1) {
      final previous = _jobs[index];
      _jobs[index] = previous.copyWith(
        status: status,
        isFilled: status != JobStatus.open,
      );
      await _localStorageService.saveJobs(_jobs);
      notifyListeners();

      try {
        await _jobRepository.updateJob(_jobs[index]);
      } catch (e) {
        debugPrint('updateJobStatus failed: $e');
        _jobs[index] = previous;
        await _localStorageService.saveJobs(_jobs);
        _lastError = 'Could not update the job.';
        notifyListeners();
      }
    }
  }

  Future<void> refresh() async {
    try {
      final remoteJobs = await _jobRepository.getJobs();
      if (remoteJobs.isNotEmpty) {
        _jobs = List.from(remoteJobs);
        await _localStorageService.saveJobs(_jobs);
        notifyListeners();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _jobsSubscription?.cancel();
    super.dispose();
  }
}
