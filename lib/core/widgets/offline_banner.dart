import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connectivity_provider.dart';

/// A prominent, animated banner widget that automatically displays when
/// the application loses network connectivity, indicating offline mode and local caching.
class OfflineBanner extends StatelessWidget {
  final Widget child;
  final String offlineMessage;
  final bool showDismiss;

  const OfflineBanner({
    super.key,
    required this.child,
    this.offlineMessage = 'Offline Mode — browsing cached jobs. Changes will sync when connected.',
    this.showDismiss = false,
  });

  @override
  Widget build(BuildContext context) {
    ConnectivityProvider? connectivityProvider;
    try {
      connectivityProvider = Provider.of<ConnectivityProvider>(context);
    } catch (_) {
      connectivityProvider = null;
    }

    final isOnline = connectivityProvider?.isOnline ?? true;

    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: !isOnline
              ? Container(
                  key: const Key('offline_banner_container'),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade800,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    bottom: false,
                    top: false,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.cloud_off_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            offlineMessage,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        Expanded(child: child),
      ],
    );
  }
}
