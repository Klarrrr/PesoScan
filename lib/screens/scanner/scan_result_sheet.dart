import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../../core/money.dart';
import '../../core/scan_math.dart';
import '../../models/detection.dart';
import '../../widgets/gold_button.dart';

enum ResultAction { save, discard }

/// Page 9 of the prototype: the bottom sheet shown after capturing.
class ScanResultSheet extends StatelessWidget {
  final List<Detection> detections;
  const ScanResultSheet({super.key, required this.detections});

  /// Shows the sheet and waits for a choice. It cannot be swiped away,
  /// so the answer is always Save or Discard.
  static Future<ResultAction> show(
    BuildContext context,
    List<Detection> detections,
  ) async {
    final result = await showModalBottomSheet<ResultAction>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => ScanResultSheet(detections: detections),
    );
    return result ?? ResultAction.discard;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;

    final counts = countByClass(detections);
    final total = totalCentavos(detections);
    final n = detections.length;
    final hasLow = detections.any((d) => d.isLowConfidence);
    final maxListHeight = MediaQuery.sizeOf(context).height * 0.38;

    // canPop: false = the Android Back button cannot close the sheet.
    return PopScope(
      canPop: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0A1D3A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle
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
                const SizedBox(height: 18),
                // Title and total
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Scan Result', style: text.headlineSmall),
                          const SizedBox(height: 2),
                          Text(
                            '$n ${n == 1 ? 'item' : 'items'} detected',
                            style: text.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('TOTAL', style: text.labelSmall),
                        Text(
                          formatPeso(total),
                          style: AppText.mono(size: 32, color: c.gold),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (hasLow) ...[
                  _LowConfidenceBanner(color: c.danger),
                  const SizedBox(height: 12),
                ],
                // The breakdown
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: c.border),
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxListHeight),
                    child: ListView(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      children: [
                        for (final (index, entry) in counts.entries.indexed)
                          _BreakdownRow(
                            key: Key('result-row-${entry.key.id}'),
                            shaded: index.isEven,
                            quantity: entry.value,
                            title: entry.key.shortValue,
                            subtitle:
                                '${entry.key.design} · ${entry.key.typeLabel}',
                            value: entry.key.valueCentavos * entry.value,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: SoftButton(
                        label: 'Discard',
                        onPressed: () =>
                            Navigator.pop(context, ResultAction.discard),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: GoldButton(
                        label: 'Save to History',
                        onPressed: () =>
                            Navigator.pop(context, ResultAction.save),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LowConfidenceBanner extends StatelessWidget {
  final Color color;
  const _LowConfidenceBanner({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Some items have low confidence. Verify manually.',
              style: TextStyle(color: color, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final bool shaded;
  final int quantity;
  final String title;
  final String subtitle;
  final int value; // centavos

  const _BreakdownRow({
    super.key,
    required this.shaded,
    required this.quantity,
    required this.title,
    required this.subtitle,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      color: shaded ? const Color(0xFF101B38) : const Color(0xFF0C1930),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: c.chip, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              '$quantity×',
              style: AppText.mono(size: 13, color: c.gold),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: c.textPrimary,
                  ),
                ),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Text(
            formatPeso(value),
            style: AppText.mono(size: 15, color: c.textPrimary),
          ),
        ],
      ),
    );
  }
}
