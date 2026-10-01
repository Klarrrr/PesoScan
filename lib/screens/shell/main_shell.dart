import 'package:flutter/material.dart';

import '../../widgets/peso_bottom_bar.dart';
import '../../widgets/placeholder_screen.dart';
import '../home/dev_home_screen.dart';
import '../home/home_tab.dart';
import '../scanner/open_scanner.dart';

/// The screen that holds the bottom bar and the three tabs.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

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
                  const PlaceholderScreen(title: 'History'), // Part 13
                  const DevHomeScreen(), // temporary Settings, Part 20
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
