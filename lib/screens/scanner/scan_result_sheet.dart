import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../../core/money.dart';
import '../../core/scan_math.dart';
import '../../models/detection.dart';
import '../../models/money_class.dart';
import '../../providers/scanner_provider.dart';
import '../../widgets/confidence_chip.dart';
import '../../widgets/gold_button.dart';
import 'class_picker_sheet.dart';
import 'verify_sheet.dart';

// --- ADDED: discard is now its own distinct action ---
enum ResultAction { saveSession, resume, discard }

class SheetOutcome {
  final ResultAction action;
  final List<Detection> detections;
  final bool wasAdded;
  const SheetOutcome(this.action, this.detections, this.wasAdded);
}

class _Group {
  final MoneyClass money;
  final List<int> indexes;
  const _Group(this.money, this.indexes);
}

class ScanResultSheet extends StatefulWidget {
  final List<Detection> detections;
  final String? tempPath;

  const ScanResultSheet({super.key, required this.detections, this.tempPath});

  static Future<SheetOutcome> show(
    BuildContext context,
    List<Detection> detections,
    String? tempPath,
  ) async {
    final scanner = context.read<ScannerProvider>();

    final result = await showModalBottomSheet<SheetOutcome>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: scanner,
        child: Theme(
          data: AppTheme.dark,
          child: ScanResultSheet(detections: detections, tempPath: tempPath),
        ),
      ),
    );
    return result ?? SheetOutcome(ResultAction.resume, detections, false);
  }

  @override
  State<ScanResultSheet> createState() => _ScanResultSheetState();
}

class _ScanResultSheetState extends State<ScanResultSheet> {
  late final ValueNotifier<List<Detection>> _items = ValueNotifier(
    List.of(widget.detections),
  );
  bool _wasAdded = false;

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
    if (picked == null || !mounted) {
      return;
    }
    final list = List.of(_items.value);
    list[i] = list[i].copyWith(money: picked, verified: true);
    _items.value = list;
  }

  void _remove(int i) {
    _items.value = List.of(_items.value)..removeAt(i);
  }

  void _finish(ResultAction action) =>
      Navigator.pop(context, SheetOutcome(action, _items.value, _wasAdded));

  void _addCurrentToTotal() {
    if (_wasAdded || _items.value.isEmpty) {
      return;
    }
    final scanner = context.read<ScannerProvider>();

    if (widget.tempPath != null) {
      scanner.addCurrentFrameToTotal(widget.tempPath!, _items.value);
    }

    setState(() {
      _wasAdded = true;
    });
  }

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

    final scanner = context.watch<ScannerProvider>();
    final runningTotal = scanner.runningTotalCentavos;

    return PopScope(
      canPop: false,
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
              final currentScanTotal = totalCentavos(items);

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
                            Text('CURRENT SCAN', style: text.labelSmall),
                            Text(
                              formatPeso(currentScanTotal),
                              style: AppText.mono(size: 32, color: c.gold),
                            ),
                          ],
                        ),
                      ],
                    ),

                    if (runningTotal > 0) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF060F1F),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: c.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Running Total:',
                              style: TextStyle(color: c.textSecondary),
                            ),
                            Text(
                              formatPeso(runningTotal),
                              style: TextStyle(
                                color: c.gold,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

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
                          child: OutlinedButton.icon(
                            onPressed: () => _finish(ResultAction.resume),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Scan Again'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                              side: BorderSide(color: c.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GoldButton(
                            label: _wasAdded ? 'Added ✓' : 'Add to Total',
                            onPressed: _wasAdded || items.isEmpty
                                ? null
                                : _addCurrentToTotal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: items.isEmpty && runningTotal == 0
                          ? null
                          : () {
                              if (!_wasAdded) {
                                _addCurrentToTotal();
                              }
                              _finish(ResultAction.saveSession);
                            },
                      icon: Icon(Icons.save_alt, color: c.textPrimary),
                      label: Text(
                        'Save Session to History',
                        style: TextStyle(color: c.textPrimary, fontSize: 16),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        side: BorderSide(color: c.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),

                    // --- FIXED: Both buttons now show up correctly ---
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Discard always shows up now
                        TextButton.icon(
                          onPressed: () => _finish(ResultAction.discard),
                          icon: Icon(Icons.close, color: c.textMuted, size: 18),
                          label: Text(
                            'Discard & Exit',
                            style: TextStyle(color: c.textMuted),
                          ),
                        ),

                        // Reset Total only shows up if there is a running total to reset
                        if (runningTotal > 0)
                          TextButton.icon(
                            onPressed: () {
                              scanner.resetRunningTotal();
                              setState(() => _wasAdded = false);
                            },
                            icon: Icon(
                              Icons.delete_outline,
                              color: c.danger,
                              size: 18,
                            ),
                            label: Text(
                              'Reset Total',
                              style: TextStyle(color: c.danger),
                            ),
                          ),
                      ],
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
  final int value;
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
