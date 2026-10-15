import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../../core/money.dart';
import '../../core/scan_stats.dart';
import '../../models/scan_record.dart';
import '../../providers/history_provider.dart';
import '../../widgets/screen_header.dart';

/// Page 14: Analytics, Model Accuracy/Confidence, and Denomination breakdown.
class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  double _computeAverageConfidence(List<ScanRecord> records) {
    int totalDetections = 0;
    double confidenceSum = 0.0;

    for (final record in records) {
      for (final detection in record.detections) {
        confidenceSum += detection.confidence;
        totalDetections++;
      }
    }

    if (totalDetections == 0) return 0.0;
    final average = confidenceSum / totalDetections;

    // Normalize: if the model provided 0.0-1.0, convert to percentage (0-100)
    return average <= 1.0 ? average * 100 : average;
  }

  @override
  Widget build(BuildContext context) {
    final records = context.watch<HistoryProvider>().all;
    final stats = computeStats(records);
    final avgConfidence = _computeAverageConfidence(records);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            const ScreenHeader(title: 'Statistics'),
            const SizedBox(height: 20),
            if (stats.isEmpty)
              const _EmptyStats()
            else ...[
              // Hero Card: Model Accuracy & Confidence
              _ConfidenceCard(averageConfidence: avgConfidence),
              const SizedBox(height: 12),

              // Side-by-Side: Items Detected and Scan Sessions
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'ITEMS DETECTED',
                      value: '${stats.items}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: 'SCAN SESSIONS',
                      value: '${stats.sessions}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Denomination Frequency Breakdown
              _FrequencyCard(rows: stats.byDenomination),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConfidenceCard extends StatelessWidget {
  final double averageConfidence;
  const _ConfidenceCard({required this.averageConfidence});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fraction = (averageConfidence / 100).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MODEL CONFIDENCE',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              Icon(Icons.verified_rounded, size: 20, color: c.gold),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                averageConfidence == 0
                    ? '--'
                    : '${averageConfidence.toStringAsFixed(1)}%',
                style: AppText.mono(size: 34, color: c.gold),
              ),
              const SizedBox(width: 10),
              Text(
                'average detection score',
                style: TextStyle(
                  fontSize: 13,
                  color: c.textMuted,
                  fontFamily: AppFonts.body,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Bar(fraction: fraction == 0 ? 0.03 : fraction),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: AppText.mono(size: 26, color: c.gold)),
          ),
        ],
      ),
    );
  }
}

class _FrequencyCard extends StatelessWidget {
  final List<DenominationCount> rows;
  const _FrequencyCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final maxCount =
        rows.first.count; // rows are sorted, so the first is the highest

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Denomination Frequency',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        formatPesoShort(row.valueCentavos),
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: c.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${row.count} ${row.count == 1 ? 'item' : 'items'}',
                        style: AppText.mono(
                          size: 13,
                          weight: FontWeight.w400,
                          color: c.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _Bar(fraction: row.count / maxCount),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A gold bar that animates smoothly to its width on render.
class _Bar extends StatelessWidget {
  final double fraction; // 0..1
  const _Bar({required this.fraction});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 8,
        color: c.chip,
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: fraction.clamp(0.03, 1.0)),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => FractionallySizedBox(
            widthFactor: value,
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: c.goldGradient),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyStats extends StatelessWidget {
  const _EmptyStats();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          Icon(Icons.bar_chart_rounded, size: 56, color: c.textMuted),
          const SizedBox(height: 14),
          Text('No statistics yet', style: text.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Save a scan and your totals will show up here.',
            textAlign: TextAlign.center,
            style: text.bodyMedium,
          ),
        ],
      ),
    );
  }
}
