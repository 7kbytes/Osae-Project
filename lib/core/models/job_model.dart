import 'timestamp_helper.dart';

enum JobStatus {
  open,
  inProgress,
  completed;

  String get label {
    switch (this) {
      case JobStatus.open:
        return 'Active / Open';
      case JobStatus.inProgress:
        return 'In Progress';
      case JobStatus.completed:
        return 'Completed';
    }
  }

  static JobStatus fromString(dynamic value) {
    if (value == null) return JobStatus.open;
    final s = value.toString().trim().toLowerCase().replaceAll('_', '');
    if (s == 'inprogress') return JobStatus.inProgress;
    if (s == 'completed') return JobStatus.completed;
    return JobStatus.open;
  }
}

class JobPost {
  final String id;
  final String title;
  final String description;
  final String category;
  final double payRate;
  final String payUnit; // e.g., 'per day', 'per hour', 'fixed'
  final String currency;
  final String city; // Accra, Kumasi, Tema
  final String locationName;
  final double latitude;
  final double longitude;
  final String posterId;
  final String posterName;
  final String posterPhone;
  final JobStatus status;
  final bool isFilled;
  final bool isFavorite;
  final DateTime createdAt;

  const JobPost({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.payRate,
    this.payUnit = 'per day',
    this.currency = 'GHS',
    required this.city,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.posterId,
    required this.posterName,
    required this.posterPhone,
    this.status = JobStatus.open,
    this.isFilled = false,
    this.isFavorite = false,
    required this.createdAt,
  });

  JobPost copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    double? payRate,
    String? payUnit,
    String? currency,
    String? city,
    String? locationName,
    double? latitude,
    double? longitude,
    String? posterId,
    String? posterName,
    String? posterPhone,
    JobStatus? status,
    bool? isFilled,
    bool? isFavorite,
    DateTime? createdAt,
  }) {
    final effectiveStatus =
        status ??
        (isFilled != null
            ? (isFilled ? JobStatus.completed : JobStatus.open)
            : this.status);
    final effectiveIsFilled =
        isFilled ??
        (status != null ? (status != JobStatus.open) : this.isFilled);

    return JobPost(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      payRate: payRate ?? this.payRate,
      payUnit: payUnit ?? this.payUnit,
      currency: currency ?? this.currency,
      city: city ?? this.city,
      locationName: locationName ?? this.locationName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      posterId: posterId ?? this.posterId,
      posterName: posterName ?? this.posterName,
      posterPhone: posterPhone ?? this.posterPhone,
      status: effectiveStatus,
      isFilled: effectiveIsFilled,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'payRate': payRate,
      'payUnit': payUnit,
      'currency': currency,
      'city': city,
      'locationName': locationName,
      'latitude': latitude,
      'longitude': longitude,
      'posterId': posterId,
      'posterName': posterName,
      'posterPhone': posterPhone,
      'status': status.name,
      'isFilled': isFilled || status != JobStatus.open,
      'createdAt': createdAt.toIso8601String(),
      'searchTerms': searchTerms,
    };
  }

  /// Word prefixes from the fields people search on, stored on the document so
  /// Firestore can match a partly typed word with `array-contains`. Prefixes,
  /// not whole words, so "clean" finds "Cleaning" while the user is still
  /// typing. Firestore has no substring search, so a query that starts
  /// mid-word ("leaning") is not matched by the backend; the loaded pages are
  /// still filtered by substring on top of this (see docs/02).
  List<String> get searchTerms =>
      buildSearchTerms([title, locationName, category, city]);

  /// Longest prefix stored (and matched), to bound document size.
  static const int maxTermLength = 12;
  static const int _minTermLength = 3;
  static const int _maxTerms = 60;

  static List<String> buildSearchTerms(List<String> sources) {
    final terms = <String>{};
    for (final source in sources) {
      for (final word in source.toLowerCase().split(RegExp(r'[^a-z0-9]+'))) {
        if (word.isEmpty) continue;
        if (word.length < _minTermLength) {
          terms.add(word);
          continue;
        }
        final longest = word.length < maxTermLength
            ? word.length
            : maxTermLength;
        for (var end = _minTermLength; end <= longest; end++) {
          terms.add(word.substring(0, end));
        }
      }
    }
    return terms.take(_maxTerms).toList();
  }

  /// The term a search box query is matched against, or null when the query
  /// is too short to query on (the backend query then stays unfiltered and
  /// the loaded pages are filtered client-side).
  static String? searchTermFor(String query) {
    final words = query
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((w) => w.length >= _minTermLength)
        .toList();
    if (words.isEmpty) return null;
    // Longest word is the most selective, so the backend returns the least.
    words.sort((a, b) => b.length.compareTo(a.length));
    final word = words.first;
    return word.length <= maxTermLength
        ? word
        : word.substring(0, maxTermLength);
  }

  factory JobPost.fromMap(Map<String, dynamic> map, String docId) {
    JobStatus parsedStatus;
    if (map['status'] != null) {
      parsedStatus = JobStatus.fromString(map['status']);
    } else {
      final isFilledVal = map['isFilled'] == true;
      parsedStatus = isFilledVal ? JobStatus.completed : JobStatus.open;
    }
    final parsedIsFilled = map['isFilled'] ?? (parsedStatus != JobStatus.open);

    return JobPost(
      id: docId,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? 'Other',
      payRate: (map['payRate'] as num?)?.toDouble() ?? 0.0,
      payUnit: map['payUnit'] ?? 'per day',
      currency: map['currency'] ?? 'GHS',
      city: map['city'] ?? 'Accra',
      locationName: map['locationName'] ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 5.5586,
      longitude: (map['longitude'] as num?)?.toDouble() ?? -0.2014,
      posterId: map['posterId'] ?? '',
      posterName: map['posterName'] ?? 'Business Owner',
      posterPhone: map['posterPhone'] ?? '',
      status: parsedStatus,
      isFilled: parsedIsFilled,
      isFavorite: map['isFavorite'] ?? false,
      createdAt: parseDateTime(map['createdAt']),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JobPost &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          category == other.category &&
          city == other.city;

  @override
  int get hashCode =>
      id.hashCode ^ title.hashCode ^ category.hashCode ^ city.hashCode;

  @override
  String toString() =>
      'JobPost(id: $id, title: $title, city: $city, status: ${status.name}, pay: $currency $payRate/$payUnit)';
}
