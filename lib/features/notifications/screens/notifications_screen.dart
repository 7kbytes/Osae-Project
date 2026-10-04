import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/theme.dart';
import '../../../core/models/job_application_model.dart';
import '../../../core/providers/application_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../applications/screens/applicant_review_screen.dart';
import '../../jobs/screens/job_detail_screen.dart';

enum _NotificationKind { newApplicant, statusUpdate }

class _NotificationItem {
  final _NotificationKind kind;
  final JobApplication application;

  const _NotificationItem({required this.kind, required this.application});

  DateTime get sortTime => application.appliedAt;
}

/// Derives notifications from application data already held by
/// [ApplicationProvider] rather than a separate backend feed: new
/// applicants for jobs the signed-in user posted, and status changes
/// on applications the signed-in user submitted.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  List<_NotificationItem> _buildItems(
    String uid,
    List<JobApplication> applications,
  ) {
    final items = <_NotificationItem>[];
    for (final app in applications) {
      if (app.posterId == uid && app.status == ApplicationStatus.pending) {
        items.add(
          _NotificationItem(
            kind: _NotificationKind.newApplicant,
            application: app,
          ),
        );
      } else if (app.seekerId == uid &&
          app.status != ApplicationStatus.pending) {
        items.add(
          _NotificationItem(
            kind: _NotificationKind.statusUpdate,
            application: app,
          ),
        );
      }
    }
    items.sort((a, b) => b.sortTime.compareTo(a.sortTime));
    return items;
  }

  (IconData, Color) _iconFor(_NotificationItem item) {
    switch (item.kind) {
      case _NotificationKind.newApplicant:
        return (Icons.person_add_alt_1, AppTheme.primaryColor);
      case _NotificationKind.statusUpdate:
        switch (item.application.status) {
          case ApplicationStatus.accepted:
            return (Icons.check_circle, Colors.green);
          case ApplicationStatus.rejected:
            return (Icons.cancel, Colors.red);
          case ApplicationStatus.completed:
            return (Icons.task_alt, Colors.blue);
          case ApplicationStatus.pending:
            return (Icons.hourglass_empty, AppTheme.textMuted);
        }
    }
  }

  String _titleFor(_NotificationItem item) {
    switch (item.kind) {
      case _NotificationKind.newApplicant:
        return '${item.application.seekerName} applied to your job';
      case _NotificationKind.statusUpdate:
        switch (item.application.status) {
          case ApplicationStatus.accepted:
            return 'Your application was accepted';
          case ApplicationStatus.rejected:
            return 'Your application was not selected';
          case ApplicationStatus.completed:
            return 'Job marked as completed';
          case ApplicationStatus.pending:
            return 'Application pending';
        }
    }
  }

  void _handleTap(BuildContext context, _NotificationItem item) {
    if (item.kind == _NotificationKind.newApplicant) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ApplicantReviewScreen(
            jobId: item.application.jobId,
            jobTitle: item.application.jobTitle,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => JobDetailScreen(jobId: item.application.jobId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().currentUser?.id ?? '';
    final applications = context.watch<ApplicationProvider>().applications;
    final items = _buildItems(uid, applications);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "You're all caught up",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'New applicants and application updates will show up here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                final (icon, color) = _iconFor(item);
                return Card(
                  elevation: 0,
                  color: Colors.grey.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.12),
                      child: Icon(icon, color: color),
                    ),
                    title: Text(
                      _titleFor(item),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(item.application.jobTitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _handleTap(context, item),
                  ),
                );
              },
            ),
    );
  }
}
