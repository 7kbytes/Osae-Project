import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_job_connector/app/theme.dart';
import 'package:local_job_connector/core/providers/auth_provider.dart';
import 'package:local_job_connector/core/providers/chat_provider.dart';
import 'package:local_job_connector/core/providers/job_provider.dart';
import 'package:local_job_connector/core/repositories/chat_repository.dart';
import 'package:local_job_connector/core/repositories/job_repository.dart';
import 'package:local_job_connector/core/repositories/user_repository.dart';
import 'package:local_job_connector/features/chat/screens/chat_list_screen.dart';
import 'package:local_job_connector/features/chat/screens/chat_room_screen.dart';
import 'package:provider/provider.dart';

Widget createChatTestApp(
  Widget homeWidget, {
  AuthProvider? auth,
  JobProvider? job,
  ChatProvider? chat,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>(
        create: (_) =>
            auth ??
            AuthProvider(
              userRepository: InMemoryUserRepository(),
              startAuthenticated: true,
            ),
      ),
      ChangeNotifierProvider<JobProvider>(
        create: (_) =>
            job ?? JobProvider(jobRepository: InMemoryJobRepository()),
      ),
      ChangeNotifierProvider<ChatProvider>(
        create: (_) =>
            chat ??
            ChatProvider(
              currentUserId: 'seeker_001',
              chatRepository: InMemoryChatRepository(),
            ),
      ),
    ],
    child: MaterialApp(theme: AppTheme.lightTheme, home: homeWidget),
  );
}

void main() {
  group('ChatListScreen Widget Tests', () {
    testWidgets('Renders conversation threads with job titles and snippets', (
      WidgetTester tester,
    ) async {
      final chatProvider = ChatProvider(
        currentUserId: 'seeker_001',
        chatRepository: InMemoryChatRepository(),
      );

      await tester.pumpWidget(
        createChatTestApp(const ChatListScreen(), chat: chatProvider),
      );
      await tester.pumpAndSettle();

      expect(find.text('Messages & Direct Chat'), findsOneWidget);
      expect(find.text('Akosua Wholesale'), findsOneWidget);
      expect(find.text('Re: Market Offloader & Heavy Carrier'), findsOneWidget);
      expect(
        find.text('Great! Come to Container 14 near the VIP bus park.'),
        findsOneWidget,
      );
    });

    testWidgets('Tapping a conversation item navigates to ChatRoomScreen', (
      WidgetTester tester,
    ) async {
      final chatProvider = ChatProvider(
        currentUserId: 'seeker_001',
        chatRepository: InMemoryChatRepository(),
      );

      await tester.pumpWidget(
        createChatTestApp(const ChatListScreen(), chat: chatProvider),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Akosua Wholesale'));
      await tester.pumpAndSettle();

      expect(find.byType(ChatRoomScreen), findsOneWidget);
      expect(find.text('Akosua Wholesale'), findsOneWidget);
      expect(find.text('Market Offloader & Heavy Carrier'), findsOneWidget);
    });
  });

  group('ChatRoomScreen Widget Tests', () {
    testWidgets('Renders message bubbles and sends new message', (
      WidgetTester tester,
    ) async {
      final chatProvider = ChatProvider(
        currentUserId: 'seeker_001',
        chatRepository: InMemoryChatRepository(),
      );

      await tester.pumpWidget(
        createChatTestApp(
          const ChatRoomScreen(
            roomId: 'chat_101',
            jobTitle: 'Market Offloader & Heavy Carrier',
            otherUserName: 'Akosua Wholesale',
          ),
          chat: chatProvider,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Hello Kofi, are you available today at Circle VIP terminal?',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Yes Madam Akosua! I am near Kwame Nkrumah Circle now.'),
        findsOneWidget,
      );

      // Type and send new message
      await tester.enterText(
        find.byType(TextField),
        'I have reached Container 14.',
      );
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(find.text('I have reached Container 14.'), findsOneWidget);
      expect(find.text(''), findsWidgets); // Textfield is cleared
    });
  });
}
