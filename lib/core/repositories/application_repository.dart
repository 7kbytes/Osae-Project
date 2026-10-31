import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/job_application_model.dart';
import '../services/local_storage_service.dart';

abstract class ApplicationRepository {
  Stream<List<JobApplication>> getSeekerApplications(String seekerId);
  Stream<List<JobApplication>> getPosterApplications(String posterId);
  Future<void> submitApplication(JobApplication application);
  Future<void> updateStatus(String applicationId, ApplicationStatus status);

  /// Accepts atomically: the application (sharing [posterPhone] with the
  /// seeker) and the job change together or not at all.
  Future<void> acceptApplication(
    String applicationId,
    String jobId,
    String posterPhone,
  );
}

class FirestoreApplicationRepository implements ApplicationRepository {
  final FirebaseFirestore _firestore;

  FirestoreApplicationRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _applicationsCollection =>
      _firestore.collection('applications');

  @override
  Stream<List<JobApplication>> getSeekerApplications(String seekerId) {
    return _applicationsCollection
        .where('seekerId', isEqualTo: seekerId)
        .orderBy('appliedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => JobApplication.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  @override
  Stream<List<JobApplication>> getPosterApplications(String posterId) {
    return _applicationsCollection
        .where('posterId', isEqualTo: posterId)
        .orderBy('appliedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => JobApplication.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  @override
  Future<void> submitApplication(JobApplication application) async {
    await _applicationsCollection.doc(application.id).set(application.toMap());
  }

  @override
  Future<void> updateStatus(
    String applicationId,
    ApplicationStatus status,
  ) async {
    await _applicationsCollection.doc(applicationId).update({
      'status': status.name,
    });
  }

  @override
  Future<void> acceptApplication(
    String applicationId,
    String jobId,
    String posterPhone,
  ) async {
    final batch = _firestore.batch();
    batch.update(_applicationsCollection.doc(applicationId), {
      'status': ApplicationStatus.accepted.name,
      'posterPhone': posterPhone,
    });
    batch.update(_firestore.collection('jobs').doc(jobId), {
      'status': 'inProgress',
      'isFilled': true,
      'posterPhone': FieldValue.delete(),
    });
    await batch.commit();
  }
}

class InMemoryApplicationRepository implements ApplicationRepository {
  final List<JobApplication> _applications = [];
  final LocalStorageService _localStorageService;
  final StreamController<List<JobApplication>> _controller =
      StreamController<List<JobApplication>>.broadcast();

  InMemoryApplicationRepository({
    LocalStorageService? localStorageService,
    List<JobApplication>? initialApplications,
  }) : _localStorageService =
           localStorageService ?? LocalStorageService.instance {
    if (initialApplications != null) {
      _applications.addAll(initialApplications);
    } else {
      final cached = _localStorageService.getApplications();
      if (cached.isNotEmpty) {
        _applications.addAll(cached);
      }
    }
  }

  void _notify() {
    _localStorageService.saveApplications(_applications);
    if (!_controller.isClosed) {
      _controller.add(List.unmodifiable(_applications));
    }
  }

  @override
  Stream<List<JobApplication>> getSeekerApplications(String seekerId) {
    Timer.run(_notify);
    return _controller.stream.map((list) {
      return list.where((app) => app.seekerId == seekerId).toList();
    });
  }

  @override
  Stream<List<JobApplication>> getPosterApplications(String posterId) {
    Timer.run(_notify);
    return _controller.stream.map((list) {
      return list.where((app) => app.posterId == posterId).toList();
    });
  }

  @override
  Future<void> submitApplication(JobApplication application) async {
    _applications.insert(0, application);
    _notify();
  }

  @override
  Future<void> updateStatus(
    String applicationId,
    ApplicationStatus status,
  ) async {
    final index = _applications.indexWhere((app) => app.id == applicationId);
    if (index != -1) {
      _applications[index] = _applications[index].copyWith(status: status);
      _notify();
    }
  }

  @override
  Future<void> acceptApplication(
    String applicationId,
    String jobId,
    String posterPhone,
  ) async {
    final index = _applications.indexWhere((app) => app.id == applicationId);
    if (index != -1) {
      _applications[index] = _applications[index].copyWith(
        status: ApplicationStatus.accepted,
        posterPhone: posterPhone,
      );
      _notify();
    }
  }
}
