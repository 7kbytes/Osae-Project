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

    _subscribe();
  }

  /// Bumped per subscription so a late reply from a previous query (e.g. the
  /// city filter changed while it was in flight) cannot overwrite the feed.
  int _queryGeneration = 0;

  void _subscribe() {
    // Subscribe to repository stream for live updates
    _jobsSubscription?.cancel();
    final generation = ++_queryGeneration;
    // City and category are filtered by the backend so the feed pages through
    // every matching job, not just the ones already loaded. Search stays
    // client-side: Firestore has no substring matching (see docs/02).
    _jobsSubscription = _jobRepository
        .getJobsStream(
          city: _selectedCity,
          category: _selectedCategory,
          search: _searchQuery,
          limit: _limit,
        )
        .listen(
          (updatedJobs) {
            if (generation != _queryGeneration) return;
            _isLoading = false;
            _isLoadingMore = false;
            _loadError = null;
            _lastPageCount = updatedJobs.length;
            // Against Firestore an empty list is real (e.g. the last job was deleted).
            if (updatedJobs.isNotEmpty || FirebaseService.isInitialized) {
              _jobs = List.from(updatedJobs);
              // Only cache an unfiltered page: caching a filtered result would
              // leave the offline feed holding one city or category.
              if (_selectedCity == 'All' && _selectedCategory == 'All') {
                _localStorageService.saveJobs(_jobs);
              }
              notifyListeners();
            } else {
              notifyListeners();
            }
          },
          onError: (Object e) {
            if (generation != _queryGeneration) return;
            debugPrint('Job stream error: $e');
            _isLoading = false;
            _isLoadingMore = false;
            _loadError = 'Could not load jobs. Check your connection.';
            notifyListeners();
          },
        );
  }

  // ---------------------------------------------------------------------------
  // Pagination
  // ---------------------------------------------------------------------------

  /// Jobs fetched per page of the live feed.
  static const int pageSize = 20;
  int _limit = pageSize;
  int _lastPageCount = 0;
  bool _isLoadingMore = false;

  /// Jobs outside the loaded pages, fetched individually (e.g. opened from an
  /// application or a favourite), so lookups never depend on scroll depth.
  final Map<String, JobPost> _extraJobs = {};
  final Set<String> _missingJobIds = {};

  /// True when the backend may have more jobs than the pages loaded so far.
  bool get hasMore => _lastPageCount >= _limit;
  bool get isLoadingMore => _isLoadingMore;

  /// Extends the live feed by one page.
  void loadMore() {
    if (!hasMore || _isLoadingMore) return;
    _isLoadingMore = true;
    _limit += pageSize;
    notifyListeners();
    _subscribe();
  }

  /// Returns the job with [jobId], fetching it by id when it is not in the
  /// loaded pages. Returns null if it does not exist or cannot be fetched.
  Future<JobPost?> ensureJob(String jobId) async {
    final known = _findJob(jobId);
    if (known != null) return known;
    if (_missingJobIds.contains(jobId)) return null;
    // Block body on purpose: an arrow would return the removed future itself,
    // and whenComplete would then wait on its own result forever.
    return _pendingFetches[jobId] ??= _fetchJob(jobId).whenComplete(() {
      _pendingFetches.remove(jobId);
    });
  }

  final Map<String, Future<JobPost?>> _pendingFetches = {};

  Future<JobPost?> _fetchJob(String jobId) async {
    try {
      final job = await _jobRepository.getJobById(jobId);
      if (job == null) {
        _missingJobIds.add(jobId);
      } else {
        _extraJobs[jobId] = job;
      }
      notifyListeners();
      return job;
    } catch (e) {
      debugPrint('ensureJob($jobId) failed: $e');
      _missingJobIds.add(jobId);
      notifyListeners();
      return null;
    }
  }

  JobPost? _findJob(String jobId) =>
      _jobs.where((j) => j.id == jobId).firstOrNull ?? _extraJobs[jobId];

  /// Replaces a job wherever it is held (loaded page or individually fetched).
  void _putJob(JobPost job) {
    final index = _jobs.indexWhere((j) => j.id == job.id);
    if (index != -1) {
      _jobs[index] = job;
    } else {
      _extraJobs[job.id] = job;
    }
  }

  // Getters
  List<JobPost> get allJobs => List.unmodifiable([
    ..._jobs,
    ..._extraJobs.values.where((e) => !_jobs.any((j) => j.id == e.id)),
  ]);
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
    final result = <JobPost>[];
    for (final id in _favoriteJobIds) {
      final job = _findJob(id);
      if (job != null) {
        result.add(job);
      } else if (!_missingJobIds.contains(id)) {
        // Saved job outside the loaded pages: fetch it once.
        Future.microtask(() => ensureJob(id));
      }
    }
    return result;
  }

  bool isFavorite(String jobId) => _favoriteJobIds.contains(jobId);

  // Actions
  void setRole(UserRole role) {
    _currentUserRole = role;
    notifyListeners();
  }

  void setCityFilter(String city) {
    if (city == _selectedCity) return;
    _selectedCity = city;
    _restartPaging();
  }

  void setCategoryFilter(String category) {
    if (category == _selectedCategory) return;
    _selectedCategory = category;
    _restartPaging();
  }

  /// A new filter is a new query: go back to the first page and re-subscribe.
  void _restartPaging() {
    _searchDebounce?.cancel();
    _limit = pageSize;
    _lastPageCount = 0;
    _isLoadingMore = false;
    _isLoading = FirebaseService.isInitialized;
    notifyListeners();
    _subscribe();
  }

  /// Filters the loaded jobs at once, then (after a pause in typing) runs the
  /// search as a backend query so results are not limited to loaded pages.
  void setSearchQuery(String query) {
    if (query == _searchQuery) return;
    _searchQuery = query;
    notifyListeners();

    _searchDebounce?.cancel();
    _searchDebounce = Timer(searchDebounce, _restartPaging);
  }

  /// How long typing must pause before the search is sent to the backend.
  static const Duration searchDebounce = Duration(milliseconds: 350);
  Timer? _searchDebounce;

  String? _lastError;
  bool _isLoading = FirebaseService.isInitialized;
  String? _loadError;

  /// True until the first list arrives from the backend.
  bool get isLoading => _isLoading;

  /// Set when the live job list could not be loaded.
  String? get loadError => _loadError;

  /// Re-subscribes to the live job list after a failure.
  void retryLoad() {
    _loadError = null;
    _isLoading = FirebaseService.isInitialized;
    notifyListeners();
    _subscribe();
  }

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
    final removedJob = _findJob(jobId);
    final removedExtra = _extraJobs.remove(jobId);
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
        if (removedExtra != null) {
          _extraJobs[jobId] = removedExtra;
        } else {
          _jobs.insert(0, removedJob);
        }
        await _localStorageService.saveJobs(_jobs);
        _lastError = 'Could not delete the job.';
        notifyListeners();
      }
    }
  }

  Future<void> updateJob(JobPost job) async {
    final previous = _findJob(job.id);
    if (previous != null) {
      _putJob(job);
      await _localStorageService.saveJobs(_jobs);
      notifyListeners();

      try {
        await _jobRepository.updateJob(job);
      } catch (e) {
        debugPrint('updateJob failed: $e');
        _putJob(previous);
        await _localStorageService.saveJobs(_jobs);
        _lastError = 'Could not update the job.';
        notifyListeners();
      }
    }
  }

  Future<void> updateJobStatus(String jobId, JobStatus status) async {
    final previous = _findJob(jobId);
    if (previous != null) {
      final updated = previous.copyWith(
        status: status,
        isFilled: status != JobStatus.open,
      );
      _putJob(updated);
      await _localStorageService.saveJobs(_jobs);
      notifyListeners();

      try {
        await _jobRepository.updateJob(updated);
      } catch (e) {
        debugPrint('updateJobStatus failed: $e');
        _putJob(previous);
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
    _searchDebounce?.cancel();
    _jobsSubscription?.cancel();
    super.dispose();
  }
}
