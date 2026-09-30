import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_images.dart';

// Shows assets/images/<name>.png inside a FIXED-size box.
/// - Too-big pictures are scaled down (BoxFit.contain), never overflow.
/// - If the file doesn't exist yet, `fallback` (or a labelled placeholder)
///   is shown, so you can build the whole app before the artwork is ready.
class AppImage extends StatelessWidget {
  final String name;
  final double width;
  final double height;
  final Widget? fallback;

  const AppImage(
    this.name, {
    super.key,
    required this.width,
    required this.height,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return SizedBox(
      width: width,
      height: height,
      child: Image.asset(
        '${AppImages.folder}$name.${AppImages.ext}',
        fit: BoxFit.contain,
        // Decode at the size we need, so huge files don't waste memory.
        cacheWidth: (width * dpr).round(),
        errorBuilder: (context, error, stack) =>
            fallback ?? _MissingImage(name: name),
      ),
    );
  }
}

class _MissingImage extends StatelessWidget {
  final String name;
  const _MissingImage({required this.name});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.textMuted.withValues(alpha: 0.5)),
      ),
      alignment: Alignment.center,
      child: Text(
        name,
        style: TextStyle(fontSize: 9, color: c.textMuted),
        textAlign: TextAlign.center,
      ),
    );
  }
}
