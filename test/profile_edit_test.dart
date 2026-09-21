import 'package:flutter_test/flutter_test.dart';
import 'package:local_job_connector/core/providers/auth_provider.dart';
import 'package:local_job_connector/core/repositories/user_repository.dart';
import 'package:local_job_connector/core/services/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DenyingProfileRepository extends InMemoryUserRepository {
  @override
  Future<void> updateProfile(
    String userId, {
    required String displayName,
    required String phone,
    required String city,
  }) async => throw Exception('permission-denied');
}

void main() {
  late LocalStorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalStorageService(prefs: await SharedPreferences.getInstance());
  });

  test('updateProfile saves name, phone and city', () async {
    final repo = InMemoryUserRepository();
    final auth = AuthProvider(
      userRepository: repo,
      localStorageService: storage,
    );
    final id = auth.currentUser!.id;

    final ok = await auth.updateProfile(
      displayName: '  Ama Serwaa ',
      phone: '0551234567',
      city: 'Kumasi',
    );

    expect(ok, isTrue);
    expect(auth.currentUser!.displayName, 'Ama Serwaa');
    expect(auth.currentUser!.city, 'Kumasi');
    final stored = await repo.getUser(id);
    expect(stored!.phone, '0551234567');
    expect(storage.getUser()!.city, 'Kumasi');
  });

  test('updateProfile rejects invalid input without saving', () async {
    final auth = AuthProvider(
      userRepository: InMemoryUserRepository(),
      localStorageService: storage,
    );
    final before = auth.currentUser!;

    expect(
      await auth.updateProfile(
        displayName: 'A',
        phone: '0551234567',
        city: 'Tema',
      ),
      isFalse,
    );
    expect(
      await auth.updateProfile(
        displayName: 'Ama',
        phone: '12345',
        city: 'Tema',
      ),
      isFalse,
    );
    expect(auth.lastError, isNotNull);
    expect(auth.currentUser, before);
  });

  test(
    'updateProfile keeps the old profile when the backend refuses',
    () async {
      final auth = AuthProvider(
        userRepository: DenyingProfileRepository(),
        localStorageService: storage,
      );
      final before = auth.currentUser!;

      final ok = await auth.updateProfile(
        displayName: 'Changed Name',
        phone: '0551234567',
        city: 'Tema',
      );

      expect(ok, isFalse);
      expect(auth.lastError, isNotNull);
      expect(auth.currentUser, before);
    },
  );
}
