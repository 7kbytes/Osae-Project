import 'timestamp_helper.dart';

enum ReportTarget { job, user, message }

enum ReportStatus { open, resolved, dismissed }

/// A user's report of a job, user or message for admin review.
class Report {
  final String id;
  final ReportTarget targetType;
  final String targetId;
  final String targetTitle;
  final String reporterId;
  final String reason;
  final String note;
  final ReportStatus status;
  final DateTime createdAt;

  const Report({
    required this.id,
    required this.targetType,
    required this.targetId,
    this.targetTitle = '',
    required this.reporterId,
    required this.reason,
    this.note = '',
    this.status = ReportStatus.open,
    required this.createdAt,
  });

  /// Reasons offered to the reporter.
  static const List<String> reasons = [
    'Scam or upfront fee',
    'Fake or misleading job',
    'Inappropriate content',
    'Harassment or unsafe',
    'Other',
  ];

  Map<String, dynamic> toMap() => {
    'id': id,
    'targetType': targetType.name,
    'targetId': targetId,
    'targetTitle': targetTitle,
    'reporterId': reporterId,
    'reason': reason,
    'note': note,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Report.fromMap(Map<String, dynamic> map, String docId) {
    return Report(
      id: docId,
      targetType: ReportTarget.values.firstWhere(
        (t) => t.name == map['targetType'],
        orElse: () => ReportTarget.job,
      ),
      targetId: map['targetId'] ?? '',
      targetTitle: map['targetTitle'] ?? '',
      reporterId: map['reporterId'] ?? '',
      reason: map['reason'] ?? '',
      note: map['note'] ?? '',
      status: ReportStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => ReportStatus.open,
      ),
      createdAt: parseDateTime(map['createdAt']),
    );
  }
}
