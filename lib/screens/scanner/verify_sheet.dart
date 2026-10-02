import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../models/detection.dart';
import '../../models/money_class.dart';
import '../../widgets/confidence_chip.dart';
import '../../widgets/gold_button.dart';

/// Lists the individual items of one group (for example all the ₱10 BSP
/// coins) so each can be confirmed, changed or removed.
/// It reads the same list the result sheet owns, so both stay in sync.
class VerifySheet extends StatefulWidget {
  final ValueNotifier<List<Detection>> items;
  final int classId;
  final void Function(int index) onConfirm;
  final void Function(int index) onChange;
  final void Function(int index) onRemove;

  const VerifySheet({
    super.key,
    required this.items,
    required this.classId,
    required this.onConfirm,
    required this.onChange,
    required this.onRemove,
  });

  static Future<void> show(
    BuildContext context, {
    required ValueNotifier<List<Detection>> items,
    required int classId,
    required void Function(int index) onConfirm,
    required void Function(int index) onChange,
    required void Function(int index) onRemove,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VerifySheet(
        items: items,
        classId: classId,
        onConfirm: onConfirm,
        onChange: onChange,
        onRemove: onRemove,
      ),
    );
  }

  @override
  State<VerifySheet> createState() => _VerifySheetState();
}

class _VerifySheetState extends State<VerifySheet> {
  bool _closing = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final money = MoneyClasses.byId(widget.classId);

    return ValueListenableBuilder<List<Detection>>(
      valueListenable: widget.items,
      builder: (context, list, _) {
        final indexes = [
          for (var i = 0; i < list.length; i++)
            if (list[i].money.id == widget.classId) i,
        ];

        // Everything in this group was changed or removed: close by itself.
        if (indexes.isEmpty) {
          if (!_closing) {
            _closing = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) Navigator.pop(context);
            });
          }
          return const SizedBox.shrink();
        }

        return Container(
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
                  const SizedBox(height: 16),
                  Text('Verify items', style: text.titleLarge),
                  const SizedBox(height: 2),
                  Text(
                    '${money.shortValue} ${money.design} · ${money.typeLabel}',
                    style: text.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '✓ looks right    ✎ change it    🗑 not a coin or bill',
                    style: text.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.45,
                    ),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final (n, i) in indexes.indexed)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF101B38),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                ConfidenceChip.of(list[i]),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Item ${n + 1}',
                                    style: TextStyle(color: c.textPrimary),
                                  ),
                                ),
                                IconButton(
                                  key: Key('verify-confirm-$i'),
                                  tooltip: 'Looks right',
                                  onPressed: () => widget.onConfirm(i),
                                  icon: Icon(
                                    Icons.check_circle_outline,
                                    color: list[i].verified
                                        ? c.success
                                        : c.textSecondary,
                                  ),
                                ),
                                IconButton(
                                  key: Key('verify-change-$i'),
                                  tooltip: 'Change',
                                  onPressed: () => widget.onChange(i),
                                  icon: Icon(
                                    Icons.edit_outlined,
                                    color: c.textSecondary,
                                  ),
                                ),
                                IconButton(
                                  key: Key('verify-remove-$i'),
                                  tooltip: 'Remove',
                                  onPressed: () => widget.onRemove(i),
                                  icon: Icon(
                                    Icons.delete_outline,
                                    color: c.danger,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  GoldButton(
                    label: 'Done',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
