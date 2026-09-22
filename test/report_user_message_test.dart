import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_job_connector/core/models/chat_model.dart';
import 'package:local_job_connector/core/models/report_model.dart';
import 'package:local_job_connector/core/providers/auth_provider.dart';
import 'package:local_job_connector/core/providers/chat_provider.dart';
import 'package:local_job_connector/core/repositories/chat_repository.dart';
import 'package:local_job_connector/core/repositories/report_repository.dart';
import 'package:local_job_connector/core/repositories/user_repository.dart';
import 'package:local_job_connector/core/services/local_storage_service.dart';
import 'package:local_job_connector/features/chat/screens/chat_room_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late LocalStorageService storage;
  late InMemoryReportRepository reports;
  late InMemoryChatRepository chats;
  late AuthProvider auth;
  late ChatProvider chat;
  late String roomId;
  late String myId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalStorageService(prefs: await SharedPreferences.getInstance());
    reports = InMemoryReportRepository();
    chats = InMemoryChatRepository();
    auth = AuthProvider(
      userRepository: InMemoryUserRepository(),
      localStorageService: storage,
    );
    myId = auth.currentUser!.id;
    chat = ChatProvider(
      chatRepository: chats,
      localStorageService: storage,
      currentUserId: myId,
    );
    roomId = chat.getOrCreateRoom(
      jobId: 'job1',
      jobTitle: 'Clean office',
      seekerId: myId,
      seekerName: auth.currentUser!.displayName,
      posterId: 'poster9',
      posterName: 'Kwame Poster',
    );
    // A message from the other party, which is the one that can be reported.
    await chat.sendMessage(
      roomId: roomId,
      senderId: 'poster9',
      senderName: 'Kwame Poster',
      text: 'Pay me 200 cedis first',
    );
  });

  Widget wrap() => MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider<ChatProvider>.value(value: chat),
      Provider<ReportRepository>.value(value: reports),
    ],
    child: MaterialApp(
      home: ChatRoomScreen(
        roomId: roomId,
        jobTitle: 'Clean office',
        otherUserName: 'Kwame Poster',
      ),
    ),
  );

  testWidgets('a seeker can report the other person in a chat', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump();

    await tester.tap(find.byKey(const Key('report_user_button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('report_note_input')),
      'Asked for money upfront',
    );
    await tester.tap(find.byKey(const Key('submit_report_button')));
    await tester.pumpAndSettle();

    expect(reports.reports, hasLength(1));
    final report = reports.reports.single;
    expect(report.targetType, ReportTarget.user);
    expect(report.targetId, 'poster9');
    expect(report.reporterId, myId);
    expect(report.note, 'Asked for money upfront');
    expect(report.status, ReportStatus.open);
  });

  testWidgets('long-pressing the other party\'s message reports it', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pump();

    await tester.longPress(find.text('Pay me 200 cedis first'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('submit_report_button')));
    await tester.pumpAndSettle();

    expect(reports.reports, hasLength(1));
    final report = reports.reports.single;
    expect(report.targetType, ReportTarget.message);
    expect(report.targetTitle, 'Pay me 200 cedis first');
    expect(report.reporterId, myId);
  });

  testWidgets('a user cannot report their own message', (tester) async {
    await chat.sendMessage(
      roomId: roomId,
      senderId: myId,
      senderName: 'Me',
      text: 'My own message',
    );
    await tester.pumpWidget(wrap());
    await tester.pump();

    await tester.longPress(find.text('My own message'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('submit_report_button')), findsNothing);
    expect(reports.reports, isEmpty);
  });

  testWidgets('cancelling files nothing', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump();

    await tester.tap(find.byKey(const Key('report_user_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(reports.reports, isEmpty);
  });

  test('the chat room derives the other party from the room', () {
    final room = chat.rooms.firstWhere((r) => r.id == roomId);
    expect(ChatRoom.idFor('job1', myId), roomId);
    expect(room.posterId, 'poster9');
  });
}
