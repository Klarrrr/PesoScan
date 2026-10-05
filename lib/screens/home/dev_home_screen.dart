import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/detector/detector_factory.dart';
import '../../services/detector/mock_detector.dart';
import '../../services/sample_data.dart';
import '../../services/supabase_service.dart';

/// Developer tools (debug builds only: Settings > Developer tools).
class DevHomeScreen extends StatefulWidget {
  const DevHomeScreen({super.key});

  @override
  State<DevHomeScreen> createState() => _DevHomeScreenState();
}

class _DevHomeScreenState extends State<DevHomeScreen> {
  static const Map<MockScenario, String> _sceneLabels = {
    MockScenario.normal: 'Normal',
    MockScenario.crowded: 'Crowded',
    MockScenario.edge: 'Edge',
    MockScenario.empty: 'Empty',
    MockScenario.failing: 'Fails',
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Developer tools')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Fake detector scene', style: text.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Used by the scanner while there is no model. '
            'Change it, then open the scanner.\n'
            'Crowded: heavy overlap. Edge: coins cut off by the edge (still counted). '
            'Empty: no coins found. Fails: cannot process the picture.',
            style: text.bodySmall,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in _sceneLabels.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: DetectorFactory.mockScenario == entry.key,
                  onSelected: (_) =>
                      setState(() => DetectorFactory.mockScenario = entry.key),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Fake detections allowed in this build: '
            '${DetectorFactory.demoAllowed ? 'yes' : 'no'}',
            style: text.bodySmall,
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final history = context.read<HistoryProvider>();
              final userId = context.read<AuthProvider>().userId;
              await history.addAll(devSampleScans(userId: userId));
              messenger.showSnackBar(
                const SnackBar(content: Text('Added 8 sample scans')),
              );
            },
            child: const Text('Add sample scans'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              await context.read<SettingsProvider>().setOnboardingDone(false);
              navigator.pushNamedAndRemoveUntil(AppRoutes.splash, (_) => false);
            },
            child: const Text('Reset onboarding'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async {
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
            child: const Text('Test Supabase'),
          ),
        ],
      ),
    );
  }
}
