import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import 'gold_button.dart';

enum PhotoChoice { gallery, camera, remove }

/// "Profile photo": choose from gallery, take a photo, or remove it.
class PhotoOptionsSheet extends StatelessWidget {
  final bool hasPhoto;
  const PhotoOptionsSheet({super.key, required this.hasPhoto});

  /// Returns the choice, or null if the user cancelled.
  static Future<PhotoChoice?> show(
    BuildContext context, {
    required bool hasPhoto,
  }) {
    return showModalBottomSheet<PhotoChoice>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => PhotoOptionsSheet(hasPhoto: hasPhoto),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.textMuted.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Profile photo', style: text.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Pick a picture for your account. It stays on this phone.',
                style: text.bodyMedium,
              ),
              const SizedBox(height: 10),
              _Option(
                key: const Key('photo-gallery'),
                icon: Icons.photo_library_outlined,
                label: 'Choose from gallery',
                onTap: () => Navigator.pop(context, PhotoChoice.gallery),
              ),
              _Option(
                key: const Key('photo-camera'),
                icon: Icons.photo_camera_outlined,
                label: 'Take a photo',
                onTap: () => Navigator.pop(context, PhotoChoice.camera),
              ),
              if (hasPhoto)
                _Option(
                  key: const Key('photo-remove'),
                  icon: Icons.delete_outline,
                  label: 'Remove',
                  color: c.danger,
                  onTap: () => Navigator.pop(context, PhotoChoice.remove),
                ),
              const SizedBox(height: 8),
              SoftButton(
                label: 'Cancel',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _Option({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color ?? c.textSecondary),
            const SizedBox(width: 16),
            // Expanded + ellipsis: a long label shortens instead of overflowing.
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16, color: color ?? c.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
