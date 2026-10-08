import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesoscan/core/app_theme.dart';
import 'package:pesoscan/screens/scanner/open_scanner.dart';
import 'package:pesoscan/services/permission_service.dart';

class _FakePermissions implements CameraPermissions {
  CameraAccess current;
  final CameraAccess afterRequest;
  int requestCalls = 0;
  int settingsCalls = 0;

  _FakePermissions(this.current, {this.afterRequest = CameraAccess.granted});

  @override
  Future<CameraAccess> status() async => current;

  @override
  Future<CameraAccess> request() async {
    requestCalls++;
    current = afterRequest;
    return afterRequest;
  }

  @override
  Future<void> openSettings() async {
    settingsCalls++;
  }
}

/// A screen with a "scan" button that runs the permission check.
Widget _host(CameraPermissions permissions, void Function(bool) onResult) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () async => onResult(
              await ensureCameraAccess(context, permissions: permissions),
            ),
            child: const Text('scan'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _pressScan(WidgetTester tester) async {
  await tester.tap(find.text('scan'));
  await tester.pumpAndSettle();
}

void main() {
  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
  }

  group('denialKind', () {
    test('a fresh install can still be asked', () {
      expect(
        denialKind(askedBefore: false, canAskAgain: false),
        CameraAccess.denied,
      );
      expect(
        denialKind(askedBefore: false, canAskAgain: true),
        CameraAccess.denied,
      );
    });

    test('after one refusal Android still shows its popup', () {
      expect(
        denialKind(askedBefore: true, canAskAgain: true),
        CameraAccess.denied,
      );
    });

    test('asked before and no popup possible = blocked', () {
      expect(
        denialKind(askedBefore: true, canAskAgain: false),
        CameraAccess.permanentlyDenied,
      );
    });
  });

  group('ensureCameraAccess', () {
    testWidgets('an allowed camera needs no popup at all', (tester) async {
      bigScreen(tester);
      final permissions = _FakePermissions(CameraAccess.granted);
      bool? result;
      await tester.pumpWidget(_host(permissions, (v) => result = v));
      await _pressScan(tester);

      expect(result, isTrue);
      expect(find.text('Camera Access Required'), findsNothing);
      expect(permissions.requestCalls, 0);
    });

    testWidgets('Cancel on our popup does not ask Android', (tester) async {
      bigScreen(tester);
      final permissions = _FakePermissions(CameraAccess.denied);
      bool? result;
      await tester.pumpWidget(_host(permissions, (v) => result = v));
      await _pressScan(tester);

      expect(find.text('Camera Access Required'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
      expect(permissions.requestCalls, 0);
    });

    testWidgets('Allow Camera then "yes" opens the scanner', (tester) async {
      bigScreen(tester);
      final permissions = _FakePermissions(CameraAccess.denied);
      bool? result;
      await tester.pumpWidget(_host(permissions, (v) => result = v));
      await _pressScan(tester);

      await tester.tap(find.text('Allow Camera'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(permissions.requestCalls, 1);
    });

    testWidgets('a "no" from Android shows a message and does NOT loop', (
      tester,
    ) async {
      bigScreen(tester);
      final permissions = _FakePermissions(
        CameraAccess.denied,
        afterRequest: CameraAccess.denied,
      );
      bool? result;
      await tester.pumpWidget(_host(permissions, (v) => result = v));
      await _pressScan(tester);

      await tester.tap(find.text('Allow Camera'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
      expect(permissions.requestCalls, 1); // asked once, not again
      expect(find.text('Camera Access Required'), findsNothing); // no new popup
      expect(
        find.text('The camera is needed to scan coins and bills.'),
        findsOneWidget,
      );
    });

    testWidgets('a second "no" says it is blocked and offers Settings', (
      tester,
    ) async {
      bigScreen(tester);
      final permissions = _FakePermissions(
        CameraAccess.denied,
        afterRequest: CameraAccess.permanentlyDenied,
      );
      bool? result;
      await tester.pumpWidget(_host(permissions, (v) => result = v));
      await _pressScan(tester);

      await tester.tap(find.text('Allow Camera'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
      expect(find.text('Camera access is blocked.'), findsOneWidget);

      await tester.tap(find.text('Settings'));
      await tester.pump();
      expect(permissions.settingsCalls, 1);
    });

    testWidgets('a blocked camera goes to Settings and is NEVER requested', (
      tester,
    ) async {
      bigScreen(tester);
      final permissions = _FakePermissions(CameraAccess.permanentlyDenied);
      bool? result;
      await tester.pumpWidget(_host(permissions, (v) => result = v));
      await _pressScan(tester);

      // The popup now says "Open Settings".
      expect(find.text('Open Settings'), findsOneWidget);
      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
      expect(permissions.settingsCalls, 1);
      expect(permissions.requestCalls, 0); // this call used to freeze the app
    });
  });
}
