import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/report_model.dart';

abstract class ReportRepository {
  Future<void> submitReport(Report report);
}

class FirestoreReportRepository implements ReportRepository {
  final FirebaseFirestore _firestore;

  FirestoreReportRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> submitReport(Report report) async {
    await _firestore.collection('reports').doc(report.id).set(report.toMap());
  }
}

class InMemoryReportRepository implements ReportRepository {
  final List<Report> reports = [];

  @override
  Future<void> submitReport(Report report) async {
    reports.add(report);
  }
}
