import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../../core/money.dart';
import '../../core/scan_math.dart';
import '../../models/detection.dart';
import '../../models/money_class.dart';
import '../../widgets/confidence_chip.dart';
import '../../widgets/gold_button.dart';
import 'class_picker_sheet.dart';
import 'verify_sheet.dart';

enum ResultAction { save, rescan, discard }

/// What the user decided, plus the (possibly corrected) list of items.
class ScanResultOutcome {
  final ResultAction action;
  final List<Detection> detections;
  const ScanResultOutcome(this.action, this.detections);
}

class _Group {
  final MoneyClass money;
  final List<int> indexes; // positions in the item list
  const _Group(this.money, this.indexes);
}

/// Page 9 of the prototype: the bottom sheet shown after capturing.
class ScanResultSheet extends StatefulWidget {
  final List<Detection> detections;
  const ScanResultSheet({super.key, required this.detections});

  /// Shows the sheet and waits for a choice. It cannot be swiped away.
  static Future<ScanResultOutcome> show(
    BuildContext context,
    List<Detection> detections,
  ) async {
    final result = await showModalBottomSheet<ScanResultOutcome>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => ScanResultSheet(detections: detections),
    );
    return result ?? ScanResultOutcome(ResultAction.discard, detections);
  }

  @override
  State<ScanResultSheet> createState() => _ScanResultSheetState();
}

class _ScanResultSheetState extends State<ScanResultSheet> {
  // The working copy: the user may correct it before saving.
  late final ValueNotifier<List<Detection>> _items = ValueNotifier(
    List.of(widget.detections),
  );

  @override
  void dispose() {
    _items.dispose();
    super.dispose();
  }

  void _confirm(int i) {
    final list = List.of(_items.value);
    list[i] = list[i].copyWith(verified: true);
    _items.value = list;
  }

  Future<void> _change(int i) async {
    final picked = await ClassPickerSheet.show(
      context,
      current: _items.value[i].money,
    );
    if (picked == null || !mounted) return;
    final list = List.of(_items.value);
    list[i] = list[i].copyWith(money: picked, verified: true);
    _items.value = list;
  }

  void _remove(int i) {
    _items.value = List.of(_items.value)..removeAt(i);
  }

  void _finish(ResultAction action) =>
      Navigator.pop(context, ScanResultOutcome(action, _items.value));

  List<_Group> _groups(List<Detection> items) {
    final map = <int, List<int>>{};
    for (var i = 0; i < items.length; i++) {
      map.putIfAbsent(items[i].money.id, () => []).add(i);
    }
    final groups = [
      for (final e in map.entries) _Group(MoneyClasses.byId(e.key), e.value),
    ];
    groups.sort((a, b) {
      final byValue = b.money.valueCentavos.compareTo(a.money.valueCentavos);
      return byValue != 0 ? byValue : a.money.id.compareTo(b.money.id);
    });
    return groups;
  }

  Widget _groupChip(List<Detection> items, _Group group) {
    final members = [for (final i in group.indexes) items[i]];
    final unverified = members.where((d) => !d.verified).toList();
    if (unverified.isEmpty) {
      return const ConfidenceChip(
        level: ConfidenceLevel.high,
        label: 'Verified',
        verified: true,
      );
    }
    // Show the weakest item, so one doubtful coin is never hidden.
    final worst = unverified.reduce(
      (a, b) => a.confidence <= b.confidence ? a : b,
    );
    final label = unverified.length > 1
        ? 'min ${worst.confidencePercent}'
        : worst.confidencePercent;
    return ConfidenceChip(level: worst.level, label: label);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final maxListHeight = MediaQuery.sizeOf(context).height * 0.36;

    return PopScope(
      canPop: false, // the Back button cannot close the sheet
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0A1D3A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: ValueListenableBuilder<List<Detection>>(
            valueListenable: _items,
            builder: (context, items, _) {
              final groups = _groups(items);
              final n = items.length;
              final hasLow = items.any((d) => d.isLowConfidence);

              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
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
                    const SizedBox(height: 18),
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
                              formatPeso(totalCentavos(items)),
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
                    if (items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No items left. Rescan, or discard this scan.',
                          textAlign: TextAlign.center,
                          style: text.bodyMedium,
                        ),
                      )
                    else ...[
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
                              for (final (index, g) in groups.indexed)
                                _BreakdownRow(
                                  key: Key('result-row-${g.money.id}'),
                                  shaded: index.isEven,
                                  quantity: g.indexes.length,
                                  title: g.money.shortValue,
                                  subtitle:
                                      '${g.money.design} · ${g.money.typeLabel}',
                                  value:
                                      g.money.valueCentavos * g.indexes.length,
                                  chip: _groupChip(items, g),
                                  onTap: () => VerifySheet.show(
                                    context,
                                    items: _items,
                                    classId: g.money.id,
                                    onConfirm: _confirm,
                                    onChange: _change,
                                    onRemove: _remove,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap an item to check or correct it.',
                        textAlign: TextAlign.center,
                        style: text.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: SoftButton(
                            label: 'Discard',
                            onPressed: () => _finish(ResultAction.discard),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: GoldButton(
                            label: 'Save to History',
                            onPressed: items.isEmpty
                                ? null
                                : () => _finish(ResultAction.save),
                          ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      key: const Key('btn-rescan'),
                      onPressed: () => _finish(ResultAction.rescan),
                      icon: Icon(
                        Icons.refresh_rounded,
                        size: 18,
                        color: c.gold,
                      ),
                      label: Text(
                        'Not right? Rescan',
                        style: TextStyle(color: c.gold),
                      ),
                    ),
                  ],
                ),
              );
            },
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
  final Widget chip;
  final VoidCallback onTap;

  const _BreakdownRow({
    super.key,
    required this.shaded,
    required this.quantity,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.chip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Material(
      color: shaded ? const Color(0xFF101B38) : const Color(0xFF0C1930),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c.chip,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$quantity×',
                  style: AppText.mono(size: 13, color: c.gold),
                ),
              ),
              const SizedBox(width: 12),
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
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatPeso(value),
                    style: AppText.mono(size: 15, color: c.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  chip,
                ],
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: c.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
