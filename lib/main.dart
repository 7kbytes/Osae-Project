import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app/theme.dart';
import 'core/providers/application_provider.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/chat_provider.dart';
import 'core/providers/job_provider.dart';
import 'core/services/firebase_service.dart';
import 'core/services/local_storage_service.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/navigation/main_navigation_screen.dart';
import 'firebase_options.dart';

/// Set with `--dart-define=DEMO_MODE=true` to run without Firebase (local
/// in-memory data and a demo user). Never enabled in release builds by default.
const bool kDemoMode = bool.fromEnvironment('DEMO_MODE');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorageService.instance.init();
  await FirebaseService.initialize(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (!FirebaseService.isInitialized && !kDemoMode) {
    runApp(StartupErrorApp(error: FirebaseService.initError));
    return;
  }
  runApp(const LocalJobConnectorApp());
}

class StartupErrorApp extends StatelessWidget {
  final Object? error;
  const StartupErrorApp({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Cannot connect to the service',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('Please check your connection and restart the app.'),
                if (kDebugMode && error != null) ...[
                  const SizedBox(height: 12),
                  Text('$error', style: const TextStyle(fontSize: 12)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LocalJobConnectorApp extends StatelessWidget {
  /// Start signed in as the demo user (only for demo mode and tests).
  final bool demo;

  const LocalJobConnectorApp({super.key, this.demo = kDemoMode});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // With real Firebase the session comes from FirebaseAuth; the demo
        // user is only used in explicit demo mode.
        ChangeNotifierProvider(
          create: (_) => AuthProvider(startAuthenticated: demo),
        ),
        // Keep the job screens' seeker/poster mode in step with the signed-in user.
        ChangeNotifierProxyProvider<AuthProvider, JobProvider>(
          create: (_) => JobProvider(),
          update: (ctx, auth, jobs) {
            final role = auth.currentUser?.role;
            if (role != null && role != jobs!.currentUserRole) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => jobs.setRole(role),
              );
            }
            return jobs!;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, ChatProvider>(
          create: (ctx) => ChatProvider(
            currentUserId: ctx.read<AuthProvider>().currentUser?.id ?? '',
          ),
          update: (ctx, auth, chat) {
            chat!.setCurrentUser(auth.currentUser?.id ?? '');
            return chat;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, ApplicationProvider>(
          create: (_) => ApplicationProvider(),
          update: (ctx, auth, apps) {
            if (FirebaseService.isInitialized) {
              final uid = auth.currentUser?.id ?? '';
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => apps!.bindUser(uid),
              );
            }
            return apps!;
          },
        ),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return MaterialApp(
            title: 'Local Job Connector',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            home: auth.isAuthenticated
                ? const MainNavigationScreen()
                : const LoginScreen(),
          );
        },
      ),
    );
  }
}
