import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/theme.dart';
import '../../../core/models/job_application_model.dart';
import '../../../core/models/job_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/providers/application_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/chat_provider.dart';
import '../../../core/providers/job_provider.dart';
import '../../../core/utils/form_validators.dart';
import '../../../core/utils/input_sanitizer.dart';
import '../../applications/screens/applicant_review_screen.dart';
import '../../chat/screens/chat_room_screen.dart';

class JobDetailScreen extends StatelessWidget {
  final String jobId;

  const JobDetailScreen({super.key, required this.jobId});

  Color _getApplicationBgColor(ApplicationStatus? status) {
    switch (status) {
      case ApplicationStatus.accepted:
        return Colors.green.shade50;
      case ApplicationStatus.rejected:
        return Colors.red.shade50;
      case ApplicationStatus.completed:
        return Colors.blue.shade50;
      case ApplicationStatus.pending:
      default:
        return Colors.amber.shade50;
    }
  }

  Color _getApplicationBorderColor(ApplicationStatus? status) {
    switch (status) {
      case ApplicationStatus.accepted:
        return Colors.green.shade300;
      case ApplicationStatus.rejected:
        return Colors.red.shade300;
      case ApplicationStatus.completed:
        return Colors.blue.shade300;
      case ApplicationStatus.pending:
      default:
        return Colors.amber.shade300;
    }
  }

  Color _getApplicationTextColor(ApplicationStatus? status) {
    switch (status) {
      case ApplicationStatus.accepted:
        return Colors.green.shade800;
      case ApplicationStatus.rejected:
        return Colors.red.shade800;
      case ApplicationStatus.completed:
        return Colors.blue.shade800;
      case ApplicationStatus.pending:
      default:
        return Colors.amber.shade900;
    }
  }

  IconData _getApplicationIcon(ApplicationStatus? status) {
    switch (status) {
      case ApplicationStatus.accepted:
        return Icons.check_circle;
      case ApplicationStatus.rejected:
        return Icons.cancel;
      case ApplicationStatus.completed:
        return Icons.verified;
      case ApplicationStatus.pending:
      default:
        return Icons.hourglass_top;
    }
  }

  String _getApplicationStatusName(ApplicationStatus? status) {
    switch (status) {
      case ApplicationStatus.accepted:
        return 'Accepted 🎉';
      case ApplicationStatus.rejected:
        return 'Not Selected';
      case ApplicationStatus.completed:
        return 'Completed';
      case ApplicationStatus.pending:
      default:
        return 'Pending Review';
    }
  }

  void _showApplyBottomSheet(
    BuildContext context, {
    required JobPost job,
    required String applicantId,
    required String defaultName,
    required String defaultPhone,
  }) {
    final noteController = TextEditingController();
    final phoneController = TextEditingController(text: defaultPhone);
    final nameController = TextEditingController(text: defaultName);
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Apply for ${job.title}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Confirm your contact details and add a short note to the employer.',
                    style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('apply_name_input'),
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) => FormValidators.validateRequired(val, 'Full Name', minLength: 2),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const Key('apply_phone_input'),
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Contact Phone Number',
                      prefixIcon: Icon(Icons.phone),
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) => FormValidators.validateGhanaPhone(val),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const Key('apply_note_input'),
                    controller: noteController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Cover Note / Experience (Optional)',
                      hintText:
                          'e.g. 3 years experience, available immediately...',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      key: const Key('submit_application_button'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        if (formKey.currentState?.validate() ?? false) {
                          final appProvider = Provider.of<ApplicationProvider>(
                            context,
                            listen: false,
                          );
                          final success = await appProvider.submitApplication(
                            jobId: job.id,
                            jobTitle: job.title,
                            employerId: job.posterId,
                            applicantId: applicantId,
                            applicantName: InputSanitizer.sanitize(nameController.text),
                            applicantPhone: InputSanitizer.sanitizePhone(phoneController.text),
                            coverNote: InputSanitizer.sanitize(noteController.text),
                          );
                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  success
                                      ? 'Application submitted successfully!'
                                      : 'You have already applied for this job.',
                                ),
                                backgroundColor:
                                    success ? Colors.green : Colors.orange,
                              ),
                            );
                          }
                        }
                      },
                      child: const Text(
                        'Submit Application',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final jobProvider = Provider.of<JobProvider>(context);
    
    ApplicationProvider? applicationProvider;
    try {
      applicationProvider = Provider.of<ApplicationProvider>(context);
    } catch (_) {}

    AuthProvider? authProvider;
    try {
      authProvider = Provider.of<AuthProvider>(context);
    } catch (_) {}

    ChatProvider? chatProvider;
    try {
      chatProvider = Provider.of<ChatProvider>(context, listen: false);
    } catch (_) {}

    final currentUser = authProvider?.currentUser;
    final currentUserId = currentUser?.id ?? 'seeker_001';
    final currentUserName = currentUser?.displayName ?? 'Kofi Mensah';
    final currentUserPhone = currentUser?.phone ?? '+233 24 123 4567';

    JobPost? matchingJob;
    try {
      matchingJob = jobProvider.allJobs.firstWhere((j) => j.id == jobId);
    } catch (_) {
      matchingJob = null;
    }

    if (matchingJob == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Job Details'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text(
                  'Job Not Found',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This job listing is no longer available or does not exist.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  key: const Key('return_to_jobs_feed_button'),
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Return to Jobs Feed'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final job = matchingJob;

    final isFav = jobProvider.isFavorite(job.id);
    final isSeeker = jobProvider.currentUserRole == UserRole.seeker;
    final hasApplied =
        applicationProvider?.hasApplied(job.id, currentUserId) ?? false;
    final existingApp =
        applicationProvider?.getApplication(job.id, currentUserId);
    final jobApplicants =
        applicationProvider?.getApplicationsForJob(job.id) ?? [];

    // Job Status badge styling
    Color statusBadgeBg;
    Color statusBadgeBorder;
    Color statusBadgeText;
    String statusBadgeLabel;
    switch (job.status) {
      case JobStatus.open:
        statusBadgeBg = Colors.green.shade50;
        statusBadgeBorder = Colors.green.shade300;
        statusBadgeText = Colors.green;
        statusBadgeLabel = 'Active / Open';
        break;
      case JobStatus.inProgress:
        statusBadgeBg = Colors.orange.shade50;
        statusBadgeBorder = Colors.orange.shade300;
        statusBadgeText = Colors.orange.shade800;
        statusBadgeLabel = 'In Progress';
        break;
      case JobStatus.completed:
        statusBadgeBg = Colors.blue.shade50;
        statusBadgeBorder = Colors.blue.shade300;
        statusBadgeText = Colors.blue.shade800;
        statusBadgeLabel = 'Completed';
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Details'),
        actions: [
          IconButton(
            icon: Icon(
              isFav ? Icons.favorite : Icons.favorite_border,
              color: isFav ? AppTheme.secondaryColor : Colors.white,
            ),
            onPressed: () => jobProvider.toggleFavorite(job.id),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Chip(
                          label: Text(job.category),
                          backgroundColor:
                              AppTheme.primaryColor.withValues(alpha: 0.12),
                          side: BorderSide.none,
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusBadgeBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: statusBadgeBorder),
                          ),
                          child: Text(
                            statusBadgeLabel,
                            style: TextStyle(
                              color: statusBadgeText,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      job.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            color: AppTheme.primaryColor, size: 20),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${job.locationName}, ${job.city}',
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppTheme.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Text(
                          'Payment: ',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        Text(
                          '${job.currency} ${job.payRate.toStringAsFixed(0)} ',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        Text(
                          '/ ${job.payUnit}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Description Section
              const Text(
                'Job Description',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  job.description,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: AppTheme.textDark,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Employer Info Card
              const Text(
                'Employer Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor:
                          AppTheme.primaryColor.withValues(alpha: 0.1),
                      child: const Icon(Icons.store,
                          color: AppTheme.primaryColor, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job.posterName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            job.posterPhone,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons & Workflows
              if (isSeeker) ...[
                // If user has already applied, display Application Status Card
                if (hasApplied) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _getApplicationBgColor(existingApp?.status),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            _getApplicationBorderColor(existingApp?.status),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getApplicationIcon(existingApp?.status),
                          color:
                              _getApplicationTextColor(existingApp?.status),
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Applied: ${_getApplicationStatusName(existingApp?.status)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _getApplicationTextColor(
                                    existingApp?.status,
                                  ),
                                  fontSize: 15,
                                ),
                              ),
                              if (existingApp != null &&
                                  existingApp.note.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Your note: "${existingApp.note}"',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textDark,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ] else ...[
                  // Apply for Job Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      key: const Key('apply_for_job_button'),
                      onPressed: job.status == JobStatus.completed
                          ? null
                          : () => _showApplyBottomSheet(
                                context,
                                job: job,
                                applicantId: currentUserId,
                                defaultName: currentUserName,
                                defaultPhone: currentUserPhone,
                              ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.assignment_turned_in),
                      label: const Text(
                        'Apply for this Job',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Chat with Employer Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final roomId = chatProvider?.getOrCreateRoom(
                            jobId: job.id,
                            jobTitle: job.title,
                            seekerId: currentUserId,
                            seekerName: currentUserName,
                            posterId: job.posterId,
                            posterName: job.posterName,
                          ) ??
                          'room_${job.id}_$currentUserId';

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatRoomScreen(
                            roomId: roomId,
                            jobTitle: job.title,
                            otherUserName: job.posterName,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Start Chat with Employer'),
                  ),
                ),
              ] else ...[
                // Employer Controls: View Applicants Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    key: const Key('view_applicants_button'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ApplicantReviewScreen(
                            jobId: job.id,
                            jobTitle: job.title,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.people),
                    label: Text('View Applicants (${jobApplicants.length})'),
                  ),
                ),

                const SizedBox(height: 16),

                // Job Lifecycle Status Controls Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Job Lifecycle Status',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Update the current status of this gig listing:',
                        style:
                            TextStyle(fontSize: 13, color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            key: const Key('job_status_open'),
                            avatar: const Icon(Icons.lock_open, size: 16),
                            label: const Text('Open'),
                            selected: job.status == JobStatus.open,
                            selectedColor: Colors.green.shade100,
                            onSelected: (selected) {
                              if (selected) {
                                jobProvider.updateJobStatus(
                                  job.id,
                                  JobStatus.open,
                                );
                                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Job status set to Open'),
                                  ),
                                );
                              }
                            },
                          ),
                          ChoiceChip(
                            key: const Key('job_status_in_progress'),
                            avatar: const Icon(Icons.autorenew, size: 16),
                            label: const Text('In Progress'),
                            selected: job.status == JobStatus.inProgress,
                            selectedColor: Colors.orange.shade100,
                            onSelected: (selected) {
                              if (selected) {
                                jobProvider.updateJobStatus(
                                  job.id,
                                  JobStatus.inProgress,
                                );
                                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Job status set to In Progress'),
                                  ),
                                );
                              }
                            },
                          ),
                          ChoiceChip(
                            key: const Key('job_status_completed'),
                            avatar: const Icon(Icons.check_circle_outline,
                                size: 16),
                            label: const Text('Completed'),
                            selected: job.status == JobStatus.completed,
                            selectedColor: Colors.blue.shade100,
                            onSelected: (selected) {
                              if (selected) {
                                jobProvider.updateJobStatus(
                                  job.id,
                                  JobStatus.completed,
                                );
                                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Job status set to Completed'),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You are viewing this listing in Employer mode. Switch role in Profile to apply.',
                          style: TextStyle(fontSize: 13, color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
