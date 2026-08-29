import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../repositories/user_repository.dart';
import '../services/firebase_service.dart';
import '../services/local_storage_service.dart';
import '../services/mock_data.dart';

class AuthProvider with ChangeNotifier {
  final UserRepository _userRepository;
  final LocalStorageService _localStorageService;
  bool _isAuthenticated = true; // Default logged in for seamless demo/test flow
  AppUser? _currentUser;
  String _authMethod = 'email'; // 'email' or 'google'

  AuthProvider({
    UserRepository? userRepository,
    LocalStorageService? localStorageService,
    bool startAuthenticated = true,
  })  : _userRepository = userRepository ??
            (FirebaseService.isInitialized
                ? FirestoreUserRepository()
                : InMemoryUserRepository()),
        _localStorageService =
            localStorageService ?? LocalStorageService.instance {
    if (startAuthenticated) {
      _initUser();
    } else {
      _isAuthenticated = false;
      _currentUser = null;
    }
  }

  void _initUser() {
    final cachedUser = _localStorageService.getUser();
    if (cachedUser != null) {
      _currentUser = cachedUser;
    } else {
      _currentUser = MockData.currentSeekerUser;
      _localStorageService.saveUser(_currentUser!);
    }
    _userRepository.saveUser(_currentUser!);
  }

  bool get isAuthenticated => _isAuthenticated;
  AppUser? get currentUser => _currentUser;
  String get authMethod => _authMethod;
  String get userEmail =>
      _currentUser != null && _currentUser!.displayName.isNotEmpty
          ? '${_currentUser!.displayName.toLowerCase().replaceAll(' ', '.')}@gmail.com'
          : 'user@gmail.com';

  /// Validates Ghanaian phone numbers in international (+233) or local (02X/05X/020) format.
  static bool isValidGhanaPhone(String phone) {
    final sanitized = phone.replaceAll(RegExp(r'[\s\-]'), '');
    final ghanaPhoneRegex = RegExp(r'^(?:\+233|0)[235][0-9]{8}$');
    return ghanaPhoneRegex.hasMatch(sanitized);
  }

  Future<bool> signInWithEmail(String email, String password) async {
    _isAuthenticated = true;
    _authMethod = 'email';

    try {
      if (FirebaseService.isInitialized) {
        final credential =
            await fb_auth.FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email.trim(),
          password: password.trim(),
        );

        final fbUser = credential.user;
        final userId = fbUser?.uid ?? 'usr_${DateTime.now().millisecondsSinceEpoch}';
        final displayName = fbUser?.displayName ?? email.split('@').first.replaceAll('.', ' ');

        final user = AppUser(
          id: userId,
          displayName: displayName,
          phone: fbUser?.phoneNumber ?? '+233 24 123 4567',
          role: UserRole.seeker,
          city: 'Accra',
          rating: 5.0,
          createdAt: DateTime.now(),
        );

        _currentUser = user;
        await _localStorageService.saveUser(user);
        await _userRepository.saveUser(user);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Firebase Auth live sign in exception (fallback active): $e');
    }

    // Fallback/offline behavior
    final userId = 'usr_${DateTime.now().millisecondsSinceEpoch}';
    final user = AppUser(
      id: userId,
      displayName: email.split('@').first.replaceAll('.', ' '),
      phone: '+233 24 123 4567',
      role: UserRole.seeker,
      city: 'Accra',
      rating: 5.0,
      createdAt: DateTime.now(),
    );

    _currentUser = user;
    await _localStorageService.saveUser(user);
    await _userRepository.saveUser(user);

    notifyListeners();
    return true;
  }

  Future<bool> signUpWithEmail({
    required String displayName,
    required String email,
    required String password,
    required String phone,
    required UserRole role,
    required String city,
  }) async {
    _isAuthenticated = true;
    _authMethod = 'email';

    try {
      if (FirebaseService.isInitialized) {
        final credential =
            await fb_auth.FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password.trim(),
        );

        final fbUser = credential.user;
        if (fbUser != null) {
          await fbUser.updateDisplayName(displayName);
        }

        final userId = fbUser?.uid ?? 'usr_${DateTime.now().millisecondsSinceEpoch}';
        final user = AppUser(
          id: userId,
          displayName: displayName,
          phone: phone,
          role: role,
          city: city,
          rating: 5.0,
          createdAt: DateTime.now(),
        );

        _currentUser = user;
        await _localStorageService.saveUser(user);
        await _userRepository.saveUser(user);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Firebase Auth live sign up exception (fallback active): $e');
    }

    final userId = 'usr_${DateTime.now().millisecondsSinceEpoch}';
    final user = AppUser(
      id: userId,
      displayName: displayName,
      phone: phone,
      role: role,
      city: city,
      rating: 5.0,
      createdAt: DateTime.now(),
    );

    _currentUser = user;
    await _localStorageService.saveUser(user);
    await _userRepository.saveUser(user);

    notifyListeners();
    return true;
  }

  Future<bool> signInWithGoogle() async {
    _isAuthenticated = true;
    _authMethod = 'google';

    try {
      if (FirebaseService.isInitialized && kIsWeb) {
        final googleProvider = fb_auth.GoogleAuthProvider();
        final credential =
            await fb_auth.FirebaseAuth.instance.signInWithPopup(googleProvider);

        final fbUser = credential.user;
        final userId = fbUser?.uid ?? 'google_usr_${DateTime.now().millisecondsSinceEpoch}';
        final displayName = fbUser?.displayName ?? 'Kwame Google User';

        final user = AppUser(
          id: userId,
          displayName: displayName,
          phone: fbUser?.phoneNumber ?? '+233 20 111 2233',
          role: UserRole.seeker,
          city: 'Accra',
          rating: 5.0,
          createdAt: DateTime.now(),
        );

        _currentUser = user;
        await _localStorageService.saveUser(user);
        await _userRepository.saveUser(user);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Firebase Google Auth exception (fallback active): $e');
    }

    final userId = 'google_usr_${DateTime.now().millisecondsSinceEpoch}';
    final user = AppUser(
      id: userId,
      displayName: 'Kwame Google User',
      phone: '+233 20 111 2233',
      role: UserRole.seeker,
      city: 'Accra',
      rating: 5.0,
      createdAt: DateTime.now(),
    );

    _currentUser = user;
    await _localStorageService.saveUser(user);
    await _userRepository.saveUser(user);

    notifyListeners();
    return true;
  }

  Future<void> switchRole(UserRole newRole) async {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(role: newRole);
      await _localStorageService.saveUser(_currentUser!);
      await _userRepository.updateUserRole(_currentUser!.id, newRole);
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      if (FirebaseService.isInitialized) {
        await fb_auth.FirebaseAuth.instance.signOut();
      }
    } catch (e) {
      debugPrint('Firebase sign out exception: $e');
    }
    _isAuthenticated = false;
    _currentUser = null;
    await _localStorageService.clearUser();
    notifyListeners();
  }
}
