import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_routes.dart';
import '../../core/money.dart';
import '../../providers/settings_provider.dart';
import '../../services/supabase_service.dart';

/// TEMPORARY screen to test theme, settings and the backend.
/// Replaced by the real Home in Part 8.
class DevHomeScreen extends StatelessWidget {
  const DevHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // watch = rebuild this screen whenever settings change.
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('PesoScan (dev)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Sample total: ${formatPeso(4625)}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          Text('Theme', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.light, label: Text('Light')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
              ButtonSegment(value: ThemeMode.system, label: Text('System')),
            ],
            selected: {settings.themeMode},
            // read = call a method without rebuilding because of this line.
            onSelectionChanged: (s) =>
                context.read<SettingsProvider>().setThemeMode(s.first),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Haptic feedback'),
            value: settings.hapticEnabled,
            onChanged: (v) =>
                context.read<SettingsProvider>().setHapticEnabled(v),
          ),
          SwitchListTile(
            title: const Text('Audio feedback'),
            value: settings.audioEnabled,
            onChanged: (v) =>
                context.read<SettingsProvider>().setAudioEnabled(v),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.history),
            child: const Text('Open a placeholder screen'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async {
              await context.read<SettingsProvider>().setOnboardingDone(false);
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.splash,
                (_) => false,
              );
            },
            child: const Text('Reset onboarding (dev only)'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async {
              // Grab the messenger BEFORE the await (safe use of context).
              final messenger = ScaffoldMessenger.of(context);

              if (!SupabaseService.isReady) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Supabase is not configured (check env.json)',
                    ),
                  ),
                );
                return;
              }
              try {
                final free = await SupabaseService.client.rpc(
                  'username_available',
                  params: {'name': 'pesoscan_test'},
                );
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Connected! username_available = $free'),
                  ),
                );
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
              }
            },
            child: const Text('Test Supabase (dev only)'),
          ),
        ],
      ),
    );
  }
}
