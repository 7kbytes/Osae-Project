import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/job_application_model.dart';
import '../repositories/application_repository.dart';
import '../services/firebase_service.dart';
import '../services/local_storage_service.dart';

class ApplicationProvider with ChangeNotifier {
  final ApplicationRepository _applicationRepository;
  final LocalStorageService _localStorageService;

  List<JobApplication> _applications = [];
  String? _currentSeekerId;
  bool _isLoading = false;
  String? _errorMessage;
  String? _boundUserId;
  StreamSubscription<List<JobApplication>>? _seekerSub;
  StreamSubscription<List<JobApplication>>? _posterSub;
  List<JobApplication> _asSeeker = [];
  List<JobApplication> _asPoster = [];
  bool _seekerLoaded = false;
  bool _posterLoaded = false;
  String? _loadError;

  ApplicationProvider({
    ApplicationRepository? applicationRepository,
    LocalStorageService? localStorageService,
    String? initialSeekerId,
  }) : _applicationRepository =
           applicationRepository ??
           (FirebaseService.isInitialized
               ? FirestoreApplicationRepository()
               : InMemoryApplicationRepository()),
       _localStorageService =
           localStorageService ?? LocalStorageService.instance,
       _currentSeekerId = initialSeekerId {
    _initData();
  }

  void _initData() {
    final cached = _localStorageService.getApplications();
    if (cached.isNotEmpty) {
      _applications = List.from(cached);
    }
  }

  // ---------------------------------------------------------------------------
  // Live sync
  // ---------------------------------------------------------------------------

  /// Binds the provider to the signed-in user: loads and live-updates every
  /// application they sent (as seeker) or received (as poster).
  void bindUser(String userId) {
    if (userId == _boundUserId) return;
    _boundUserId = userId;
    _asSeeker = [];
    _asPoster = [];
    _applications = [];
    _currentSeekerId = userId.isEmpty ? null : userId;
    _errorMessage = null;
    _subscribe();
    notifyListeners();
  }

  void _subscribe() {
    _seekerSub?.cancel();
    _posterSub?.cancel();
    _seekerSub = null;
    _posterSub = null;
    _loadError = null;
    final userId = _boundUserId ?? '';
    _seekerLoaded = userId.isEmpty;
    _posterLoaded = userId.isEmpty;
    _isLoading = userId.isNotEmpty;
    if (userId.isEmpty) return;

    _seekerSub = _applicationRepository.getSeekerApplications(userId).listen((
      list,
    ) {
      _asSeeker = list;
      _seekerLoaded = true;
      _mergeStreams();
    }, onError: _onStreamError);
    _posterSub = _applicationRepository.getPosterApplications(userId).listen((
      list,
    ) {
      _asPoster = list;
      _posterLoaded = true;
      _mergeStreams();
    }, onError: _onStreamError);
  }

  /// Re-subscribes to the signed-in user's applications after a failure.
  void retryLoad() {
    _subscribe();
    notifyListeners();
  }

  void _mergeStreams() {
    _isLoading = !(_seekerLoaded && _posterLoaded);
    _loadError = null;
    final byId = <String, JobApplication>{
      for (final a in _asPoster) a.id: a,
      for (final a in _asSeeker) a.id: a,
    };
    _applications = byId.values.toList()
      ..sort((a, b) => b.appliedAt.compareTo(a.appliedAt));
    _localStorageService.saveApplications(_applications);
    notifyListeners();
  }

  void _onStreamError(Object e) {
    debugPrint('ApplicationProvider stream error: $e');
    _isLoading = false;
    _loadError = 'Could not load applications. Check your connection.';
    notifyListeners();
  }

  @override
  void dispose() {
    _seekerSub?.cancel();
    _posterSub?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  List<JobApplication> get applications => List.unmodifiable(_applications);

  List<JobApplication> get myApplications {
    if (_currentSeekerId != null && _currentSeekerId!.isNotEmpty) {
      return _applications
          .where((app) => app.seekerId == _currentSeekerId)
          .toList();
    }
    return List.unmodifiable(_applications);
  }

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Set when the live application lists could not be loaded.
  String? get loadError => _loadError;
  String? get currentSeekerId => _currentSeekerId;

  // ---------------------------------------------------------------------------
  // Lookups & Filters
  // ---------------------------------------------------------------------------

  List<JobApplication> getApplicationsForJob(String jobId) {
    return _applications.where((app) => app.jobId == jobId).toList();
  }

  List<JobApplication> getApplicationsForSeeker(String seekerId) {
    return _applications.where((app) => app.seekerId == seekerId).toList();
  }

  bool hasApplied(String jobId, String seekerId) {
    return _applications.any(
      (app) => app.jobId == jobId && app.seekerId == seekerId,
    );
  }

  JobApplication? getApplication(String jobId, String seekerId) {
    final index = _applications.indexWhere(
      (app) => app.jobId == jobId && app.seekerId == seekerId,
    );
    if (index != -1) {
      return _applications[index];
    }
    return null;
  }

  void setCurrentSeekerId(String seekerId) {
    _currentSeekerId = seekerId;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------

  Future<void> loadApplications() async {
    _isLoading = true;
    notifyListeners();

    try {
      final cached = _localStorageService.getApplications();
      if (cached.isNotEmpty) {
        _applications = List.from(cached);
      }
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> submitApplication({
    required String jobId,
    required String jobTitle,
    required String employerId,
    required String applicantId,
    required String applicantName,
    required String applicantPhone,
    required String coverNote,
    String? applicationId,
    DateTime? appliedAt,
  }) async {
    if (hasApplied(jobId, applicantId)) {
      return false;
    }

    _currentSeekerId ??= applicantId;

    final application = JobApplication(
      // Fixed id: the rules use it to allow one application per job.
      id: applicationId ?? '${jobId}_$applicantId',
      jobId: jobId,
      jobTitle: jobTitle,
      seekerId: applicantId,
      seekerName: applicantName,
      seekerPhone: applicantPhone,
      posterId: employerId,
      status: ApplicationStatus.pending,
      note: coverNote,
      appliedAt: appliedAt ?? DateTime.now(),
    );

    _applications.insert(0, application);
    await _localStorageService.saveApplications(_applications);
    notifyListeners();

    try {
      await _applicationRepository.submitApplication(application);
    } catch (e) {
      debugPrint('ApplicationProvider.submitApplication repository error: $e');
      _applications.removeWhere((a) => a.id == application.id);
      await _localStorageService.saveApplications(_applications);
      _errorMessage = 'Could not submit the application. Please try again.';
      notifyListeners();
      return false;
    }

    return true;
  }

  Future<bool> updateApplicationStatus(
    String applicationId,
    ApplicationStatus status,
  ) => _applyUpdate(
    applicationId,
    (app) => app.copyWith(status: status),
    () => _applicationRepository.updateStatus(applicationId, status),
  );

  /// Accepts an application, sharing [posterPhone] with that seeker only.
  Future<bool> acceptApplication(String applicationId, String posterPhone) {
    final index = _applications.indexWhere((app) => app.id == applicationId);
    if (index == -1) return Future.value(false);
    final jobId = _applications[index].jobId;
    return _applyUpdate(
      applicationId,
      (app) => app.copyWith(
        status: ApplicationStatus.accepted,
        posterPhone: posterPhone,
      ),
      () => _applicationRepository.acceptApplication(
        applicationId,
        jobId,
        posterPhone,
      ),
    );
  }

  Future<bool> _applyUpdate(
    String applicationId,
    JobApplication Function(JobApplication) change,
    Future<void> Function() write,
  ) async {
    final index = _applications.indexWhere((app) => app.id == applicationId);
    if (index == -1) return false;

    final previous = _applications[index];
    _applications[index] = change(previous);
    await _localStorageService.saveApplications(_applications);
    notifyListeners();

    try {
      await write();
    } catch (e) {
      debugPrint('ApplicationProvider update error: $e');
      // Looked up again: the live stream may have replaced the list meanwhile.
      final current = _applications.indexWhere((a) => a.id == applicationId);
      if (current != -1) _applications[current] = previous;
      await _localStorageService.saveApplications(_applications);
      _errorMessage = 'Could not update the application.';
      notifyListeners();
      return false;
    }

    return true;
  }
}
