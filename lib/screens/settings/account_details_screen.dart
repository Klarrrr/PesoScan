// ignore_for_file: unused_import

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/avatar_provider.dart';
import '../../providers/history_provider.dart';
import '../../services/photo_picker.dart';
import '../../widgets/gold_button.dart';
import '../../widgets/photo_options_sheet.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/verify_password_dialog.dart';
import '../scanner/open_scanner.dart';
import '../../services/permission_service.dart';

/// "juan.dela@gmail.com" becomes "ju" + 6 dots + "@gmail.com".
String maskEmail(String email) {
  const dot = '\u2022';
  final at = email.indexOf('@');
  if (at <= 0) return dot * 8;

  final local = email.substring(0, at);
  final domain = email.substring(at);
  final shown = local.length <= 2
      ? local.substring(0, 1)
      : local.substring(0, 2);
  final hidden = math.min(6, math.max(3, local.length - shown.length));
  return '$shown${dot * hidden}$domain';
}

/// Account details. Private details stay hidden until the user types their
/// password. The password itself is never shown: nobody can read it.
/// The profile photo can be changed any time (it is not private).
class AccountDetailsScreen extends StatefulWidget {
  const AccountDetailsScreen({super.key});

  @override
  State<AccountDetailsScreen> createState() => _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends State<AccountDetailsScreen>
    with WidgetsBindingObserver {
  static const _showFor = Duration(seconds: 60);

  Timer? _relock;
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _relock?.cancel();
    super.dispose();
  }

  // Hide everything again if the user leaves the app.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _lock();
  }

  void _lock() {
    _relock?.cancel();
    if (mounted && _unlocked) setState(() => _unlocked = false);
  }

  Future<void> _unlock() async {
    final auth = context.read<AuthProvider>();
    final ok = await VerifyPasswordDialog.show(
      context,
      verify: auth.verifyPassword,
      title: 'Enter your password',
      message: 'To see your account details, confirm that it is you.',
      confirmLabel: 'Unlock',
    );
    if (!ok || !mounted) return;

    setState(() => _unlocked = true);
    _relock?.cancel();
    _relock = Timer(_showFor, _lock);
  }

  Future<void> _changePhoto() async {
    final avatar = context.read<AvatarProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final choice = await PhotoOptionsSheet.show(
      context,
      hasPhoto: avatar.hasPhoto,
    );
    if (choice == null || !mounted) return;

    if (choice == PhotoChoice.remove) {
      await avatar.remove();
      return;
    }

    // The picture picker asks for the camera permission by itself.
    final result = await avatar.choose(
      choice == PhotoChoice.camera ? PhotoSource.camera : PhotoSource.gallery,
    );
    if (!mounted) return;

    switch (result) {
      case AvatarChange.changed:
        messenger.showSnackBar(
          const SnackBar(content: Text('Profile photo updated')),
        );
      case AvatarChange.cameraDenied:
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Camera access is needed to take a photo.'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: PermissionService.openSettings,
            ),
          ),
        );
      case AvatarChange.failed:
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Could not change the photo. Please try again.'),
          ),
        );
      case AvatarChange.cancelled:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final auth = context.watch<AuthProvider>();
    final history = context.watch<HistoryProvider>();

    final username = (auth.username == null || auth.username!.isEmpty)
        ? 'Your account'
        : auth.username!;
    final email = auth.email;
    final dots = '\u2022' * 8;
    final dateFormat = DateFormat('MMM d, yyyy');
    final member = auth.memberSince;
    final last = auth.lastSignIn;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            const ScreenHeader(
              title: 'Account Details',
              subtitle: 'Your sign-in information',
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                GestureDetector(
                  key: const Key('btn-change-photo'),
                  onTap: _changePhoto,
                  child: UserAvatar(
                    name: username,
                    size: 72,
                    showEditBadge: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        key: const Key('link-change-photo'),
                        onTap: _changePhoto,
                        child: Text(
                          'Change photo',
                          style: TextStyle(
                            color: c.gold,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c.border),
              ),
              child: Column(
                children: [
                  _DetailRow(
                    icon: Icons.mail_outline,
                    label: 'Email',
                    value: email == null
                        ? '-'
                        : (_unlocked ? email : maskEmail(email)),
                  ),
                  Divider(height: 1, color: c.border),
                  _DetailRow(
                    icon: Icons.lock_outline,
                    label: 'Password',
                    value: dots, // always dots: it can never be shown
                    note: _unlocked
                        ? 'It is stored in a protected form that nobody can '
                              'read, not even us. You can change it below.'
                        : null,
                  ),
                  Divider(height: 1, color: c.border),
                  _DetailRow(
                    icon: Icons.event_outlined,
                    label: 'Member since',
                    value: !_unlocked
                        ? dots
                        : (member == null
                              ? '-'
                              : dateFormat.format(member.toLocal())),
                  ),
                  Divider(height: 1, color: c.border),
                  _DetailRow(
                    icon: Icons.login_rounded,
                    label: 'Last sign-in',
                    value: !_unlocked
                        ? dots
                        : (last == null
                              ? '-'
                              : dateFormat.format(last.toLocal())),
                  ),
                  Divider(height: 1, color: c.border),
                  _DetailRow(
                    icon: Icons.history_rounded,
                    label: 'Scans on this phone',
                    value: _unlocked ? '${history.count}' : dots,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (_unlocked) ...[
              SoftButton(
                key: const Key('btn-hide'),
                label: 'Hide details',
                onPressed: _lock,
              ),
              const SizedBox(height: 8),
              Text(
                'The details hide again by themselves after one minute.',
                textAlign: TextAlign.center,
                style: text.bodySmall,
              ),
            ] else ...[
              GoldButton(
                key: const Key('btn-unlock'),
                label: 'Show details',
                onPressed: _unlock,
              ),
              const SizedBox(height: 8),
              Text(
                'Your email and sign-in details stay hidden until you type '
                'your password.',
                textAlign: TextAlign.center,
                style: text.bodySmall,
              ),
            ],
            const SizedBox(height: 18),
            SoftButton(
              key: const Key('btn-change-password'),
              label: 'Change Password',
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.changePassword),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? note;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: c.textSecondary, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.bodySmall),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, color: c.textPrimary),
                ),
                if (note != null) ...[
                  const SizedBox(height: 6),
                  Text(note!, style: text.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
