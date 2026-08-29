import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../features/navigation/main_navigation_screen.dart';

/// A global error boundary widget that catches render and build exceptions in its child tree,
/// displaying a clean, user-friendly Ghanaian-styled recovery interface with "Try Again"
/// and "Go Home" actions.
class GlobalErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(BuildContext context, FlutterErrorDetails? details, VoidCallback retry)? errorBuilder;
  final void Function(Object error, StackTrace stack)? onError;

  const GlobalErrorBoundary({
    super.key,
    required this.child,
    this.errorBuilder,
    this.onError,
  });

  @override
  State<GlobalErrorBoundary> createState() => GlobalErrorBoundaryState();
}

class GlobalErrorBoundaryState extends State<GlobalErrorBoundary> {
  FlutterErrorDetails? _errorDetails;

  /// Catch and display an error programmatically.
  void catchError(FlutterErrorDetails details) {
    setState(() {
      _errorDetails = details;
    });
    widget.onError?.call(details.exception, details.stack ?? StackTrace.current);
  }

  /// Clear the error and trigger a full rebuild of the child widget tree.
  void retry() {
    setState(() {
      _errorDetails = null;
    });
  }

  /// Reset error and navigate to the application's root home screen.
  void goHome(BuildContext context) {
    setState(() {
      _errorDetails = null;
    });
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_errorDetails != null) {
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(context, _errorDetails, retry);
      }
      return GlobalErrorDisplay(
        details: _errorDetails,
        onRetry: retry,
        onGoHome: () => goHome(context),
      );
    }

    return widget.child;
  }
}

/// Standalone display widget used by [GlobalErrorBoundary] and [ErrorWidget.builder].
class GlobalErrorDisplay extends StatefulWidget {
  final FlutterErrorDetails? details;
  final VoidCallback? onRetry;
  final VoidCallback? onGoHome;

  const GlobalErrorDisplay({
    super.key,
    this.details,
    this.onRetry,
    this.onGoHome,
  });

  @override
  State<GlobalErrorDisplay> createState() => _GlobalErrorDisplayState();
}

class _GlobalErrorDisplayState extends State<GlobalErrorDisplay> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Error Icon Badge
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.red.shade200, width: 2),
                  ),
                  child: Icon(
                    Icons.error_outline_rounded,
                    size: 44,
                    color: Colors.red.shade600,
                  ),
                ),
                const SizedBox(height: 20),

                // Friendly Title
                const Text(
                  'Something Went Wrong',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 10),

                // Explanatory Message
                const Text(
                  'An unexpected error occurred while loading this view. Your saved data remains safe.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // Recovery Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.onRetry != null)
                      Expanded(
                        child: ElevatedButton.icon(
                          key: const Key('global_error_retry_button'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: widget.onRetry,
                          icon: const Icon(Icons.refresh, size: 20),
                          label: const Text(
                            'Try Again',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    if (widget.onRetry != null && widget.onGoHome != null)
                      const SizedBox(width: 12),
                    if (widget.onGoHome != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('global_error_home_button'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                            side: const BorderSide(color: AppTheme.primaryColor),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: widget.onGoHome,
                          icon: const Icon(Icons.home_outlined, size: 20),
                          label: const Text(
                            'Go Home',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 24),

                // Collapsible Diagnostics (Debug Only or Toggleable)
                if (kDebugMode && widget.details != null) ...[
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _showDetails = !_showDetails;
                      });
                    },
                    icon: Icon(
                      _showDetails ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: AppTheme.textMuted,
                    ),
                    label: Text(
                      _showDetails ? 'Hide Error Details' : 'Show Error Details',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ),
                  if (_showDetails)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: SelectableText(
                        widget.details!.exceptionAsString(),
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: Colors.red.shade900,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
