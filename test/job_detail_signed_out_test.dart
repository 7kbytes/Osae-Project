import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_job_connector/core/models/user_model.dart';
import 'package:local_job_connector/core/providers/job_provider.dart';
import 'package:local_job_connector/core/repositories/job_repository.dart';
import 'package:local_job_connector/core/services/local_storage_service.dart';
import 'package:local_job_connector/features/jobs/screens/job_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Without a signed-in user the screen must not act as a fake one (R1).
void main() {
  testWidgets('signed-out viewer cannot apply or start a chat', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = LocalStorageService(
      prefs: await SharedPreferences.getInstance(),
    );
    final jobProvider = JobProvider(
      jobRepository: InMemoryJobRepository(),
      localStorageService: storage,
    )..setRole(UserRole.seeker);
    final job = jobProvider.allJobs.first;

    await tester.pumpWidget(
      ChangeNotifierProvider<JobProvider>.value(
        value: jobProvider,
        child: MaterialApp(home: JobDetailScreen(jobId: job.id)),
      ),
    );
    await tester.pump();

    final apply = tester.widget<ElevatedButton>(
      find.byKey(const Key('apply_for_job_button')),
    );
    expect(apply.onPressed, isNull);

    final chat = find.widgetWithText(
      OutlinedButton,
      'Start Chat with Employer',
    );
    expect(tester.widget<OutlinedButton>(chat).onPressed, isNull);

    // Let the in-memory repository's timers finish before teardown.
    await tester.pump(const Duration(seconds: 5));
  });
}
