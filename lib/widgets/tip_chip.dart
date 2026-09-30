import 'package:flutter/material.dart';

import '../core/app_colors.dart';

/// The little "💡 tip" pill under each onboarding page.
class TipChip extends StatelessWidget {
  final String text;
  const TipChip(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: c.chip,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lightbulb, size: 16, color: c.gold),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: c.gold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
