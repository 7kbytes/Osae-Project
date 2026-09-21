import 'package:flutter_test/flutter_test.dart';
import 'package:local_job_connector/core/models/report_model.dart';
import 'package:local_job_connector/core/repositories/report_repository.dart';

void main() {
  test('Report serialises and deserialises', () {
    final report = Report(
      id: 'r1',
      targetType: ReportTarget.job,
      targetId: 'job1',
      targetTitle: 'Clean office',
      reporterId: 'u1',
      reason: Report.reasons.first,
      note: 'asked for money upfront',
      createdAt: DateTime.utc(2026, 9, 21, 10),
    );

    final copy = Report.fromMap(report.toMap(), 'r1');

    expect(copy.targetType, ReportTarget.job);
    expect(copy.targetId, 'job1');
    expect(copy.reason, Report.reasons.first);
    expect(copy.status, ReportStatus.open);
    expect(copy.createdAt, report.createdAt);
  });

  test('unknown values fall back to safe defaults', () {
    final r = Report.fromMap({'targetType': '???', 'status': '???'}, 'x');

    expect(r.targetType, ReportTarget.job);
    expect(r.status, ReportStatus.open);
  });

  test('reports always start open when built by the app', () {
    final r = Report(
      id: 'a',
      targetType: ReportTarget.user,
      targetId: 'u2',
      reporterId: 'u1',
      reason: 'Other',
      createdAt: DateTime.now(),
    );

    expect(r.status, ReportStatus.open);
  });

  test('in-memory repository stores submitted reports', () async {
    final repo = InMemoryReportRepository();
    await repo.submitReport(
      Report(
        id: 'a',
        targetType: ReportTarget.job,
        targetId: 'j',
        reporterId: 'u1',
        reason: 'Other',
        createdAt: DateTime.now(),
      ),
    );

    expect(repo.reports, hasLength(1));
  });
}
