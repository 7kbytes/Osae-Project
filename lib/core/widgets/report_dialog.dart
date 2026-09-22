import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/report_model.dart';
import '../repositories/report_repository.dart';
import '../utils/input_sanitizer.dart';

/// Asks for a reason and optional details, then files a report for review.
///
/// Used for jobs, users and messages so every report looks the same to the
/// reporter and lands in the same admin queue.
Future<void> showReportDialog(
  BuildContext context, {
  required ReportTarget targetType,
  required String targetId,
  required String targetTitle,
  required String reporterId,
  required String title,
  required String confirmation,
}) async {
  if (reporterId.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Sign in to report this.')));
    return;
  }

  final result = await showDialog<_ReportInput>(
    context: context,
    builder: (_) => _ReportDialog(title: title),
  );
  if (result == null || !context.mounted) return;

  final repo = context.read<ReportRepository>();
  String message;
  try {
    await repo.submitReport(
      Report(
        id: 'rep_${DateTime.now().millisecondsSinceEpoch}_$reporterId',
        targetType: targetType,
        targetId: targetId,
        targetTitle: targetTitle,
        reporterId: reporterId,
        reason: result.reason,
        note: InputSanitizer.sanitize(result.note),
        createdAt: DateTime.now(),
      ),
    );
    message = confirmation;
  } catch (e) {
    debugPrint('submitReport failed: $e');
    message = 'Could not send the report. Please try again.';
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class _ReportInput {
  final String reason;
  final String note;

  const _ReportInput(this.reason, this.note);
}

/// Owns the form state so the controller lives exactly as long as the dialog.
class _ReportDialog extends StatefulWidget {
  final String title;

  const _ReportDialog({required this.title});

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final TextEditingController _noteController = TextEditingController();
  String _reason = Report.reasons.first;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              key: const Key('report_reason_input'),
              initialValue: _reason,
              isExpanded: true,
              items: [
                for (final r in Report.reasons)
                  DropdownMenuItem(value: r, child: Text(r)),
              ],
              onChanged: (v) => setState(() => _reason = v ?? _reason),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('report_note_input'),
              controller: _noteController,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Details (optional)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const Key('submit_report_button'),
          onPressed: () => Navigator.pop(
            context,
            _ReportInput(_reason, _noteController.text),
          ),
          child: const Text('Submit report'),
        ),
      ],
    );
  }
}
