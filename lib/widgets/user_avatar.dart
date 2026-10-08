import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../core/app_theme.dart';
import '../providers/avatar_provider.dart';

/// The round account picture: the user's photo, or their initial on gold.
/// It reads the picture from [AvatarProvider] by itself (and quietly shows
/// the initial when there is no provider, for example in tests).
class UserAvatar extends StatelessWidget {
  final String name;
  final double size;

  /// Shows a small camera badge ("you can change this").
  final bool showEditBadge;

  /// Use this picture instead of the provider's (mainly for tests).
  final String? photoPath;

  const UserAvatar({
    super.key,
    required this.name,
    this.size = 50,
    this.showEditBadge = false,
    this.photoPath,
  });

  String? _providerPath(BuildContext context) {
    try {
      return context.watch<AvatarProvider>().path;
    } on ProviderNotFoundException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final path = photoPath ?? _providerPath(context);
    final trimmed = name.trim();
    final initial = trimmed.isEmpty
        ? '?'
        : trimmed.characters.first.toUpperCase();

    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: c.goldGradient,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontFamily: AppFonts.heading,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.42,
          color: c.onGold,
        ),
      ),
    );

    final Widget avatar = path == null
        ? fallback
        : ClipOval(
            child: Image.file(
              File(path),
              width: size,
              height: size,
              fit: BoxFit.cover,
              cacheWidth: (size * 3).round(), // decode small, not full size
              errorBuilder: (context, error, stack) => fallback,
            ),
          );

    if (!showEditBadge) return avatar;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: c.surface,
                shape: BoxShape.circle,
                border: Border.all(color: c.border),
              ),
              child: Icon(Icons.photo_camera_rounded, size: 14, color: c.gold),
            ),
          ),
        ],
      ),
    );
  }
}
