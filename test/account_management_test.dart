import 'package:flutter_test/flutter_test.dart';
import 'package:local_job_connector/core/providers/auth_provider.dart';
import 'package:local_job_connector/core/repositories/user_repository.dart';
import 'package:local_job_connector/core/services/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late LocalStorageService storage;
  late InMemoryUserRepository users;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalStorageService(prefs: await SharedPreferences.getInstance());
    users = InMemoryUserRepository();
  });

  AuthProvider newAuth({bool signedIn = true}) => AuthProvider(
    userRepository: users,
    localStorageService: storage,
    startAuthenticated: signedIn,
  );

  group('password reset', () {
    test('rejects a malformed email with a message', () async {
      final auth = newAuth(signedIn: false);

      expect(await auth.sendPasswordReset('not-an-email'), isFalse);
      expect(auth.lastError, isNotNull);
    });

    test('accepts a well-formed email', () async {
      final auth = newAuth(signedIn: false);

      expect(await auth.sendPasswordReset('kofi@example.com'), isTrue);
      expect(auth.lastError, isNull);
    });
  });

  group('account deletion', () {
    test('removes the profile and signs the user out', () async {
      final auth = newAuth();
      final id = auth.currentUser!.id;
      expect(await users.getUser(id), isNotNull);

      final ok = await auth.deleteAccount();

      expect(ok, isTrue);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.currentUser, isNull);
      expect(await users.getUser(id), isNull);
      expect(storage.getUser(), isNull);
    });

    test('fails cleanly when nobody is signed in', () async {
      final auth = newAuth(signedIn: false);

      expect(await auth.deleteAccount(), isFalse);
      expect(auth.lastError, isNotNull);
    });
  });
}
