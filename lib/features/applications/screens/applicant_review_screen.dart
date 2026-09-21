import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/theme.dart';
import '../../../core/models/job_application_model.dart';
import '../../../core/models/job_model.dart';
import '../../../core/providers/application_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/chat_provider.dart';
import '../../../core/providers/job_provider.dart';
import '../../chat/screens/chat_room_screen.dart';

class ApplicantReviewScreen extends StatelessWidget {
  final String jobId;
  final String jobTitle;

  const ApplicantReviewScreen({
    super.key,
    required this.jobId,
    required this.jobTitle,
  });

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
        return 'Accepted';
      case ApplicationStatus.rejected:
        return 'Rejected';
      case ApplicationStatus.completed:
        return 'Completed';
    }
  }

  @override
  Widget build(BuildContext context) {
    final applicationProvider = Provider.of<ApplicationProvider>(context);
    final jobProvider = Provider.of<JobProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final applications = applicationProvider.getApplicationsForJob(jobId);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          jobTitle.isNotEmpty ? 'Applicants: $jobTitle' : 'Review Applicants',
        ),
      ),
      body: applications.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 72,
                      color: AppTheme.textMuted.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No Applicants Yet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'When job seekers apply for this listing, their applications will appear here for your review.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: AppTheme.textMuted),
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
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Applicant Header
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: AppTheme.primaryColor.withValues(
                                alpha: 0.12,
                              ),
                              child: Text(
                                app.seekerName.isNotEmpty
                                    ? app.seekerName
                                          .substring(0, 1)
                                          .toUpperCase()
                                    : 'A',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    app.seekerName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.phone,
                                        size: 14,
                                        color: AppTheme.textMuted,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        app.seekerPhone.isNotEmpty
                                            ? app.seekerPhone
                                            : 'No phone provided',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppTheme.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
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

                        // Cover Note
                        if (app.note.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.format_quote,
                                      size: 16,
                                      color: AppTheme.textMuted,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Cover Note',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  app.note,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.textDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 14,
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
                          ],
                        ),

                        const SizedBox(height: 14),
                        const Divider(height: 1),
                        const SizedBox(height: 10),

                        // Actions
                        Row(
                          children: [
                            // Chat button
                            IconButton(
                              tooltip: 'Chat with Seeker',
                              icon: const Icon(
                                Icons.chat_bubble_outline,
                                color: AppTheme.primaryColor,
                              ),
                              onPressed: () {
                                final currentPoster = authProvider.currentUser;
                                final roomId = chatProvider.getOrCreateRoom(
                                  jobId: jobId,
                                  jobTitle: jobTitle,
                                  seekerId: app.seekerId,
                                  seekerName: app.seekerName,
                                  posterId: app.posterId,
                                  posterName:
                                      currentPoster?.displayName ?? 'Employer',
                                );

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatRoomScreen(
                                      roomId: roomId,
                                      jobTitle: jobTitle,
                                      otherUserName: app.seekerName,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const Spacer(),

                            if (app.status == ApplicationStatus.pending) ...[
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                icon: const Icon(Icons.close, size: 16),
                                label: const Text('Reject'),
                                onPressed: () async {
                                  await applicationProvider
                                      .updateApplicationStatus(
                                        app.id,
                                        ApplicationStatus.rejected,
                                      );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Application for ${app.seekerName} rejected.',
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                ),
                                icon: const Icon(Icons.check, size: 16),
                                label: const Text('Accept'),
                                onPressed: () async {
                                  await applicationProvider
                                      .updateApplicationStatus(
                                        app.id,
                                        ApplicationStatus.accepted,
                                      );
                                  await jobProvider.updateJobStatus(
                                    jobId,
                                    JobStatus.inProgress,
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Accepted ${app.seekerName} for this job!',
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ] else ...[
                              Text(
                                app.status == ApplicationStatus.accepted
                                    ? 'Applicant Accepted'
                                    : (app.status == ApplicationStatus.rejected
                                          ? 'Application Rejected'
                                          : 'Completed'),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
