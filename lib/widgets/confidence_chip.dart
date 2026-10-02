import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_theme.dart';
import '../models/detection.dart';

/// Small coloured pill: "92%", "min 58%" or "Verified".
class ConfidenceChip extends StatelessWidget {
  final ConfidenceLevel level;
  final String label;
  final bool verified;

  const ConfidenceChip({
    super.key,
    required this.level,
    required this.label,
    this.verified = false,
  });

  /// The chip for one detection.
  factory ConfidenceChip.of(Detection d, {Key? key}) => ConfidenceChip(
    key: key,
    level: d.level,
    label: d.verified ? 'Verified' : d.confidencePercent,
    verified: d.verified,
  );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = switch (level) {
      ConfidenceLevel.high => c.success,
      ConfidenceLevel.medium => c.warning,
      ConfidenceLevel.low => c.danger,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (verified) ...[
            Icon(Icons.check_rounded, size: 12, color: color),
            const SizedBox(width: 3),
          ],
          Text(label, style: AppText.mono(size: 11, color: color)),
        ],
      ),
    );
  }
}
