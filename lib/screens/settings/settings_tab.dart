import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../core/app_theme.dart';
import '../../core/format_bytes.dart';
import '../../models/money_class.dart';
import '../../providers/auth_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/feedback_service.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/peso_bottom_bar.dart';

/// Pages 12-13 of the prototype, plus Account and Exit App.
class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  String _version = '1.0.0';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform()
        .then((info) {
          if (mounted) setState(() => _version = info.version);
        })
        .catchError((Object _) {
          // Not available (for example in tests): keep the default.
        });
  }

  // ---------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------

  Future<void> _clearPhotos() async {
    final history = context.read<HistoryProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final stats = await history.photoStats();
    if (!mounted) return;
    if (stats.count == 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No saved photos to clear.')),
      );
      return;
    }

    final ok = await ConfirmDialog.show(
      context,
      icon: Icons.delete_sweep_outlined,
      title: 'Clear scan photos?',
      message:
          'This removes ${stats.count} '
          '${stats.count == 1 ? 'photo' : 'photos'} '
          '(about ${formatBytes(stats.bytes)}). Your scans, totals and items '
          'stay in History.',
      confirmLabel: 'Clear photos',
      danger: true,
    );
    if (!ok) return;

    final freed = await history.clearPhotos();
    messenger.showSnackBar(
      SnackBar(content: Text('Freed ${formatBytes(freed)}')),
    );
  }

  Future<void> _logout() async {
    final auth = context.read<AuthProvider>();
    final ok = await ConfirmDialog.show(
      context,
      icon: Icons.logout_rounded,
      title: 'Log out?',
      message:
          'Your scans stay on this phone and will be here when you log '
          'in again.',
      confirmLabel: 'Log out',
    );
    if (ok) await auth.logout(); // the auth guard sends you to Login
  }

  Future<void> _exitApp() async {
    final ok = await ConfirmDialog.show(
      context,
      icon: Icons.power_settings_new_rounded,
      title: 'Exit PesoScan?',
      message: 'The app will close. Your scans are already saved.',
      confirmLabel: 'Exit',
      danger: true,
    );
    if (ok) await SystemNavigator.pop();
  }

  // ---------------------------------------------------------------
  // Screen
  // ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final settings = context.watch<SettingsProvider>();
    final auth = context.watch<AuthProvider>();
    final text = Theme.of(context).textTheme;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          PesoBottomBar.totalHeight(context) + 8,
        ),
        children: [
          Text('Settings', style: text.headlineMedium),
          const SizedBox(height: 18),

          // ---- Account ----
          const _SectionTitle('ACCOUNT'),
          _AccountCard(username: auth.username, email: auth.email),
          const SizedBox(height: 10),
          _Group(
            children: [
              _Tile(
                key: const Key('tile-change-password'),
                icon: Icons.lock_outline,
                title: 'Change Password',
                trailing: const _Chevron(),
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.changePassword),
              ),
              _Tile(
                key: const Key('tile-logout'),
                icon: Icons.logout_rounded,
                title: 'Log Out',
                trailing: const _Chevron(),
                onTap: _logout,
              ),
            ],
          ),

          // ---- Display & theme ----
          const _SectionTitle('DISPLAY & THEME'),
          _Group(
            children: [
              _Tile(
                key: const Key('theme-dark'),
                icon: Icons.dark_mode_outlined,
                title: 'Dark Mode',
                trailing: settings.themeMode == ThemeMode.dark
                    ? const _Check()
                    : null,
                onTap: () => settings.setThemeMode(ThemeMode.dark),
              ),
              _Tile(
                key: const Key('theme-light'),
                icon: Icons.light_mode_outlined,
                title: 'Light Mode',
                trailing: settings.themeMode == ThemeMode.light
                    ? const _Check()
                    : null,
                onTap: () => settings.setThemeMode(ThemeMode.light),
              ),
              _Tile(
                key: const Key('theme-system'),
                icon: Icons.settings_suggest_outlined,
                title: 'System Mode',
                trailing: settings.themeMode == ThemeMode.system
                    ? const _Check()
                    : null,
                onTap: () => settings.setThemeMode(ThemeMode.system),
              ),
            ],
          ),

          // ---- Feedback ----
          const _SectionTitle('HAPTIC & AUDIO FEEDBACK'),
          _Group(
            children: [
              _Tile(
                icon: Icons.vibration_rounded,
                title: 'Haptic Feedback',
                trailing: _GoldSwitch(
                  key: const Key('switch-haptic'),
                  value: settings.hapticEnabled,
                  onChanged: (v) {
                    settings.setHapticEnabled(v);
                    if (v) HapticFeedback.mediumImpact(); // a little preview
                  },
                ),
              ),
              _Tile(
                icon: Icons.notifications_none_rounded,
                title: 'Audio Chime',
                trailing: _GoldSwitch(
                  key: const Key('switch-audio'),
                  value: settings.audioEnabled,
                  onChanged: (v) {
                    settings.setAudioEnabled(v);
                    if (v) {
                      FeedbackService.instance.itemLocked(
                        haptic: false,
                        audio: true,
                      );
                    }
                  },
                ),
              ),
            ],
          ),

          // ---- Storage ----
          const _SectionTitle('STORAGE'),
          _Group(
            children: [
              _Tile(
                key: const Key('tile-clear-cache'),
                icon: Icons.delete_outline_rounded,
                title: 'Clear Cached Images',
                subtitle: 'Frees up device storage',
                trailing: const _Chevron(),
                onTap: _clearPhotos,
              ),
            ],
          ),

          // ---- Support ----
          const _SectionTitle('SUPPORT'),
          _Group(
            children: [
              _Tile(
                icon: Icons.menu_book_outlined,
                title: 'Currency Reference Guide',
                subtitle: '${MoneyClasses.all.length} supported classes',
                trailing: const _Chevron(),
                onTap: () => Navigator.pushNamed(context, AppRoutes.guide),
              ),
              _Tile(
                icon: Icons.help_outline_rounded,
                title: 'Help & FAQ',
                subtitle: 'Scanning tips and guides',
                trailing: const _Chevron(),
                onTap: () => Navigator.pushNamed(context, AppRoutes.help),
              ),
            ],
          ),

          // ---- About & legal ----
          const _SectionTitle('ABOUT & LEGAL'),
          _Group(
            children: [
              _Tile(
                icon: Icons.info_outline_rounded,
                title: 'App Version',
                subtitle: 'YOLO26-Powered',
                trailing: Text(
                  'v$_version',
                  style: AppText.mono(
                    size: 13,
                    weight: FontWeight.w400,
                    color: c.textMuted,
                  ),
                ),
              ),
              _Tile(
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                trailing: const _Chevron(),
                onTap: () => Navigator.pushNamed(context, AppRoutes.terms),
              ),
              _Tile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                trailing: const _Chevron(),
                onTap: () => Navigator.pushNamed(context, AppRoutes.privacy),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _DisclaimerCard(),

          // ---- Developer tools (debug builds only) ----
          if (kDebugMode) ...[
            const _SectionTitle('DEVELOPER'),
            _Group(
              children: [
                _Tile(
                  key: const Key('tile-dev'),
                  icon: Icons.build_outlined,
                  title: 'Developer tools',
                  subtitle: 'Only in debug builds',
                  trailing: const _Chevron(),
                  onTap: () => Navigator.pushNamed(context, AppRoutes.dev),
                ),
              ],
            ),
          ],

          // ---- Exit ----
          const SizedBox(height: 22),
          _Group(
            children: [
              _Tile(
                key: const Key('tile-exit'),
                icon: Icons.power_settings_new_rounded,
                iconColor: c.danger,
                titleColor: c.danger,
                title: 'Exit App',
                onTap: _exitApp,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- pieces

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

/// A rounded card holding several rows, with thin lines between them.
class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0) Divider(height: 1, color: c.border),
            child,
          ],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final Color? titleColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _Tile({
    super.key,
    required this.icon,
    required this.title,
    this.iconColor,
    this.titleColor,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? c.textSecondary, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      color: titleColor ?? c.textPrimary,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            // ignore: use_null_aware_elements
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) =>
      Icon(Icons.chevron_right_rounded, color: context.colors.textMuted);
}

class _Check extends StatelessWidget {
  const _Check();

  @override
  Widget build(BuildContext context) =>
      Icon(Icons.check_rounded, color: context.colors.gold);
}

/// The gold switch from the prototype.
class _GoldSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _GoldSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Switch(
      value: value,
      onChanged: onChanged,
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? c.gold : c.chip,
      ),
      thumbColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? c.onGold : c.textMuted,
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final String? username;
  final String? email;
  const _AccountCard({required this.username, required this.email});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final name = (username == null || username!.isEmpty)
        ? 'Your account'
        : username!;
    final initial = name.characters.first.toUpperCase();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: c.goldGradient,
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: TextStyle(
                fontFamily: AppFonts.heading,
                fontWeight: FontWeight.w700,
                fontSize: 22,
                color: c.onGold,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontWeight: FontWeight.w600,
                    fontSize: 17,
                    color: c.textPrimary,
                  ),
                ),
                Text(
                  email ?? 'Not signed in',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DisclaimerCard extends StatelessWidget {
  const _DisclaimerCard();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.danger.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: c.danger, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
                children: [
                  TextSpan(
                    text: 'Deep learning disclaimer: ',
                    style: TextStyle(
                      color: c.danger,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const TextSpan(
                    text:
                        'PesoScan is designed for counting purposes only. '
                        'It does not detect counterfeit coins or bills and '
                        'should not be used for authentication purposes.',
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
