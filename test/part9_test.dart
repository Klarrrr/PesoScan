import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesoscan/core/app_theme.dart';
import 'package:pesoscan/screens/scanner/scanner_widgets.dart';
import 'package:pesoscan/widgets/camera_required_dialog.dart';

Widget host(Widget child) => MaterialApp(
  theme: AppTheme.dark,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('total panel: waiting, then live values', (tester) async {
    await tester.pumpWidget(host(const TotalPanel(totalCentavos: 0, count: 0)));
    expect(find.text('Waiting for detection...'), findsOneWidget);

    await tester.pumpWidget(
      host(const TotalPanel(totalCentavos: 3225, count: 7)),
    );
    expect(find.text('TOTAL VALUE'), findsOneWidget);
    expect(find.text('₱32.25'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('items'), findsOneWidget);
  });

  testWidgets('top bar shows the status and singular/plural count', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(ScannerTopBar(onBack: () {}, live: false, count: 1)),
    );
    expect(find.text('SCANNING...'), findsOneWidget);
    expect(find.text('1 ITEM'), findsOneWidget);

    await tester.pumpWidget(
      host(ScannerTopBar(onBack: () {}, live: true, count: 7)),
    );
    expect(find.text('LIVE'), findsOneWidget);
    expect(find.text('7 ITEMS'), findsOneWidget);
  });

  testWidgets('camera popup: normal and blocked wording', (tester) async {
    await tester.pumpWidget(host(const CameraRequiredDialog(blocked: false)));
    expect(find.text('Camera Access Required'), findsOneWidget);
    expect(find.text('Allow Camera'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    await tester.pumpWidget(host(const CameraRequiredDialog(blocked: true)));
    expect(find.text('Open Settings'), findsOneWidget);
  });
}
