import 'timestamp_helper.dart';

enum ApplicationStatus { pending, accepted, rejected, completed }

class JobApplication {
  final String id;
  final String jobId;
  final String jobTitle;
  final String seekerId;
  final String seekerName;
  final String seekerPhone;
  final String posterId;

  /// The poster's phone, shared with the seeker only on acceptance.
  final String posterPhone;
  final ApplicationStatus status;
  final String note;
  final DateTime appliedAt;

  const JobApplication({
    required this.id,
    required this.jobId,
    required this.jobTitle,
    required this.seekerId,
    required this.seekerName,
    required this.seekerPhone,
    required this.posterId,
    this.posterPhone = '',
    this.status = ApplicationStatus.pending,
    this.note = '',
    required this.appliedAt,
  });

  JobApplication copyWith({
    String? id,
    String? jobId,
    String? jobTitle,
    String? seekerId,
    String? seekerName,
    String? seekerPhone,
    String? posterId,
    String? posterPhone,
    ApplicationStatus? status,
    String? note,
    DateTime? appliedAt,
  }) {
    return JobApplication(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      jobTitle: jobTitle ?? this.jobTitle,
      seekerId: seekerId ?? this.seekerId,
      seekerName: seekerName ?? this.seekerName,
      seekerPhone: seekerPhone ?? this.seekerPhone,
      posterId: posterId ?? this.posterId,
      posterPhone: posterPhone ?? this.posterPhone,
      status: status ?? this.status,
      note: note ?? this.note,
      appliedAt: appliedAt ?? this.appliedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'jobId': jobId,
      'jobTitle': jobTitle,
      'seekerId': seekerId,
      'seekerName': seekerName,
      'seekerPhone': seekerPhone,
      'posterId': posterId,
      if (posterPhone.isNotEmpty) 'posterPhone': posterPhone,
      'status': status.name,
      'note': note,
      'appliedAt': appliedAt.toIso8601String(),
    };
  }

  factory JobApplication.fromMap(Map<String, dynamic> map, String docId) {
    return JobApplication(
      id: docId,
      jobId: map['jobId'] ?? '',
      jobTitle: map['jobTitle'] ?? '',
      seekerId: map['seekerId'] ?? '',
      seekerName: map['seekerName'] ?? '',
      seekerPhone: map['seekerPhone'] ?? '',
      posterId: map['posterId'] ?? '',
      posterPhone: map['posterPhone'] ?? '',
      status: ApplicationStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => ApplicationStatus.pending,
      ),
      note: map['note'] ?? '',
      appliedAt: parseDateTime(map['appliedAt']),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JobApplication &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          jobId == other.jobId &&
          seekerId == other.seekerId;

  @override
  int get hashCode => id.hashCode ^ jobId.hashCode ^ seekerId.hashCode;

  @override
  String toString() =>
      'JobApplication(id: $id, job: $jobTitle, seeker: $seekerName, status: ${status.name})';
}
