import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../core/app_theme.dart';
import '../../core/money.dart';
import '../../core/scan_math.dart';
import '../../core/time_labels.dart';
import '../../models/scan_record.dart';
import '../../providers/history_provider.dart';
import '../../widgets/confirm_tap_button.dart';
import '../../widgets/gold_button.dart';
import '../../widgets/peso_bottom_bar.dart';
import '../scanner/open_scanner.dart';

/// Page 10 of the prototype.
class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pickRange(HistoryProvider history) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange: history.range,
    );
    if (picked != null && mounted) history.setRange(picked);
  }

  void _clearFilters(HistoryProvider history) {
    _search.clear();
    history.clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final history = context.watch<HistoryProvider>();
    final groups = history.groups;

    // One flat list: a String is a section title, a ScanRecord is a card.
    final entries = <Object>[
      for (final g in groups) ...[g.label, ...g.scans],
    ];

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'History',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                if (history.count > 0)
                  ConfirmTapButton(
                    onConfirmed: history.clearAll,
                    builder: (context, armed) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: armed
                            ? c.danger.withValues(alpha: 0.15)
                            : c.chip,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: armed
                              ? c.danger.withValues(alpha: 0.5)
                              : c.border,
                        ),
                      ),
                      child: Text(
                        armed ? 'Tap again to confirm' : 'Clear All',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: armed ? c.danger : c.textSecondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    onChanged: history.setQuery,
                    cursorColor: c.gold,
                    style: TextStyle(color: c.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search scans...',
                      hintStyle: TextStyle(color: c.textMuted),
                      prefixIcon: Icon(Icons.search, color: c.textMuted),
                      filled: true,
                      fillColor: c.surface,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: c.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: c.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: c.gold, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  key: const Key('btn-date-filter'),
                  onTap: () => _pickRange(history),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: history.range != null
                          ? c.gold.withValues(alpha: 0.15)
                          : c.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: history.range != null ? c.gold : c.border,
                      ),
                    ),
                    child: Icon(
                      Icons.calendar_month_outlined,
                      color: history.range != null ? c.gold : c.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (history.range != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: _RangeChip(
                range: history.range!,
                onClear: () => history.setRange(null),
              ),
            ),
          const SizedBox(height: 14),
          Expanded(
            child: history.count == 0
                ? _EmptyState(
                    icon: Icons.history_rounded,
                    title: 'No scan history yet',
                    message: 'Scans you save will appear here.',
                    buttonLabel: 'Start Scanning',
                    onButton: () => openScanner(context),
                  )
                : entries.isEmpty
                ? _EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No results',
                    message: 'Nothing matches your search or dates.',
                    buttonLabel: 'Clear filters',
                    onButton: () => _clearFilters(history),
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      0,
                      20,
                      PesoBottomBar.totalHeight(context) + 8,
                    ),
                    itemCount: entries.length,
                    itemBuilder: (context, i) {
                      final entry = entries[i];
                      if (entry is String) {
                        return Padding(
                          padding: EdgeInsets.only(
                            top: i == 0 ? 0 : 12,
                            bottom: 8,
                          ),
                          child: Text(
                            entry.toUpperCase(),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        );
                      }
                      final record = entry as ScanRecord;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _HistoryCard(
                          record: record,
                          onOpen: () => Navigator.pushNamed(
                            context,
                            AppRoutes.historyDetail,
                            arguments: record,
                          ),
                          onDelete: () {
                            final messenger = ScaffoldMessenger.of(context);
                            history.delete(record);
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Scan deleted')),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  final DateTimeRange range;
  final VoidCallback onClear;
  const _RangeChip({required this.range, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fmt = DateFormat('MMM d');
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
        decoration: BoxDecoration(
          color: c.chip,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.date_range, size: 16, color: c.gold),
            const SizedBox(width: 6),
            Text(
              '${fmt.format(range.start)} – ${fmt.format(range.end)}',
              style: TextStyle(color: c.textPrimary, fontSize: 13),
            ),
            IconButton(
              key: const Key('btn-clear-range'),
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              padding: EdgeInsets.zero,
              onPressed: onClear,
              icon: Icon(Icons.close, size: 16, color: c.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final ScanRecord record;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  const _HistoryCard({
    required this.record,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final n = record.itemCount;
    final groups = countByClass(record.detections).entries.toList();

    Widget pill(String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.chip,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: AppText.mono(size: 12, color: c.gold)),
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    _Thumbnail(path: record.imagePath),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$n ${n == 1 ? 'item' : 'items'} detected',
                            style: TextStyle(
                              fontFamily: AppFonts.heading,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: c.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final e in groups.take(3))
                                pill('${e.value}×${e.key.shortValue}'),
                              if (groups.length > 3)
                                pill('+${groups.length - 3}'),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            scanTimeLabel(record.createdAt),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatPeso(record.totalCentavos),
                      style: AppText.mono(size: 18, color: c.gold),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Divider(height: 1, color: c.border),
          SizedBox(
            height: 48,
            child: Row(
              children: [
                Expanded(
                  child: ConfirmTapButton(
                    key: Key('delete-${record.id}'),
                    onConfirmed: onDelete,
                    builder: (context, armed) => Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            armed
                                ? Icons.warning_amber_rounded
                                : Icons.delete_outline,
                            size: 18,
                            color: armed ? c.danger : c.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            armed ? 'Tap to confirm' : 'Delete',
                            style: TextStyle(
                              fontSize: 14,
                              color: armed ? c.danger : c.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(width: 1, height: 24, color: c.border),
                Expanded(
                  child: InkWell(
                    onTap: onOpen,
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: c.textSecondary,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'View Detail',
                            style: TextStyle(
                              fontSize: 14,
                              color: c.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final String path;
  const _Thumbnail({required this.path});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fallback = Container(
      color: c.chip,
      alignment: Alignment.center,
      child: Icon(Icons.paid_outlined, color: c.gold, size: 30),
    );

    return SizedBox(
      width: 78,
      height: 78,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: path.isEmpty
            ? fallback
            : Image.file(
                File(path),
                fit: BoxFit.cover,
                cacheWidth: 240, // decode small: the card shows 78 pixels
                errorBuilder: (context, error, stack) => fallback,
              ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback onButton;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onButton,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: c.textMuted),
            const SizedBox(height: 14),
            Text(title, style: text.titleLarge),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center, style: text.bodyMedium),
            const SizedBox(height: 22),
            SizedBox(
              width: 220,
              child: GoldButton(label: buttonLabel, onPressed: onButton),
            ),
          ],
        ),
      ),
    );
  }
}
