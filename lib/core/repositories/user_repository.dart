import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/mock_data.dart';

abstract class UserRepository {
  Future<AppUser?> getUser(String userId);
  Future<void> saveUser(AppUser user);
  Future<void> updateUserRole(String userId, UserRole role);
}

class FirestoreUserRepository implements UserRepository {
  final FirebaseFirestore _firestore;

  FirestoreUserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  @override
  Future<AppUser?> getUser(String userId) async {
    try {
      final doc = await _usersCollection.doc(userId).get();
      if (!doc.exists || doc.data() == null) return null;
      return AppUser.fromMap(doc.data()!, doc.id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveUser(AppUser user) async {
    await _usersCollection.doc(user.id).set(
          user.toMap(),
          SetOptions(merge: true),
        );
  }

  @override
  Future<void> updateUserRole(String userId, UserRole role) async {
    await _usersCollection.doc(userId).update({
      'role': role.name,
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
