import 'package:cloud_firestore/cloud_firestore.dart';

/// Resilient DateTime parsing helper for Firestore Timestamp, ISO8601 String,
/// int milliseconds, and native DateTime objects.
DateTime parseDateTime(dynamic value) {
  if (value == null) {
    return DateTime.now();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }
  try {
    // Dynamic fallback for any custom timestamp-like object with toDate()
    final dynamic dyn = value;
    if (dyn.toDate is Function) {
      return dyn.toDate() as DateTime;
    }
  } catch (_) {}

  return DateTime.now();
}
