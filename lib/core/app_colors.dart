import 'package:flutter/material.dart';

/// Every color in the app lives here, taken from the prototype.
/// Use it anywhere with:  final c = context.colors;  then  c.gold, c.surface ...
class PesoColors {
  final Color background;
  final Color surface; // cards
  final Color tile; // lighter blue home tiles
  final Color chip; // icon boxes and tip chips
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color gold;
  final Color goldDark;
  final Color onGold; // text drawn on top of gold
  final Color success; // high confidence
  final Color warning; // medium confidence
  final Color danger; // low confidence, errors

  const PesoColors({
    required this.background,
    required this.surface,
    required this.tile,
    required this.chip,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.gold,
    required this.goldDark,
    required this.onGold,
    required this.success,
    required this.warning,
    required this.danger,
  });

  // Estimated from the prototype. Replace with exact values if you have them.
  static const dark = PesoColors(
    background: Color(0xFF0A1226),
    surface: Color(0xFF101B38),
    tile: Color(0xFF1D3861),
    chip: Color(0xFF1B242C),
    border: Color(0x14FFFFFF),
    textPrimary: Color(0xFFF2F4F8),
    textSecondary: Color(0xFF7C8DB5),
    textMuted: Color(0xFF4A5B82),
    gold: Color(0xFFF5B83D),
    goldDark: Color(0xFFE59F1E),
    onGold: Color(0xFF0A1226),
    success: Color(0xFF34D77A),
    warning: Color(0xFFE0A526),
    danger: Color(0xFFF26B6B),
  );

  // The prototype has no light design, so this one is ours, same style.
  static const light = PesoColors(
    background: Color(0xFFF4F6FB),
    surface: Color(0xFFFFFFFF),
    tile: Color(0xFFDDE7F7),
    chip: Color(0xFFE9EDF5),
    border: Color(0x1F0A1226),
    textPrimary: Color(0xFF0A1226),
    textSecondary: Color(0xFF5A6A8C),
    textMuted: Color(0xFF8A97B3),
    gold: Color(0xFFF5B83D),
    goldDark: Color(0xFFE59F1E),
    onGold: Color(0xFF0A1226),
    success: Color(0xFF1FA85A),
    warning: Color(0xFFC88A0A),
    danger: Color(0xFFD64545),
  );

  /// The diagonal gold gradient used on buttons and the Scan button.
  LinearGradient get goldGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gold, goldDark],
  );
}

/// Lets any widget write `context.colors` and get the palette for the
/// current light/dark theme.
extension PesoColorsContext on BuildContext {
  PesoColors get colors => Theme.of(this).brightness == Brightness.dark
      ? PesoColors.dark
      : PesoColors.light;
}
