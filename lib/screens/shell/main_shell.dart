import 'package:flutter/material.dart';

import '../../core/app_health.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/peso_bottom_bar.dart';
import '../history/history_tab.dart';
import '../home/home_tab.dart';
import '../scanner/open_scanner.dart';
import '../settings/settings_tab.dart';

/// The screen that holds the bottom bar and the three tabs.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _warnIfStorageIsBroken(),
    );
  }

  /// If the scan database could not be opened, say so once.
  Future<void> _warnIfStorageIsBroken() async {
    if (!mounted || !AppHealth.databaseFailed || AppHealth.warningShown) return;
    AppHealth.warningShown = true;
    await ConfirmDialog.show(
      context,
      icon: Icons.storage_rounded,
      title: 'Scan history cannot be saved',
      message:
          'PesoScan could not open its storage on this phone, so scans '
          'will be lost when you close the app. Free up some storage and '
          'restart the app.',
      confirmLabel: 'Got it',
      showCancel: false,
      danger: true,
    );
  }

  void _goTo(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    // Back on History/Settings returns to Home first; Back on Home exits.
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goTo(0);
      },
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              // IndexedStack keeps every tab alive, so scroll positions survive.
              child: IndexedStack(
                index: _index,
                children: [
                  HomeTab(onGoToTab: _goTo),
                  const HistoryTab(),
                  const SettingsTab(),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: PesoBottomBar(
                currentIndex: _index,
                onTab: _goTo,
                onScan: () => openScanner(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
