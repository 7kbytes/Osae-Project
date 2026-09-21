import 'package:flutter_test/flutter_test.dart';
import 'package:local_job_connector/core/models/user_model.dart';
import 'package:local_job_connector/core/providers/auth_provider.dart';
import 'package:local_job_connector/core/repositories/user_repository.dart';

void main() {
  group('AuthProvider Tests', () {
    late AuthProvider authProvider;
    late InMemoryUserRepository userRepository;

    setUp(() {
      userRepository = InMemoryUserRepository();
      authProvider = AuthProvider(
        userRepository: userRepository,
        startAuthenticated: true,
      );
    });

    test('Default initialized user state', () {
      expect(authProvider.isAuthenticated, true);
      expect(authProvider.currentUser, isNotNull);
      expect(authProvider.currentUser!.displayName, 'Kofi Mensah');
      expect(authProvider.currentUser!.role, UserRole.seeker);
      expect(authProvider.currentUser!.city, 'Accra');
      expect(authProvider.authMethod, 'email');
      expect(authProvider.userEmail, 'kofi.mensah@gmail.com');
    });

    test('Unauthenticated initialization', () {
      final unauth = AuthProvider(
        userRepository: userRepository,
        startAuthenticated: false,
      );
      expect(unauth.isAuthenticated, false);
      expect(unauth.currentUser, isNull);
    });

    test('Sign in with email and password', () async {
      final unauth = AuthProvider(
        userRepository: userRepository,
        startAuthenticated: false,
      );

      final success = await unauth.signInWithEmail(
        'kwame.osei@gmail.com',
        'password123',
      );
      expect(success, true);
      expect(unauth.isAuthenticated, true);
      expect(unauth.currentUser, isNotNull);
      expect(unauth.currentUser!.displayName, 'kwame osei');
      expect(unauth.authMethod, 'email');

      // Verify saved in repository
      final savedUser = await userRepository.getUser(unauth.currentUser!.id);
      expect(savedUser, isNotNull);
    });

    test('Sign up with email and custom details', () async {
      final unauth = AuthProvider(
        userRepository: userRepository,
        startAuthenticated: false,
      );

      final success = await unauth.signUpWithEmail(
        displayName: 'Ama Serwaa',
        email: 'ama@gmail.com',
        password: 'securePassword!',
        phone: '+233 24 555 6677',
        role: UserRole.poster,
        city: 'Kumasi',
      );

      expect(success, true);
      expect(unauth.isAuthenticated, true);
      expect(unauth.currentUser!.displayName, 'Ama Serwaa');
      expect(unauth.currentUser!.role, UserRole.poster);
      expect(unauth.currentUser!.city, 'Kumasi');
      expect(unauth.currentUser!.phone, '+233 24 555 6677');
    });

    test('Sign in with Google OAuth simulation', () async {
      final unauth = AuthProvider(
        userRepository: userRepository,
        startAuthenticated: false,
      );

      final success = await unauth.signInWithGoogle();
      expect(success, true);
      expect(unauth.isAuthenticated, true);
      expect(unauth.authMethod, 'google');
      expect(unauth.currentUser!.displayName, 'Kwame Google User');
    });

    test('Switch role dynamically and verify persistence', () async {
      expect(authProvider.currentUser!.role, UserRole.seeker);

      await authProvider.switchRole(UserRole.poster);
      expect(authProvider.currentUser!.role, UserRole.poster);

      final savedUser = await userRepository.getUser(
        authProvider.currentUser!.id,
      );
      expect(savedUser!.role, UserRole.poster);

      await authProvider.switchRole(UserRole.seeker);
      expect(authProvider.currentUser!.role, UserRole.seeker);
    });

    test('Sign out clears user state', () {
      expect(authProvider.isAuthenticated, true);
      authProvider.signOut();
      expect(authProvider.isAuthenticated, false);
      expect(authProvider.currentUser, isNull);
    });

    test('Ghana phone number validation', () {
      // Valid international formats
      expect(AuthProvider.isValidGhanaPhone('+233 24 123 4567'), true);
      expect(AuthProvider.isValidGhanaPhone('+233241234567'), true);
      expect(AuthProvider.isValidGhanaPhone('+233 55 999 8888'), true);
      expect(AuthProvider.isValidGhanaPhone('+233 20 111 2222'), true);

      // Valid local formats
      expect(AuthProvider.isValidGhanaPhone('0241234567'), true);
      expect(AuthProvider.isValidGhanaPhone('0559998888'), true);
      expect(AuthProvider.isValidGhanaPhone('0201112222'), true);
      expect(AuthProvider.isValidGhanaPhone('0273334455'), true);

      // Invalid formats
      expect(AuthProvider.isValidGhanaPhone('12345'), false);
      expect(AuthProvider.isValidGhanaPhone('+1 555 123 4567'), false);
      expect(AuthProvider.isValidGhanaPhone('0123456789'), false);
      expect(AuthProvider.isValidGhanaPhone('not-a-number'), false);
    });
  });
}
