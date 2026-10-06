import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../data/legal_content.dart';
import 'gold_button.dart';

/// The empty box that fills with a check mark when it is ticked.
class CheckBoxMark extends StatelessWidget {
  final bool checked;
  final bool error;
  const CheckBoxMark({super.key, required this.checked, this.error = false});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final border = error ? c.danger : (checked ? c.gold : c.textMuted);

    return Semantics(
      checked: checked,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: checked ? c.gold : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: border, width: 1.8),
        ),
        child: checked
            ? Icon(Icons.check_rounded, size: 18, color: c.onGold)
            : null,
      ),
    );
  }
}

/// The row under the Login and Create Account forms:
/// [box]  I agree to the  Terms of Service & Privacy Policy
/// The gold text is ONE button that opens the [LegalPanel].
class AgreementField extends StatelessWidget {
  final bool agreed;
  final bool showError;
  final ValueChanged<bool> onChanged;

  const AgreementField({
    super.key,
    required this.agreed,
    required this.showError,
    required this.onChanged,
  });

  Future<void> _openPanel(BuildContext context) async {
    final result = await LegalPanel.show(context, agreed: agreed);
    onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasError = showError && !agreed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              key: const Key('agree-box'),
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(!agreed),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 6, 10, 6),
                child: CheckBoxMark(checked: agreed, error: hasError),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'I agree to the ',
                      style: TextStyle(color: c.textSecondary, fontSize: 14),
                    ),
                    GestureDetector(
                      key: const Key('btn-legal'),
                      onTap: () => _openPanel(context),
                      child: Text(
                        'Terms of Service & Privacy Policy',
                        style: TextStyle(
                          color: c.gold,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          decorationColor: c.gold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'Please agree to the Terms of Service and Privacy Policy to continue.',
              style: TextStyle(color: c.danger, fontSize: 12),
            ),
          ),
      ],
    );
  }
}

/// The floating panel. Header: two tabs. Terms of Service is open first.
/// Bottom: the agree box and a Done button.
class LegalPanel extends StatefulWidget {
  final bool agreed;
  const LegalPanel({super.key, required this.agreed});

  /// Opens the panel and returns whether the box was ticked when it closed.
  static Future<bool> show(BuildContext context, {required bool agreed}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => LegalPanel(agreed: agreed),
    );
    return result ?? agreed;
  }

  @override
  State<LegalPanel> createState() => _LegalPanelState();
}

class _LegalPanelState extends State<LegalPanel> {
  int _tab = 0; // 0 = Terms of Service (shown first), 1 = Privacy Policy
  late bool _agreed = widget.agreed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final height = math.min(MediaQuery.sizeOf(context).height * 0.82, 720.0);
    final sections = _tab == 0 ? termsSections : privacySections;

    // The phone's Back button closes the panel and keeps what was ticked.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.pop(context, _agreed);
      },
      child: Dialog(
        backgroundColor: c.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: height,
          child: Column(
            children: [
              // ---- Header: the two tabs ----
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: c.chip,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _Tab(
                          key: const Key('tab-terms'),
                          label: 'Terms of Service',
                          selected: _tab == 0,
                          onTap: () => setState(() => _tab = 0),
                        ),
                      ),
                      Expanded(
                        child: _Tab(
                          key: const Key('tab-privacy'),
                          label: 'Privacy Policy',
                          selected: _tab == 1,
                          onTap: () => setState(() => _tab = 1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Divider(height: 1, color: c.border),

              // ---- The text of the chosen document ----
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: ListView(
                    key: ValueKey(_tab),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    children: [
                      Text(
                        'Last updated: $legalLastUpdated',
                        style: text.labelSmall,
                      ),
                      const SizedBox(height: 14),
                      for (final section in sections)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(section.title, style: text.titleMedium),
                              const SizedBox(height: 4),
                              Text(
                                section.body,
                                style: text.bodyMedium?.copyWith(height: 1.55),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Divider(height: 1, color: c.border),

              // ---- Bottom: the agree box and Done ----
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      key: const Key('panel-checkbox'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _agreed = !_agreed),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            CheckBoxMark(checked: _agreed),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'I agree to the Terms of Service and Privacy Policy',
                                style: TextStyle(
                                  color: c.textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    GoldButton(
                      label: 'Done',
                      onPressed: () => Navigator.pop(context, _agreed),
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

class _Tab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Tab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 44,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          gradient: selected ? c.goldGradient : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: selected ? c.onGold : c.textSecondary,
          ),
        ),
      ),
    );
  }
}
