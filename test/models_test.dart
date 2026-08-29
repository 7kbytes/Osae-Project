import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_job_connector/core/models/chat_model.dart';
import 'package:local_job_connector/core/models/job_application_model.dart';
import 'package:local_job_connector/core/models/job_model.dart';
import 'package:local_job_connector/core/models/timestamp_helper.dart';
import 'package:local_job_connector/core/models/user_model.dart';

void main() {
  group('TimestampHelper Tests', () {
    test('parseDateTime handles null safely', () {
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      final parsed = parseDateTime(null);
      expect(parsed.isAfter(before), true);
    });

    test('parseDateTime handles DateTime directly', () {
      final now = DateTime(2026, 8, 29, 12, 0);
      expect(parseDateTime(now), now);
    });

    test('parseDateTime handles ISO8601 String', () {
      final parsed = parseDateTime('2026-08-29T10:30:00.000Z');
      expect(parsed.year, 2026);
      expect(parsed.month, 8);
      expect(parsed.day, 29);
    });

    test('parseDateTime handles invalid String fallback', () {
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      final parsed = parseDateTime('not-a-date');
      expect(parsed.isAfter(before), true);
    });

    test('parseDateTime handles int milliseconds', () {
      const millis = 1756464000000;
      final parsed = parseDateTime(millis);
      expect(parsed.millisecondsSinceEpoch, millis);
    });

    test('parseDateTime handles Firestore Timestamp', () {
      final now = DateTime.now();
      final ts = Timestamp.fromDate(now);
      final parsed = parseDateTime(ts);
      expect(parsed.millisecondsSinceEpoch ~/ 1000, now.millisecondsSinceEpoch ~/ 1000);
    });
  });

  group('AppUser Model Tests', () {
    test('AppUser serialization and deserialization with String date', () {
      final user = AppUser(
        id: 'usr_001',
        displayName: 'Kwame Mensah',
        phone: '+233 24 123 4567',
        role: UserRole.seeker,
        city: 'Accra',
        rating: 4.9,
        avatarUrl: 'https://example.com/avatar.png',
        createdAt: DateTime(2026, 1, 1),
      );

      final map = user.toMap();
      expect(map['id'], 'usr_001');
      expect(map['displayName'], 'Kwame Mensah');
      expect(map['role'], 'seeker');
      expect(map['city'], 'Accra');

      final deserialized = AppUser.fromMap(map, 'usr_001');
      expect(deserialized.id, 'usr_001');
      expect(deserialized.displayName, 'Kwame Mensah');
      expect(deserialized.phone, '+233 24 123 4567');
      expect(deserialized.role, UserRole.seeker);
      expect(deserialized.city, 'Accra');
      expect(deserialized.rating, 4.9);
      expect(deserialized.avatarUrl, 'https://example.com/avatar.png');
    });

    test('AppUser deserialization with Firestore Timestamp and defaults', () {
      final map = {
        'displayName': 'Ama Serwaa',
        'phone': '+233 20 999 8888',
        'role': 'poster',
        'city': 'Kumasi',
        'rating': 4.5,
        'createdAt': Timestamp.fromDate(DateTime(2026, 5, 10)),
      };

      final user = AppUser.fromMap(map, 'usr_poster_01');
      expect(user.id, 'usr_poster_01');
      expect(user.displayName, 'Ama Serwaa');
      expect(user.role, UserRole.poster);
      expect(user.city, 'Kumasi');
      expect(user.createdAt.month, 5);
    });

    test('AppUser copyWith updates selected fields', () {
      final user = AppUser(
        id: 'usr_001',
        displayName: 'Kwame',
        phone: '+233 24 000 0000',
        role: UserRole.seeker,
        city: 'Accra',
        createdAt: DateTime.now(),
      );

      final updated = user.copyWith(
        displayName: 'Kwame Osei',
        role: UserRole.poster,
        city: 'Tema',
      );

      expect(updated.displayName, 'Kwame Osei');
      expect(updated.role, UserRole.poster);
      expect(updated.city, 'Tema');
      expect(updated.phone, '+233 24 000 0000');
    });
  });

  group('JobPost Model Tests', () {
    test('JobPost serialization and deserialization with String date', () {
      final job = JobPost(
        id: 'job_001',
        title: 'Masonry Helper',
        description: 'Need skilled assistant for site work at Circle',
        category: 'Construction & Labor',
        payRate: 180.0,
        payUnit: 'per day',
        currency: 'GHS',
        city: 'Accra',
        locationName: 'Circle VIP Terminal',
        latitude: 5.5586,
        longitude: -0.2014,
        posterId: 'poster_001',
        posterName: 'Accra Builders',
        posterPhone: '+233 24 111 2222',
        isFilled: false,
        isFavorite: true,
        createdAt: DateTime(2026, 6, 1),
      );

      final map = job.toMap();
      expect(map['title'], 'Masonry Helper');
      expect(map['payRate'], 180.0);
      expect(map['city'], 'Accra');

      final deserialized = JobPost.fromMap(map, 'job_001');
      expect(deserialized.id, 'job_001');
      expect(deserialized.title, 'Masonry Helper');
      expect(deserialized.description, 'Need skilled assistant for site work at Circle');
      expect(deserialized.category, 'Construction & Labor');
      expect(deserialized.payRate, 180.0);
      expect(deserialized.payUnit, 'per day');
      expect(deserialized.currency, 'GHS');
      expect(deserialized.city, 'Accra');
      expect(deserialized.locationName, 'Circle VIP Terminal');
      expect(deserialized.latitude, 5.5586);
      expect(deserialized.longitude, -0.2014);
      expect(deserialized.posterId, 'poster_001');
    });

    test('JobPost deserialization with Timestamp and fallback defaults', () {
      final map = {
        'title': 'Chop Bar Server',
        'category': 'Hospitality',
        'payRate': 120,
        'city': 'Kumasi',
        'createdAt': Timestamp.fromDate(DateTime(2026, 7, 1)),
      };

      final job = JobPost.fromMap(map, 'job_kuma_01');
      expect(job.id, 'job_kuma_01');
      expect(job.title, 'Chop Bar Server');
      expect(job.payRate, 120.0);
      expect(job.currency, 'GHS');
      expect(job.payUnit, 'per day');
      expect(job.isFilled, false);
      expect(job.createdAt.month, 7);
    });

    test('JobPost copyWith updates selected fields', () {
      final job = JobPost(
        id: 'job_001',
        title: 'Original Title',
        description: 'Original Desc',
        category: 'Cleaning',
        payRate: 100.0,
        city: 'Tema',
        locationName: 'Community 1',
        latitude: 5.64,
        longitude: 0.0,
        posterId: 'p1',
        posterName: 'Poster 1',
        posterPhone: '123',
        createdAt: DateTime.now(),
      );

      final updated = job.copyWith(
        title: 'Updated Title',
        isFilled: true,
        payRate: 140.0,
      );

      expect(updated.title, 'Updated Title');
      expect(updated.isFilled, true);
      expect(updated.payRate, 140.0);
      expect(updated.city, 'Tema');
    });

    test('JobStatus enum serialization, deserialization, and compatibility', () {
      final jobOpen = JobPost(
        id: 'job_status_01',
        title: 'Painter',
        description: 'Paint compound wall',
        category: 'Construction',
        payRate: 150.0,
        city: 'Accra',
        locationName: 'Madina',
        latitude: 5.67,
        longitude: -0.16,
        posterId: 'poster_01',
        posterName: 'Ama',
        posterPhone: '0241112222',
        status: JobStatus.open,
        createdAt: DateTime(2026, 8, 29),
      );

      final openMap = jobOpen.toMap();
      expect(openMap['status'], 'open');
      expect(openMap['isFilled'], false);

      final inProgressJob = jobOpen.copyWith(status: JobStatus.inProgress);
      expect(inProgressJob.status, JobStatus.inProgress);
      expect(inProgressJob.isFilled, true);
      expect(inProgressJob.toMap()['status'], 'inProgress');
      expect(inProgressJob.toMap()['isFilled'], true);

      final completedJob = jobOpen.copyWith(status: JobStatus.completed);
      expect(completedJob.status, JobStatus.completed);
      expect(completedJob.isFilled, true);

      // Test JobStatus.fromString helper
      expect(JobStatus.fromString('open'), JobStatus.open);
      expect(JobStatus.fromString('inProgress'), JobStatus.inProgress);
      expect(JobStatus.fromString('in_progress'), JobStatus.inProgress);
      expect(JobStatus.fromString('completed'), JobStatus.completed);
      expect(JobStatus.fromString('invalid'), JobStatus.open);
      expect(JobStatus.fromString(null), JobStatus.open);

      // Test deserialization with isFilled only (legacy data)
      final legacyMapFilled = {
        'title': 'Legacy Gig',
        'isFilled': true,
        'createdAt': '2026-08-29T00:00:00.000Z',
      };
      final parsedLegacyFilled = JobPost.fromMap(legacyMapFilled, 'legacy_01');
      expect(parsedLegacyFilled.status, JobStatus.completed);
      expect(parsedLegacyFilled.isFilled, true);

      final legacyMapOpen = {
        'title': 'Legacy Open Gig',
        'isFilled': false,
        'createdAt': '2026-08-29T00:00:00.000Z',
      };
      final parsedLegacyOpen = JobPost.fromMap(legacyMapOpen, 'legacy_02');
      expect(parsedLegacyOpen.status, JobStatus.open);
      expect(parsedLegacyOpen.isFilled, false);
    });
  });

  group('ChatMessage & ChatRoom Model Tests', () {
    test('ChatMessage serialization and deserialization', () {
      final message = ChatMessage(
        id: 'msg_01',
        senderId: 'seeker_01',
        senderName: 'Kofi Mensah',
        text: 'Hello, is the gig still available?',
        timestamp: DateTime(2026, 8, 29, 9, 30),
        isRead: true,
      );

      final map = message.toMap();
      expect(map['text'], 'Hello, is the gig still available?');
      expect(map['isRead'], true);

      final deserialized = ChatMessage.fromMap(map, 'msg_01');
      expect(deserialized.id, 'msg_01');
      expect(deserialized.senderName, 'Kofi Mensah');
      expect(deserialized.text, 'Hello, is the gig still available?');
      expect(deserialized.isRead, true);
    });

    test('ChatMessage deserialization with Firestore Timestamp', () {
      final map = {
        'senderId': 'p1',
        'senderName': 'Akosua',
        'text': 'Yes, come right now!',
        'timestamp': Timestamp.fromDate(DateTime(2026, 8, 29, 10, 0)),
        'isRead': false,
      };

      final msg = ChatMessage.fromMap(map, 'msg_02');
      expect(msg.id, 'msg_02');
      expect(msg.text, 'Yes, come right now!');
      expect(msg.timestamp.hour, 10);
      expect(msg.isRead, false);
    });

    test('ChatRoom serialization and deserialization', () {
      final room = ChatRoom(
        id: 'room_01',
        jobId: 'job_01',
        jobTitle: 'Produce Offloader',
        seekerId: 'seeker_01',
        seekerName: 'Kofi',
        posterId: 'poster_01',
        posterName: 'Akosua Wholesale',
        lastMessage: 'I am on my way.',
        updatedAt: DateTime(2026, 8, 29, 11, 0),
      );

      final map = room.toMap();
      expect(map['jobTitle'], 'Produce Offloader');
      expect(map['lastMessage'], 'I am on my way.');

      final deserialized = ChatRoom.fromMap(map, 'room_01');
      expect(deserialized.id, 'room_01');
      expect(deserialized.jobTitle, 'Produce Offloader');
      expect(deserialized.seekerName, 'Kofi');
      expect(deserialized.posterName, 'Akosua Wholesale');
      expect(deserialized.lastMessage, 'I am on my way.');
    });
  });

  group('JobApplication Model Tests', () {
    test('JobApplication serialization and deserialization', () {
      final app = JobApplication(
        id: 'app_001',
        jobId: 'job_101',
        jobTitle: 'Market Offloader',
        seekerId: 'seeker_001',
        seekerName: 'Kofi Mensah',
        seekerPhone: '+233 24 123 4567',
        posterId: 'poster_001',
        status: ApplicationStatus.pending,
        note: 'I have 3 years experience in offloading.',
        appliedAt: DateTime(2026, 8, 29, 8, 0),
      );

      final map = app.toMap();
      expect(map['status'], 'pending');
      expect(map['seekerPhone'], '+233 24 123 4567');

      final deserialized = JobApplication.fromMap(map, 'app_001');
      expect(deserialized.id, 'app_001');
      expect(deserialized.jobTitle, 'Market Offloader');
      expect(deserialized.status, ApplicationStatus.pending);
      expect(deserialized.note, 'I have 3 years experience in offloading.');
    });

    test('JobApplication copyWith and status updates', () {
      final app = JobApplication(
        id: 'app_001',
        jobId: 'job_101',
        jobTitle: 'Market Offloader',
        seekerId: 'seeker_001',
        seekerName: 'Kofi Mensah',
        seekerPhone: '+233 24 123 4567',
        posterId: 'poster_001',
        status: ApplicationStatus.pending,
        appliedAt: DateTime.now(),
      );

      final accepted = app.copyWith(status: ApplicationStatus.accepted);
      expect(accepted.status, ApplicationStatus.accepted);

      final rejected = app.copyWith(status: ApplicationStatus.rejected);
      expect(rejected.status, ApplicationStatus.rejected);
    });
  });
}
