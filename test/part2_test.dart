// ignore: unnecessary_import
import 'dart:ui' show Rect;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesoscan/models/detection.dart';
import 'package:pesoscan/models/money_class.dart';
import 'package:pesoscan/models/scan_record.dart';
import 'package:pesoscan/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ScanRecord survives a save/load round trip', () {
    final record = ScanRecord(
      id: 'scan-1',
      userId: 'user-1',
      createdAt: DateTime(2026, 9, 30, 10, 30),
      imagePath: '/data/scan-1.jpg',
      detections: [
        Detection(
          money: MoneyClasses.byId(7), // P10 BSP
          confidence: 0.91,
          box: const Rect.fromLTRB(0.1, 0.2, 0.3, 0.4),
        ),
        Detection(
          money: MoneyClasses.byId(12), // P100 NGC bill
          confidence: 0.55,
          box: const Rect.fromLTRB(0.2, 0.5, 0.9, 0.7),
        ),
      ],
    );

    final loaded = ScanRecord.fromMap(record.toMap());

    expect(loaded.id, 'scan-1');
    expect(loaded.createdAt, record.createdAt);
    expect(loaded.totalCentavos, 11000); // P10 + P100
    expect(loaded.itemCount, 2);
    expect(loaded.detections.first.money, MoneyClasses.byId(7));
    expect(loaded.detections.last.box.right, closeTo(0.9, 0.0001));
    expect(loaded.detections.last.isLowConfidence, isTrue);
  });

  test('Settings are saved and loaded again', () async {
    SharedPreferences.setMockInitialValues({});

    final first = SettingsProvider();
    await first.load();
    await first.setThemeMode(ThemeMode.dark);
    await first.setHapticEnabled(false);

    // A brand-new provider = simulates restarting the app.
    final second = SettingsProvider();
    await second.load();

    expect(second.themeMode, ThemeMode.dark);
    expect(second.hapticEnabled, isFalse);
    expect(second.audioEnabled, isTrue); // untouched default
  });
}
