import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/theme.dart';
import '../../../core/models/job_application_model.dart';
import '../../../core/providers/application_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/job_provider.dart';
import '../../jobs/screens/job_detail_screen.dart';

class MyApplicationsScreen extends StatelessWidget {
  const MyApplicationsScreen({super.key});

  Color _getStatusColor(ApplicationStatus status) {
    switch (status) {
      case ApplicationStatus.pending:
        return Colors.orange;
      case ApplicationStatus.accepted:
        return Colors.green;
      case ApplicationStatus.rejected:
        return Colors.red;
      case ApplicationStatus.completed:
        return AppTheme.primaryColor;
    }
  }

  String _getStatusLabel(ApplicationStatus status) {
    switch (status) {
      case ApplicationStatus.pending:
        return 'Pending Review';
      case ApplicationStatus.accepted:
        return 'Accepted 🎉';
      case ApplicationStatus.rejected:
        return 'Not Selected';
      case ApplicationStatus.completed:
        return 'Job Completed';
    }
  }

  @override
  Widget build(BuildContext context) {
    final applicationProvider = Provider.of<ApplicationProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final jobProvider = Provider.of<JobProvider>(context, listen: false);

    final currentUserId = authProvider.currentUser?.id ?? '';
    final applications = applicationProvider.getApplicationsForSeeker(
      currentUserId,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('My Applications')),
      body: (applicationProvider.isLoading && applications.isEmpty)
          ? const Center(child: CircularProgressIndicator())
          : (applicationProvider.loadError != null && applications.isEmpty)
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off, size: 56),
                  const SizedBox(height: 12),
                  Text(applicationProvider.loadError!),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: applicationProvider.retryLoad,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            )
          : applications.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.assignment_outlined,
                      size: 72,
                      color: AppTheme.textMuted.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No Applications Yet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'You have not submitted any job applications yet. Browse the job feed to find and apply for informal gig opportunities.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.search),
                      label: const Text('Browse Available Jobs'),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: applications.length,
              itemBuilder: (context, index) {
                final app = applications[index];
                final statusColor = _getStatusColor(app.status);

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  margin: const EdgeInsets.only(bottom: 16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      final jobExists = jobProvider.allJobs.any(
                        (j) => j.id == app.jobId,
                      );
                      if (jobExists) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => JobDetailScreen(jobId: app.jobId),
                          ),
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: Job Title + Status Badge
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  app.jobTitle,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textDark,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: statusColor.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Text(
                                  _getStatusLabel(app.status),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // Cover Note snippet if available
                          if (app.note.isNotEmpty) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Text(
                                'Note: "${app.note}"',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                  color: AppTheme.textDark,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],

                          // Date and action
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                size: 13,
                                color: AppTheme.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Applied: ${app.appliedAt.day}/${app.appliedAt.month}/${app.appliedAt.year}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () {
                                  final jobExists = jobProvider.allJobs.any(
                                    (j) => j.id == app.jobId,
                                  );
                                  if (jobExists) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            JobDetailScreen(jobId: app.jobId),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.arrow_forward, size: 14),
                                label: const Text('View Job'),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 0),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
