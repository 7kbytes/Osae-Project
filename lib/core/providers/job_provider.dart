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
  })  : _jobRepository = jobRepository ??
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
    } else {
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
      if (updatedJobs.isNotEmpty) {
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
      final matchesSearch = _searchQuery.isEmpty ||
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

  Future<void> toggleFavorite(String jobId, {String userId = 'usr_default_01'}) async {
    if (_favoriteJobIds.contains(jobId)) {
      _favoriteJobIds.remove(jobId);
    } else {
      _favoriteJobIds.add(jobId);
    }
    await _localStorageService.saveFavorites(_favoriteJobIds);
    notifyListeners();

    try {
      await _jobRepository.toggleFavorite(userId, jobId);
    } catch (_) {}
  }

  Future<void> addJob(JobPost job) async {
    _jobs.insert(0, job);
    await _localStorageService.saveJobs(_jobs);
    notifyListeners();

    try {
      await _jobRepository.addJob(job);
    } catch (_) {}
  }

  Future<void> deleteJob(String jobId) async {
    _jobs.removeWhere((j) => j.id == jobId);
    _favoriteJobIds.remove(jobId);
    await _localStorageService.saveJobs(_jobs);
    await _localStorageService.saveFavorites(_favoriteJobIds);
    notifyListeners();

    try {
      await _jobRepository.deleteJob(jobId);
    } catch (_) {}
  }

  Future<void> updateJob(JobPost job) async {
    final index = _jobs.indexWhere((j) => j.id == job.id);
    if (index != -1) {
      _jobs[index] = job;
      await _localStorageService.saveJobs(_jobs);
      notifyListeners();

      try {
        await _jobRepository.updateJob(job);
      } catch (_) {}
    }
  }

  Future<void> updateJobStatus(String jobId, JobStatus status) async {
    final index = _jobs.indexWhere((j) => j.id == jobId);
    if (index != -1) {
      _jobs[index] = _jobs[index].copyWith(
        status: status,
        isFilled: status != JobStatus.open,
      );
      await _localStorageService.saveJobs(_jobs);
      notifyListeners();

      try {
        await _jobRepository.updateJob(_jobs[index]);
      } catch (_) {}
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
