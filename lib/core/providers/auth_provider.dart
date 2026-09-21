import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../repositories/user_repository.dart';
import '../services/firebase_service.dart';
import '../services/local_storage_service.dart';
import '../utils/input_sanitizer.dart';
import '../services/mock_data.dart';

/// Authentication state.
///
/// When Firebase is initialised the session is owned by Firebase Auth:
/// credentials are verified for real, failures return `false` with
/// [lastError] set, and no fake user is ever created.
///
/// When Firebase is *not* initialised (unit tests and explicit demo mode) the
/// provider works against the injected repository with a local demo user.
class AuthProvider with ChangeNotifier {
  final UserRepository _userRepository;
  final LocalStorageService _localStorageService;
  bool _isAuthenticated = false;
  AppUser? _currentUser;
  String _authMethod = 'email'; // 'email' or 'google'
  String? _email;
  String? _lastError;
  StreamSubscription<fb_auth.User?>? _authSubscription;

  bool get _live => FirebaseService.isInitialized;

  AuthProvider({
    UserRepository? userRepository,
    LocalStorageService? localStorageService,
    bool startAuthenticated = true,
  }) : _userRepository =
           userRepository ??
           (FirebaseService.isInitialized
               ? FirestoreUserRepository()
               : InMemoryUserRepository()),
       _localStorageService =
           localStorageService ?? LocalStorageService.instance {
    if (_live) {
      _listenToFirebaseSession();
    } else if (startAuthenticated) {
      _isAuthenticated = true;
      _initDemoUser();
    }
  }

  // ---------------------------------------------------------------------------
  // Session
  // ---------------------------------------------------------------------------

  void _listenToFirebaseSession() {
    _authSubscription = fb_auth.FirebaseAuth.instance.authStateChanges().listen(
      (fbUser) async {
        if (fbUser == null) {
          if (_isAuthenticated) {
            _isAuthenticated = false;
            _currentUser = null;
            _email = null;
            await _localStorageService.clearUser();
            notifyListeners();
          }
          return;
        }
        // Sign-in/sign-up flows set the user themselves; only restore here when
        // a stored session is picked up on start-up.
        if (_currentUser?.id == fbUser.uid && _isAuthenticated) return;
        _currentUser = await _loadOrCreateProfile(fbUser);
        _email = fbUser.email;
        _isAuthenticated = true;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _initDemoUser() {
    final cachedUser = _localStorageService.getUser();
    _currentUser = cachedUser ?? MockData.currentSeekerUser;
    if (cachedUser == null) _localStorageService.saveUser(_currentUser!);
    _userRepository.saveUser(_currentUser!);
  }

  /// Loads the stored profile for [fbUser]; only creates one when none exists
  /// (so a returning user keeps their role, city and phone).
  Future<AppUser> _loadOrCreateProfile(
    fb_auth.User fbUser, {
    String? displayName,
    String? phone,
    UserRole role = UserRole.seeker,
    String city = 'Accra',
  }) async {
    var user = await _userRepository.getUser(fbUser.uid);
    if (user == null) {
      user = AppUser(
        id: fbUser.uid,
        displayName:
            displayName ??
            fbUser.displayName ??
            (fbUser.email ?? 'User').split('@').first.replaceAll('.', ' '),
        phone: phone ?? fbUser.phoneNumber ?? '',
        role: role,
        city: city,
        rating: 5.0,
        createdAt: DateTime.now(),
      );
      await _userRepository.saveUser(user);
    }
    await _localStorageService.saveUser(user);
    return user;
  }

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  bool get isAuthenticated => _isAuthenticated;
  AppUser? get currentUser => _currentUser;
  String get authMethod => _authMethod;

  /// Human-readable reason the last sign-in/sign-up attempt failed.
  String? get lastError => _lastError;

  String get userEmail {
    if (_email != null && _email!.isNotEmpty) return _email!;
    return _currentUser != null && _currentUser!.displayName.isNotEmpty
        ? '${_currentUser!.displayName.toLowerCase().replaceAll(' ', '.')}@gmail.com'
        : 'user@gmail.com';
  }

  /// Validates Ghanaian phone numbers in international (+233) or local (02X/05X/020) format.
  static bool isValidGhanaPhone(String phone) {
    final sanitized = phone.replaceAll(RegExp(r'[\s\-]'), '');
    final ghanaPhoneRegex = RegExp(r'^(?:\+233|0)[235][0-9]{8}$');
    return ghanaPhoneRegex.hasMatch(sanitized);
  }

  static String _messageFor(fb_auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-email':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'No internet connection. Please try again.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'requires-recent-login':
        return 'For security, please sign out, sign in again, then retry.';
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
        return 'Sign-in was cancelled.';
      default:
        return 'Could not sign in. Please try again.';
    }
  }

  // ---------------------------------------------------------------------------
  // Sign in / up
  // ---------------------------------------------------------------------------

  Future<bool> signInWithEmail(String email, String password) async {
    _lastError = null;

    if (_live) {
      try {
        final credential = await fb_auth.FirebaseAuth.instance
            .signInWithEmailAndPassword(
              email: email.trim(),
              password: password.trim(),
            );
        return await _completeLiveSignIn(credential.user, 'email');
      } on fb_auth.FirebaseAuthException catch (e) {
        return _fail(_messageFor(e));
      } catch (e) {
        debugPrint('Sign-in error: $e');
        return _fail('Could not sign in. Please try again.');
      }
    }

    // Local/demo mode (no Firebase).
    _authMethod = 'email';
    return _signInLocal(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      displayName: email.split('@').first.replaceAll('.', ' '),
      phone: '+233 24 123 4567',
      role: UserRole.seeker,
      city: 'Accra',
    );
  }

  Future<bool> signUpWithEmail({
    required String displayName,
    required String email,
    required String password,
    required String phone,
    required UserRole role,
    required String city,
  }) async {
    _lastError = null;

    if (_live) {
      try {
        final credential = await fb_auth.FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: email.trim(),
              password: password.trim(),
            );
        final fbUser = credential.user;
        if (fbUser == null) return _fail('Could not create the account.');
        await fbUser.updateDisplayName(displayName);
        // The profile chosen at sign-up wins over any default.
        final user = AppUser(
          id: fbUser.uid,
          displayName: displayName,
          phone: phone,
          role: role,
          city: city,
          rating: 5.0,
          createdAt: DateTime.now(),
        );
        await _userRepository.saveUser(user);
        await _localStorageService.saveUser(user);
        _authMethod = 'email';
        _email = fbUser.email;
        _currentUser = user;
        _isAuthenticated = true;
        notifyListeners();
        return true;
      } on fb_auth.FirebaseAuthException catch (e) {
        return _fail(_messageFor(e));
      } catch (e) {
        debugPrint('Sign-up error: $e');
        return _fail('Could not create the account. Please try again.');
      }
    }

    _authMethod = 'email';
    return _signInLocal(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      displayName: displayName,
      phone: phone,
      role: role,
      city: city,
    );
  }

  Future<bool> signInWithGoogle() async {
    _lastError = null;

    if (_live) {
      if (!kIsWeb) {
        return _fail('Google sign-in is not available on this platform yet.');
      }
      try {
        final credential = await fb_auth.FirebaseAuth.instance.signInWithPopup(
          fb_auth.GoogleAuthProvider(),
        );
        return await _completeLiveSignIn(credential.user, 'google');
      } on fb_auth.FirebaseAuthException catch (e) {
        return _fail(_messageFor(e));
      } catch (e) {
        debugPrint('Google sign-in error: $e');
        return _fail('Could not sign in with Google. Please try again.');
      }
    }

    _authMethod = 'google';
    return _signInLocal(
      id: 'google_usr_${DateTime.now().millisecondsSinceEpoch}',
      displayName: 'Kwame Google User',
      phone: '+233 20 111 2233',
      role: UserRole.seeker,
      city: 'Accra',
    );
  }

  Future<bool> _completeLiveSignIn(fb_auth.User? fbUser, String method) async {
    if (fbUser == null) return _fail('Could not sign in. Please try again.');
    _currentUser = await _loadOrCreateProfile(fbUser);
    _authMethod = method;
    _email = fbUser.email;
    _isAuthenticated = true;
    notifyListeners();
    return true;
  }

  Future<bool> _signInLocal({
    required String id,
    required String displayName,
    required String phone,
    required UserRole role,
    required String city,
  }) async {
    final user = AppUser(
      id: id,
      displayName: displayName,
      phone: phone,
      role: role,
      city: city,
      rating: 5.0,
      createdAt: DateTime.now(),
    );
    _isAuthenticated = true;
    _currentUser = user;
    await _localStorageService.saveUser(user);
    await _userRepository.saveUser(user);
    notifyListeners();
    return true;
  }

  bool _fail(String message) {
    _lastError = message;
    notifyListeners();
    return false;
  }

  /// Sends a password-reset email. Always reports success for well-formed
  /// addresses so the response doesn't reveal whether an account exists.
  Future<bool> sendPasswordReset(String email) async {
    _lastError = null;
    final address = email.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(address)) {
      return _fail('Enter a valid email address.');
    }
    if (!_live) return true;
    try {
      await fb_auth.FirebaseAuth.instance.sendPasswordResetEmail(
        email: address,
      );
      return true;
    } on fb_auth.FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') return true;
      return _fail(_messageFor(e));
    } catch (e) {
      debugPrint('Password reset error: $e');
      return _fail('Could not send the reset email. Please try again.');
    }
  }

  /// Permanently deletes the signed-in user's profile and login.
  /// Jobs they posted are not removed (needs a server-side cascade, R13).
  Future<bool> deleteAccount() async {
    _lastError = null;
    final user = _currentUser;
    if (user == null) return _fail('Not signed in.');

    if (_live) {
      final fbUser = fb_auth.FirebaseAuth.instance.currentUser;
      if (fbUser == null) return _fail('Not signed in.');
      try {
        // Profile first: once the login is deleted the rules no longer
        // recognise the caller.
        await _userRepository.deleteUser(user.id);
        await fbUser.delete();
      } on fb_auth.FirebaseAuthException catch (e) {
        // Restore the profile if the login could not be deleted.
        await _userRepository.saveUser(user);
        return _fail(_messageFor(e));
      } catch (e) {
        debugPrint('Delete account error: $e');
        try {
          await _userRepository.saveUser(user);
        } catch (_) {}
        return _fail('Could not delete the account. Please try again.');
      }
    } else {
      await _userRepository.deleteUser(user.id);
    }

    _isAuthenticated = false;
    _currentUser = null;
    _email = null;
    await _localStorageService.clearUser();
    notifyListeners();
    return true;
  }

  // ---------------------------------------------------------------------------
  // Profile / sign out
  // ---------------------------------------------------------------------------

  /// Saves the editable profile fields. Returns false and sets [lastError]
  /// (leaving the profile unchanged) if validation or the backend fails.
  Future<bool> updateProfile({
    required String displayName,
    required String phone,
    required String city,
  }) async {
    _lastError = null;
    final user = _currentUser;
    if (user == null) return _fail('Not signed in.');

    final name = InputSanitizer.sanitize(displayName).trim();
    final cleanPhone = phone.trim();
    final cleanCity = city.trim();
    if (name.length < 2 || name.length > 100) {
      return _fail('Enter a name between 2 and 100 characters.');
    }
    if (!isValidGhanaPhone(cleanPhone)) {
      return _fail('Enter a valid Ghana phone number.');
    }
    if (cleanCity.isEmpty || cleanCity.length > 60) {
      return _fail('Choose your city.');
    }

    try {
      await _userRepository.updateProfile(
        user.id,
        displayName: name,
        phone: cleanPhone,
        city: cleanCity,
      );
    } catch (e) {
      debugPrint('Update profile error: $e');
      return _fail('Could not save your profile. Please try again.');
    }

    _currentUser = user.copyWith(
      displayName: name,
      phone: cleanPhone,
      city: cleanCity,
    );
    await _localStorageService.saveUser(_currentUser!);
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
      if (_live) {
        await fb_auth.FirebaseAuth.instance.signOut();
      }
    } catch (e) {
      debugPrint('Firebase sign out exception: $e');
    }
    _isAuthenticated = false;
    _currentUser = null;
    _email = null;
    await _localStorageService.clearUser();
    notifyListeners();
  }
}
