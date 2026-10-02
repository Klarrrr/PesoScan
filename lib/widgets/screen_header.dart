import 'package:flutter/material.dart';

import '../core/app_colors.dart';

/// Back button + title (+ optional subtitle). Used by Detail, Statistics
/// and, later, the Guide, Help and legal pages.
class ScreenHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  const ScreenHeader({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;

    return Row(
      children: [
        GestureDetector(
          key: const Key('btn-back'),
          onTap: () => Navigator.maybePop(context),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.chip,
              shape: BoxShape.circle,
              border: Border.all(color: c.border),
            ),
            child: Icon(
              Icons.chevron_left_rounded,
              color: c.textSecondary,
              size: 28,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.headlineSmall),
              if (subtitle != null) Text(subtitle!, style: text.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}
