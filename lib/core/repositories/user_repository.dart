import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/mock_data.dart';

abstract class UserRepository {
  /// Returns null only when no profile exists; backend failures throw so they
  /// are never mistaken for a new user.
  Future<AppUser?> getUser(String userId);
  Future<void> saveUser(AppUser user);
  Future<void> updateUserRole(String userId, UserRole role);

  /// Writes only the user-editable fields, so rules can keep `rating` and
  /// `createdAt` out of the owner's reach.
  Future<void> updateProfile(
    String userId, {
    required String displayName,
    required String phone,
    required String city,
  });
  Future<void> deleteUser(String userId);
}

class FirestoreUserRepository implements UserRepository {
  final FirebaseFirestore _firestore;

  FirestoreUserRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  @override
  Future<AppUser?> getUser(String userId) async {
    final doc = await _usersCollection.doc(userId).get();
    if (!doc.exists || doc.data() == null) return null;
    return AppUser.fromMap(doc.data()!, doc.id);
  }

  @override
  Future<void> saveUser(AppUser user) async {
    await _usersCollection
        .doc(user.id)
        .set(user.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> deleteUser(String userId) async {
    await _usersCollection.doc(userId).delete();
  }

  @override
  Future<void> updateUserRole(String userId, UserRole role) async {
    await _usersCollection.doc(userId).update({'role': role.name});
  }

  @override
  Future<void> updateProfile(
    String userId, {
    required String displayName,
    required String phone,
    required String city,
  }) async {
    await _usersCollection.doc(userId).update({
      'displayName': displayName,
      'phone': phone,
      'city': city,
    });
  }
}

class InMemoryUserRepository implements UserRepository {
  final Map<String, AppUser> _users = {};

  InMemoryUserRepository() {
    _users[MockData.currentSeekerUser.id] = MockData.currentSeekerUser;
    _users[MockData.currentPosterUser.id] = MockData.currentPosterUser;
  }

  @override
  Future<AppUser?> getUser(String userId) async {
    return _users[userId];
  }

  @override
  Future<void> saveUser(AppUser user) async {
    _users[user.id] = user;
  }

  @override
  Future<void> deleteUser(String userId) async {
    _users.remove(userId);
  }

  @override
  Future<void> updateProfile(
    String userId, {
    required String displayName,
    required String phone,
    required String city,
  }) async {
    final existing = _users[userId];
    if (existing == null) throw StateError('No profile for $userId');
    _users[userId] = existing.copyWith(
      displayName: displayName,
      phone: phone,
      city: city,
    );
  }

  @override
  Future<void> updateUserRole(String userId, UserRole role) async {
    final existing = _users[userId];
    if (existing != null) {
      _users[userId] = existing.copyWith(role: role);
    } else {
      _users[userId] = AppUser(
        id: userId,
        displayName: 'User',
        phone: '+233 24 123 4567',
        role: role,
        city: 'Accra',
        createdAt: DateTime.now(),
      );
    }
  }
}
