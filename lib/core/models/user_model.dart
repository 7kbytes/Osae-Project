import 'timestamp_helper.dart';

enum UserRole { seeker, poster, admin }

class AppUser {
  final String id;
  final String displayName;
  final String phone;
  final UserRole role;
  final String city; // Accra, Kumasi, Tema, etc.
  final double rating;
  final String? avatarUrl;
  final DateTime createdAt;

  const AppUser({
    required this.id,
    required this.displayName,
    required this.phone,
    required this.role,
    required this.city,
    this.rating = 5.0,
    this.avatarUrl,
    required this.createdAt,
  });

  AppUser copyWith({
    String? id,
    String? displayName,
    String? phone,
    UserRole? role,
    String? city,
    double? rating,
    String? avatarUrl,
    DateTime? createdAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      city: city ?? this.city,
      rating: rating ?? this.rating,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'displayName': displayName,
      'phone': phone,
      'role': role.name,
      'city': city,
      'rating': rating,
      'avatarUrl': avatarUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map, String docId) {
    return AppUser(
      id: docId,
      displayName: map['displayName'] ?? 'User',
      phone: map['phone'] ?? '',
      role: UserRole.values.firstWhere(
        (r) => r.name == map['role'],
        orElse: () => UserRole.seeker,
      ),
      city: map['city'] ?? 'Accra',
      rating: (map['rating'] as num?)?.toDouble() ?? 5.0,
      avatarUrl: map['avatarUrl'] as String?,
      createdAt: parseDateTime(map['createdAt']),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          displayName == other.displayName &&
          phone == other.phone &&
          role == other.role &&
          city == other.city;

  @override
  int get hashCode =>
      id.hashCode ^
      displayName.hashCode ^
      phone.hashCode ^
      role.hashCode ^
      city.hashCode;

  @override
  String toString() =>
      'AppUser(id: $id, displayName: $displayName, phone: $phone, role: ${role.name}, city: $city)';
}
