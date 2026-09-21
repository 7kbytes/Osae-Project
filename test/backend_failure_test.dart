import 'package:flutter_test/flutter_test.dart';
import 'package:local_job_connector/core/models/chat_model.dart';
import 'package:local_job_connector/core/models/job_application_model.dart';
import 'package:local_job_connector/core/models/job_model.dart';
import 'package:local_job_connector/core/providers/application_provider.dart';
import 'package:local_job_connector/core/providers/chat_provider.dart';
import 'package:local_job_connector/core/providers/job_provider.dart';
import 'package:local_job_connector/core/repositories/application_repository.dart';
import 'package:local_job_connector/core/repositories/chat_repository.dart';
import 'package:local_job_connector/core/repositories/job_repository.dart';
import 'package:local_job_connector/core/services/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simulates Firestore rejecting writes (e.g. permission-denied).
class DenyingJobRepository extends InMemoryJobRepository {
  @override
  Future<void> addJob(JobPost job) async =>
      throw Exception('permission-denied');

  @override
  Future<void> updateJob(JobPost job) async =>
      throw Exception('permission-denied');

  @override
  Future<void> deleteJob(String jobId) async =>
      throw Exception('permission-denied');
}

class DenyingApplicationRepository extends InMemoryApplicationRepository {
  DenyingApplicationRepository({super.localStorageService});

  @override
  Future<void> submitApplication(JobApplication application) async =>
      throw Exception('permission-denied');

  @override
  Future<void> updateStatus(
    String applicationId,
    ApplicationStatus status,
  ) async => throw Exception('permission-denied');
}

/// Simulates the live application queries failing (e.g. offline or denied).
class FailingStreamApplicationRepository extends InMemoryApplicationRepository {
  FailingStreamApplicationRepository({super.localStorageService});

  bool fail = true;

  @override
  Stream<List<JobApplication>> getSeekerApplications(String seekerId) => fail
      ? Stream.error(Exception('unavailable'))
      : super.getSeekerApplications(seekerId);

  @override
  Stream<List<JobApplication>> getPosterApplications(String posterId) => fail
      ? Stream.error(Exception('unavailable'))
      : super.getPosterApplications(posterId);
}

class DenyingChatRepository extends InMemoryChatRepository {
  @override
  Future<void> sendMessage(String chatRoomId, ChatMessage message) async =>
      throw Exception('permission-denied');
}

class RoomDenyingChatRepository extends InMemoryChatRepository {
  @override
  Future<String> getOrCreateChatRoom({
    required String jobId,
    required String jobTitle,
    required String seekerId,
    required String seekerName,
    required String posterId,
    required String posterName,
  }) async => throw Exception('permission-denied');
}

class FailingMessagesChatRepository extends InMemoryChatRepository {
  bool fail = true;

  @override
  Stream<List<ChatMessage>> getMessagesStream(String chatRoomId) => fail
      ? Stream.error(Exception('unavailable'))
      : super.getMessagesStream(chatRoomId);
}

class FailingStreamChatRepository extends InMemoryChatRepository {
  bool fail = true;

  @override
  Stream<List<ChatRoom>> getChatRoomsStream(String userId) => fail
      ? Stream.error(Exception('unavailable'))
      : super.getChatRoomsStream(userId);
}

JobPost _job(String id) => JobPost(
  id: id,
  title: 'Test job $id',
  description: 'd',
  category: 'Cleaning',
  payRate: 50,
  city: 'Accra',
  locationName: 'Osu',
  latitude: 5.5,
  longitude: -0.2,
  posterId: 'poster1',
  posterName: 'Poster',
  posterPhone: '0241234567',
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  late LocalStorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalStorageService(prefs: await SharedPreferences.getInstance());
  });

  group('JobProvider when the backend rejects writes', () {
    test('addJob rolls back and reports failure', () async {
      final provider = JobProvider(
        jobRepository: DenyingJobRepository(),
        localStorageService: storage,
      );
      final before = provider.allJobs.length;

      final saved = await provider.addJob(_job('new1'));

      expect(saved, isFalse);
      expect(provider.allJobs.length, before);
      expect(provider.allJobs.any((j) => j.id == 'new1'), isFalse);
      expect(provider.lastError, isNotNull);
    });

    test('addJob succeeds against a healthy repository', () async {
      final provider = JobProvider(
        jobRepository: InMemoryJobRepository(),
        localStorageService: storage,
      );

      final saved = await provider.addJob(_job('ok1'));

      expect(saved, isTrue);
      expect(provider.allJobs.any((j) => j.id == 'ok1'), isTrue);
      expect(provider.lastError, isNull);
    });

    test('updateJobStatus restores the previous status on failure', () async {
      final repo = InMemoryJobRepository();
      final provider = JobProvider(
        jobRepository: repo,
        localStorageService: storage,
      );
      await provider.addJob(_job('u1'));
      final failing = JobProvider(
        jobRepository: DenyingJobRepository(),
        localStorageService: storage,
      );
      final id = failing.allJobs.first.id;
      final original = failing.allJobs.first.status;

      await failing.updateJobStatus(id, JobStatus.completed);

      expect(failing.allJobs.firstWhere((j) => j.id == id).status, original);
      expect(failing.lastError, isNotNull);
    });

    test('deleteJob restores the job on failure', () async {
      final provider = JobProvider(
        jobRepository: DenyingJobRepository(),
        localStorageService: storage,
      );
      final id = provider.allJobs.first.id;
      final count = provider.allJobs.length;

      await provider.deleteJob(id);

      expect(provider.allJobs.length, count);
      expect(provider.allJobs.any((j) => j.id == id), isTrue);
    });
  });

  group('ApplicationProvider when the backend rejects writes', () {
    test('submitApplication rolls back and returns false', () async {
      final provider = ApplicationProvider(
        applicationRepository: DenyingApplicationRepository(
          localStorageService: storage,
        ),
        localStorageService: storage,
      );

      final ok = await provider.submitApplication(
        jobId: 'j1',
        jobTitle: 'Job',
        employerId: 'poster1',
        applicantId: 'seeker1',
        applicantName: 'Seeker',
        applicantPhone: '0241234567',
        coverNote: 'hi',
      );

      expect(ok, isFalse);
      expect(provider.hasApplied('j1', 'seeker1'), isFalse);
      expect(provider.errorMessage, isNotNull);
    });
  });

  group('Load failures surface as errors, not empty lists', () {
    test('applications: loadError is set, then cleared by retryLoad', () async {
      final repo = FailingStreamApplicationRepository(
        localStorageService: storage,
      );
      final provider = ApplicationProvider(
        applicationRepository: repo,
        localStorageService: storage,
      );

      provider.bindUser('seeker1');
      expect(provider.isLoading, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(provider.isLoading, isFalse);
      expect(provider.loadError, isNotNull);
      expect(provider.errorMessage, isNull);

      repo.fail = false;
      provider.retryLoad();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(provider.loadError, isNull);
      expect(provider.isLoading, isFalse);
    });

    test('chats: loadError is set, then cleared by retryLoad', () async {
      final repo = FailingStreamChatRepository();
      final provider = ChatProvider(
        chatRepository: repo,
        localStorageService: storage,
        currentUserId: 'seekerA',
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(provider.loadError, isNotNull);
      expect(provider.isLoading, isFalse);

      repo.fail = false;
      provider.retryLoad();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(provider.loadError, isNull);
    });
  });

  group('ChatProvider when the backend rejects a message', () {
    test('sendMessage removes the message and reports failure', () async {
      final provider = ChatProvider(
        chatRepository: DenyingChatRepository(),
        localStorageService: storage,
        currentUserId: 'seekerA',
      );
      final roomId = provider.getOrCreateRoom(
        jobId: 'job1',
        jobTitle: 'Job',
        seekerId: 'seekerA',
        seekerName: 'A',
        posterId: 'poster1',
        posterName: 'P',
      );
      final before = provider.getMessages(roomId).length;

      final sent = await provider.sendMessage(
        roomId: roomId,
        senderId: 'seekerA',
        senderName: 'A',
        text: 'hello',
      );

      expect(sent, isFalse);
      expect(provider.sendError, isNotNull);
      expect(
        provider.getMessages(roomId).any((m) => m.text == 'hello'),
        isFalse,
      );
      expect(provider.getMessages(roomId).length, before);
    });
  });

  group('ChatProvider room and message failures', () {
    test('a room the backend refuses is removed and reported', () async {
      final provider = ChatProvider(
        chatRepository: RoomDenyingChatRepository(),
        localStorageService: storage,
        currentUserId: 'seekerA',
      );
      final roomId = provider.getOrCreateRoom(
        jobId: 'job2',
        jobTitle: 'Job',
        seekerId: 'seekerA',
        seekerName: 'A',
        posterId: 'poster1',
        posterName: 'P',
      );
      expect(provider.rooms.any((r) => r.id == roomId), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(provider.rooms.any((r) => r.id == roomId), isFalse);
      expect(provider.roomError(roomId), isNotNull);
    });

    test('message load failure is reported and retry clears it', () async {
      final repo = FailingMessagesChatRepository();
      final provider = ChatProvider(
        chatRepository: repo,
        localStorageService: storage,
        currentUserId: 'seekerA',
      );
      provider.getMessages('room_x');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(provider.messagesError('room_x'), isNotNull);

      repo.fail = false;
      provider.retryMessages('room_x');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(provider.messagesError('room_x'), isNull);
    });
  });

  group('Chat rooms', () {
    test('room id is deterministic per job and seeker', () {
      expect(
        ChatRoom.idFor('job1', 'seekerA'),
        ChatRoom.idFor('job1', 'seekerA'),
      );
      expect(
        ChatRoom.idFor('job1', 'seekerA'),
        isNot(ChatRoom.idFor('job1', 'seekerB')),
      );
    });

    test('provider uses the same id the repository will create', () async {
      final provider = ChatProvider(
        chatRepository: InMemoryChatRepository(),
        localStorageService: storage,
        currentUserId: 'seekerA',
      );

      final id = provider.getOrCreateRoom(
        jobId: 'job9',
        jobTitle: 'Job',
        seekerId: 'seekerA',
        seekerName: 'A',
        posterId: 'poster1',
        posterName: 'P',
      );

      expect(id, ChatRoom.idFor('job9', 'seekerA'));
    });

    test('setCurrentUser clears the previous user\'s rooms', () async {
      final provider = ChatProvider(
        chatRepository: InMemoryChatRepository(),
        localStorageService: storage,
        currentUserId: 'seeker_001',
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(provider.rooms, isNotEmpty);

      provider.setCurrentUser('someone_else');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(provider.rooms, isEmpty);
    });
  });
}
