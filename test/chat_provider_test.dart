import 'package:flutter_test/flutter_test.dart';
import 'package:local_job_connector/core/providers/chat_provider.dart';
import 'package:local_job_connector/core/repositories/chat_repository.dart';

void main() {
  group('ChatProvider Tests', () {
    late ChatProvider chatProvider;
    late InMemoryChatRepository chatRepository;

    setUp(() {
      chatRepository = InMemoryChatRepository();
      chatProvider = ChatProvider(chatRepository: chatRepository);
    });

    test('Initial chat rooms and messages loaded', () {
      expect(chatProvider.rooms.isNotEmpty, true);
      final firstRoom = chatProvider.rooms.first;
      expect(firstRoom.id, 'chat_101');
      expect(firstRoom.jobTitle, 'Market Offloader & Heavy Carrier');

      final messages = chatProvider.getMessages('chat_101');
      expect(messages.length, 3);
      expect(
        messages.first.text,
        'Hello Kofi, are you available today at Circle VIP terminal?',
      );
    });

    test('getOrCreateRoom returns existing room without duplicate', () {
      final initialCount = chatProvider.rooms.length;

      final roomId = chatProvider.getOrCreateRoom(
        jobId: 'job_101',
        jobTitle: 'Market Offloader & Heavy Carrier',
        seekerId: 'seeker_001',
        seekerName: 'Kofi Mensah',
        posterId: 'poster_001',
        posterName: 'Akosua Wholesale',
      );

      expect(roomId, 'chat_101');
      expect(chatProvider.rooms.length, initialCount);
    });

    test('getOrCreateRoom creates new room and initial message', () {
      final initialCount = chatProvider.rooms.length;

      final newRoomId = chatProvider.getOrCreateRoom(
        jobId: 'job_999',
        jobTitle: 'Store Attendant in Kumasi',
        seekerId: 'seeker_001',
        seekerName: 'Kofi Mensah',
        posterId: 'poster_kumasi_01',
        posterName: 'Kumasi Trader',
      );

      expect(newRoomId.startsWith('chat_'), true);
      expect(chatProvider.rooms.length, initialCount + 1);
      expect(chatProvider.rooms.first.id, newRoomId);
      expect(chatProvider.rooms.first.jobTitle, 'Store Attendant in Kumasi');

      final roomMessages = chatProvider.getMessages(newRoomId);
      expect(roomMessages.length, 1);
      expect(
        roomMessages.first.text.contains('Store Attendant in Kumasi'),
        true,
      );
    });

    test('sendMessage appends message and updates room metadata', () {
      const roomId = 'chat_101';
      final initialMessagesCount = chatProvider.getMessages(roomId).length;

      chatProvider.sendMessage(
        roomId: roomId,
        senderId: 'seeker_001',
        senderName: 'Kofi Mensah',
        text: 'I am right at the gate near Container 14.',
      );

      final updatedMessages = chatProvider.getMessages(roomId);
      expect(updatedMessages.length, initialMessagesCount + 1);
      expect(
        updatedMessages.last.text,
        'I am right at the gate near Container 14.',
      );

      final room = chatProvider.rooms.firstWhere((r) => r.id == roomId);
      expect(room.lastMessage, 'I am right at the gate near Container 14.');
    });

    test('sendMessage ignores empty or whitespace-only messages', () {
      const roomId = 'chat_101';
      final initialMessagesCount = chatProvider.getMessages(roomId).length;

      chatProvider.sendMessage(
        roomId: roomId,
        senderId: 'seeker_001',
        senderName: 'Kofi Mensah',
        text: '   ',
      );

      expect(chatProvider.getMessages(roomId).length, initialMessagesCount);
    });
  });
}
