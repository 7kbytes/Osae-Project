import 'package:flutter/material.dart';
import '../../app/theme.dart';

/// A crash-resilient image widget that safely displays network images with
/// loading placeholders and error fallbacks for offline, missing, or malformed URLs.
class SafeNetworkImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? fallbackWidget;
  final Widget? placeholder;
  final BorderRadius? borderRadius;
  final IconData defaultFallbackIcon;

  const SafeNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.fallbackWidget,
    this.placeholder,
    this.borderRadius,
    this.defaultFallbackIcon = Icons.image_not_supported_outlined,
  });

  Widget _buildFallback() {
    if (fallbackWidget != null) {
      return fallbackWidget!;
    }
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade200,
      alignment: Alignment.center,
      child: Icon(
        defaultFallbackIcon,
        color: AppTheme.textMuted,
        size: (width != null && height != null) ? (width! < height! ? width! * 0.5 : height! * 0.5) : 24,
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
    if (loadingProgress == null) return child;
    if (placeholder != null) return placeholder!;

    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade100,
      alignment: Alignment.center,
      child: CircularProgressIndicator(
        value: loadingProgress.expectedTotalBytes != null
            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
            : null,
        strokeWidth: 2,
        color: AppTheme.primaryColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Validate URL
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty || (!url.startsWith('http://') && !url.startsWith('https://'))) {
      final fallback = _buildFallback();
      if (borderRadius != null) {
        return ClipRRect(borderRadius: borderRadius!, child: fallback);
      }
      return fallback;
    }

    Widget image = Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: _buildPlaceholder,
      errorBuilder: (context, error, stackTrace) => _buildFallback(),
    );

    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }

    return image;
  }
}

/// Alias for [SafeNetworkImage].
typedef SafeImage = SafeNetworkImage;
