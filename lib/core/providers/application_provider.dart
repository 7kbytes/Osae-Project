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

  ApplicationProvider({
    ApplicationRepository? applicationRepository,
    LocalStorageService? localStorageService,
    String? initialSeekerId,
  })  : _applicationRepository = applicationRepository ??
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
      id: applicationId ?? 'app_${DateTime.now().millisecondsSinceEpoch}',
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
    }

    return true;
  }

  Future<bool> updateApplicationStatus(
    String applicationId,
    ApplicationStatus status,
  ) async {
    final index = _applications.indexWhere((app) => app.id == applicationId);
    if (index == -1) return false;

    _applications[index] = _applications[index].copyWith(status: status);
    await _localStorageService.saveApplications(_applications);
    notifyListeners();

    try {
      await _applicationRepository.updateStatus(applicationId, status);
    } catch (e) {
      debugPrint('ApplicationProvider.updateApplicationStatus error: $e');
    }

    return true;
  }
}
