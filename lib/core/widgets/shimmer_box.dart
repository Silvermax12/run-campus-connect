import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Simple shimmer placeholder for image loading states.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 0,
    this.baseColor,
    this.highlightColor,
  });

  final double? width;
  final double height;
  final double borderRadius;
  final Color? baseColor;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final resolvedBase = baseColor ?? (isDark ? Colors.grey.shade800 : Colors.grey.shade300);
    final resolvedHighlight =
        highlightColor ?? (isDark ? Colors.grey.shade700 : Colors.grey.shade100);

    return Shimmer.fromColors(
      baseColor: resolvedBase,
      highlightColor: resolvedHighlight,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

