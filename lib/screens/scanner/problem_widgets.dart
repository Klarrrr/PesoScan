import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../../widgets/gold_button.dart';

/// Something is wrong while scanning (the model is missing, or the camera
/// picture cannot be read). Has a "Try again" button.
class ScanProblemCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  const ScanProblemCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.80),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.danger.withValues(alpha: 0.55)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: c.danger, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 14),
          GoldButton(
            key: const Key('btn-retry'),
            label: retryLabel,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

/// Nothing found for a while: tells the user what to do.
class EmptyScanCard extends StatelessWidget {
  final VoidCallback onHelp;
  const EmptyScanCard({super.key, required this.onHelp});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      key: const Key('card-empty'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.warning.withValues(alpha: 0.55)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.search_off_rounded, color: c.warning, size: 22),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'No coins or bills found',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              'Put them flat on a plain surface, inside the gold corners, '
              'with good light.',
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const Key('btn-empty-help'),
              onPressed: onHelp,
              child: Text('How to scan', style: TextStyle(color: c.gold)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small badge shown while the detections are invented.
class DemoBadge extends StatelessWidget {
  final String reason;
  const DemoBadge({super.key, required this.reason});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      key: const Key('badge-demo'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: c.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.warning.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.science_outlined, size: 14, color: c.warning),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'DEMO MODE - $reason',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.mono(
                size: 11,
                weight: FontWeight.w600,
                color: c.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
