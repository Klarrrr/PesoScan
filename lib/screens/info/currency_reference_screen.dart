import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_images.dart';
import '../../core/app_theme.dart';
import '../../data/currency_reference.dart';
import '../../models/money_class.dart';
import '../../widgets/app_image.dart';
import '../../widgets/gold_button.dart';
import '../../widgets/screen_header.dart';

/// Pages 16-19 of the prototype.
class CurrencyReferenceScreen extends StatefulWidget {
  const CurrencyReferenceScreen({super.key});

  @override
  State<CurrencyReferenceScreen> createState() =>
      _CurrencyReferenceScreenState();
}

class _CurrencyReferenceScreenState extends State<CurrencyReferenceScreen> {
  int _tab = 0; // 0 = coins, 1 = bills

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            children: [
              const ScreenHeader(
                title: 'Currency Reference',
                subtitle: 'Coins & bills supported by PesoScan',
              ),
              const SizedBox(height: 16),
              const _InfoCard(),
              const SizedBox(height: 14),
              _Tabs(
                selected: _tab,
                coinCount: MoneyClasses.coins.length,
                billCount: MoneyClasses.bills.length,
                onChanged: (i) => setState(() => _tab = i),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _tab == 0
                      ? const _CoinGrid(key: ValueKey('coins'))
                      : const _BillList(key: ValueKey('bills')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.chip,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(Icons.bolt_rounded, color: c.gold, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: Theme.of(context).textTheme.bodyMedium,
                children: [
                  const TextSpan(text: 'Detected by '),
                  TextSpan(
                    text: 'YOLO26',
                    style: TextStyle(
                      color: c.gold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const TextSpan(
                    text: '. Use this guide to verify uncertain detections.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  final int selected;
  final int coinCount;
  final int billCount;
  final ValueChanged<int> onChanged;

  const _Tabs({
    required this.selected,
    required this.coinCount,
    required this.billCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    Widget tab(Key key, int index, IconData icon, String label) {
      final active = selected == index;
      return Expanded(
        child: GestureDetector(
          key: key,
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 46,
            decoration: BoxDecoration(
              gradient: active ? c.goldGradient : null,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: active ? c.onGold : c.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: active ? c.onGold : c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          tab(
            const Key('tab-coins'),
            0,
            Icons.toll_outlined,
            'Coins ($coinCount)',
          ),
          tab(
            const Key('tab-bills'),
            1,
            Icons.payments_outlined,
            'Bills ($billCount)',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- coins

class _CoinGrid extends StatelessWidget {
  const _CoinGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final coins = MoneyClasses.coins;

    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.64,
      ),
      itemCount: coins.length,
      itemBuilder: (context, i) => _CoinCard(money: coins[i]),
    );
  }
}

class _CoinCard extends StatelessWidget {
  final MoneyClass money;
  const _CoinCard({required this.money});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final info = referenceFor(money.id);

    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: c.border),
      ),
      child: InkWell(
        key: Key('ref-${money.id}'),
        borderRadius: BorderRadius.circular(20),
        onTap: () => _ReferenceSheet.show(context, money),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
          child: Column(
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: c.gold.withValues(alpha: 0.12),
                      blurRadius: 22,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: AppImage(
                  AppImages.forClass(money.id),
                  width: 84,
                  height: 84,
                  fallback: _Fallback(label: money.shortValue, circle: true),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                money.shortValue,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              _DesignPill(money.design),
              const SizedBox(height: 4),
              Text(
                info.period,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Flexible(
                child: Text(
                  info.look,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: c.textSecondary,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- bills

class _BillList extends StatelessWidget {
  const _BillList({super.key});

  @override
  Widget build(BuildContext context) {
    final bills = MoneyClasses.bills;

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: bills.length,
      separatorBuilder: (context, i) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _BillRow(money: bills[i]),
    );
  }
}

class _BillRow extends StatelessWidget {
  final MoneyClass money;
  const _BillRow({required this.money});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final info = referenceFor(money.id);

    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: c.border),
      ),
      child: InkWell(
        key: Key('ref-${money.id}'),
        borderRadius: BorderRadius.circular(18),
        onTap: () => _ReferenceSheet.show(context, money),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AppImage(
                  AppImages.forClass(money.id),
                  width: 128,
                  height: 64, // the pictures are 2:1
                  fallback: _Fallback(label: money.shortValue),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          money.shortValue,
                          style: TextStyle(
                            fontFamily: AppFonts.heading,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: c.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(child: _DesignPill(money.design)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      info.period,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      info.look,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: c.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- shared

class _DesignPill extends StatelessWidget {
  final String text;
  const _DesignPill(this.text);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: c.chip,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: c.gold,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Shown when the image file for a class does not exist yet.
class _Fallback extends StatelessWidget {
  final String label;
  final bool circle;
  const _Fallback({required this.label, this.circle = false});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.chip,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(label, style: AppText.mono(size: 16, color: c.gold)),
    );
  }
}

/// The larger view when you tap an item.
class _ReferenceSheet extends StatelessWidget {
  final MoneyClass money;
  const _ReferenceSheet({required this.money});

  static Future<void> show(BuildContext context, MoneyClass money) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReferenceSheet(money: money),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final info = referenceFor(money.id);

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
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
              Center(
                child: AppImage(
                  AppImages.forClass(money.id),
                  width: money.isCoin ? 180 : 280,
                  height: money.isCoin ? 180 : 140,
                  fallback: _Fallback(
                    label: money.shortValue,
                    circle: money.isCoin,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                money.displayName,
                textAlign: TextAlign.center,
                style: text.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                '${money.typeLabel} · ${info.period}',
                textAlign: TextAlign.center,
                style: text.bodyMedium,
              ),
              const SizedBox(height: 10),
              Text(
                info.look,
                textAlign: TextAlign.center,
                style: text.bodyLarge,
              ),
              const SizedBox(height: 10),
              Text(
                'App class ${money.id} · model index ${money.yoloIndex}',
                textAlign: TextAlign.center,
                style: AppText.mono(
                  size: 11,
                  weight: FontWeight.w400,
                  color: c.textMuted,
                ),
              ),
              const SizedBox(height: 18),
              GoldButton(
                label: 'Close',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
