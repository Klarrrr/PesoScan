import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../services/connectivity_service.dart';

/// A yellow note shown only while the phone has no network.
/// It takes up no space when you are online.
class OfflineBanner extends StatefulWidget {
  /// Tests pass their own service; the app uses the shared one.
  final ConnectivityService? service;
  const OfflineBanner({super.key, this.service});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  late final ConnectivityService _service =
      widget.service ?? ConnectivityService.instance;
  late bool _online = _service.isOnline;
  StreamSubscription<bool>? _subscription;

  @override
  void initState() {
    super.initState();
    _service.start();
    _subscription = _service.changes.listen((value) {
      if (mounted) setState(() => _online = value);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_online) return const SizedBox.shrink();
    final c = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        key: const Key('offline-banner'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.warning.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            Icon(Icons.wifi_off_rounded, color: c.warning, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No internet connection. Logging in and email codes need '
                'internet. Scanning does not.',
                style: TextStyle(color: c.warning, fontSize: 13, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
