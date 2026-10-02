import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../../models/money_class.dart';

/// "What is it really?" Lists every class the app knows, coins then bills.
class ClassPickerSheet extends StatelessWidget {
  final MoneyClass? current;
  const ClassPickerSheet({super.key, this.current});

  static Future<MoneyClass?> show(BuildContext context, {MoneyClass? current}) {
    return showModalBottomSheet<MoneyClass>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ClassPickerSheet(current: current),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;

    Widget section(String label) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
      child: Text(label, style: text.labelSmall),
    );

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF0A1D3A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: c.textMuted.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text('Choose the correct item', style: text.titleLarge),
          const SizedBox(height: 4),
          Text('Pick what is really in the picture.', style: text.bodyMedium),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                section('COINS'),
                for (final m in MoneyClasses.coins)
                  _PickTile(money: m, selected: m == current),
                section('BILLS'),
                for (final m in MoneyClasses.bills)
                  _PickTile(money: m, selected: m == current),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PickTile extends StatelessWidget {
  final MoneyClass money;
  final bool selected;
  const _PickTile({required this.money, required this.selected});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? c.gold.withValues(alpha: 0.12)
            : const Color(0xFF101B38),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: Key('pick-class-${money.id}'),
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.pop(context, money),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: c.chip,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: FittedBox(
                    child: Text(
                      money.shortValue,
                      style: AppText.mono(size: 14, color: c.gold),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${money.shortValue} ${money.design}',
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: c.textPrimary,
                        ),
                      ),
                      Text(
                        money.notes.isEmpty
                            ? money.typeLabel
                            : '${money.typeLabel} · ${money.notes}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (selected) Icon(Icons.check_circle, color: c.gold),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
