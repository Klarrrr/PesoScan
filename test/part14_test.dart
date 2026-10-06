import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesoscan/core/app_theme.dart';
import 'package:pesoscan/models/detection.dart';
import 'package:pesoscan/models/money_class.dart';
import 'package:pesoscan/models/scan_record.dart';
import 'package:pesoscan/screens/history/scan_detail_screen.dart';

Detection det(int classId, Rect box, {double conf = 0.9}) =>
    Detection(money: MoneyClasses.byId(classId), confidence: conf, box: box);

void main() {
  testWidgets('detail shows date, total, boxes, table and the no-photo note', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    final record = ScanRecord(
      id: 'x',
      createdAt: DateTime(2026, 9, 30, 10, 18),
      imagePath: '', // no photo
      detections: [
        det(7, const Rect.fromLTRB(0.1, 0.1, 0.3, 0.3)),
        det(7, const Rect.fromLTRB(0.5, 0.1, 0.7, 0.3)),
        det(6, const Rect.fromLTRB(0.1, 0.5, 0.3, 0.7), conf: 0.4),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: ScanDetailScreen(record: record),
      ),
    );

    expect(find.text('Scan Detail'), findsOneWidget);
    expect(find.text('Wednesday, September 30, 2026'), findsOneWidget);
    expect(find.text('₱25.00'), findsOneWidget); // 10 + 10 + 5
    expect(find.text('TOTAL VALUE'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // item count
    expect(find.text('×2'), findsOneWidget);
    expect(find.text('₱20.00'), findsOneWidget);
    expect(find.text('No photo saved'), findsOneWidget);
  });
}
