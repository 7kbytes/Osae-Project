import 'package:flutter_test/flutter_test.dart';
import 'package:local_job_connector/main.dart';

void main() {
  testWidgets('app starts on the login screen when not in demo mode', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const LocalJobConnectorApp(demo: false));
    await tester.pumpAndSettle();

    expect(find.text('Jobs'), findsNothing); // no bottom navigation
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('LocalJobConnector app loads and navigates through tabs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const LocalJobConnectorApp(demo: true));
    await tester.pumpAndSettle();

    // Verify main app title is rendered in JobFeed
    expect(find.text('Local Job Connector'), findsOneWidget);

    // Verify Bottom Navigation Bar has 6 items
    expect(find.text('Jobs'), findsOneWidget);
    expect(find.text('Map'), findsOneWidget);
    expect(find.text('Post Gig'), findsOneWidget);
    expect(find.text('Chats'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    // Tap 'Post Gig' tab (index 2)
    await tester.tap(find.text('Post Gig'));
    await tester.pumpAndSettle();
    expect(find.text('Post Informal Job'), findsOneWidget);

    // Tap 'Chats' tab (index 3)
    await tester.tap(find.text('Chats'));
    await tester.pumpAndSettle();
    expect(find.text('Messages & Direct Chat'), findsOneWidget);

    // Tap 'Saved' tab (index 4)
    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();
    expect(find.text('Saved Jobs / Favorites'), findsOneWidget);

    // Tap 'Profile' tab (index 5)
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('My Account & Settings'), findsOneWidget);
    expect(find.textContaining('Emmanuel Duodu Osae'), findsOneWidget);

    // Tap 'Jobs' tab (index 0)
    await tester.tap(find.text('Jobs'));
    await tester.pumpAndSettle();
    expect(find.text('Local Job Connector'), findsOneWidget);
  });
}
