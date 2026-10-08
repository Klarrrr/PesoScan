import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pesoscan/core/app_theme.dart';
import 'package:pesoscan/data/legal_content.dart';
import 'package:pesoscan/providers/auth_provider.dart';
import 'package:pesoscan/providers/avatar_provider.dart';
import 'package:pesoscan/providers/history_provider.dart';
import 'package:pesoscan/screens/settings/account_details_screen.dart';
import 'package:pesoscan/services/avatar_store.dart';
import 'package:pesoscan/services/photo_picker.dart';
import 'package:pesoscan/services/scan_repository.dart';
import 'package:pesoscan/widgets/photo_options_sheet.dart';
import 'package:pesoscan/widgets/user_avatar.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A picker that "chooses" whatever the test says.
class _FakePicker implements PhotoPicker {
  String? next; // null = the user cancelled
  Object? failWith;
  PhotoSource? lastSource;

  @override
  Future<String?> pick(PhotoSource source) async {
    lastSource = source;
    if (failWith != null) throw failWith!;
    return next;
  }
}

class _FakeAuth extends AuthProvider {
  String? id = 'user-1';

  @override
  String? get userId => id;

  @override
  String? get username => 'juan';

  @override
  String? get email => 'juan@example.com';

  void switchTo(String? newId) {
    id = newId;
    notifyListeners();
  }
}

/// Real file work needs real time, so wait for it in small steps.
Future<void> _waitFor(bool Function() condition) async {
  for (var i = 0; i < 200 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(condition(), isTrue, reason: 'it never happened');
}

void main() {
  late Directory root;
  late AvatarStore store;

  File photo(String name, List<int> bytes) =>
      File(p.join(root.path, name))..writeAsBytesSync(bytes);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('pesoscan_avatar');
    store = AvatarStore(root: () async => root);
  });

  tearDown(() => root.delete(recursive: true));

  group('AvatarStore', () {
    test('keeps one picture per account and replaces the old one', () async {
      final first = await store.save(
        userId: 'u1',
        sourcePath: photo('a.jpg', [1]).path,
      );
      expect(File(first).existsSync(), isTrue);
      expect(await store.load('u1'), first);
      expect(await store.load('u2'), isNull);

      final second = await store.save(
        userId: 'u1',
        sourcePath: photo('b.jpg', [2]).path,
      );
      expect(second, isNot(first));
      expect(File(first).existsSync(), isFalse); // the old one is gone
      expect(await store.load('u1'), second);
    });

    test('remove forgets the picture and deletes its file', () async {
      final saved = await store.save(
        userId: 'u1',
        sourcePath: photo('a.jpg', [1]).path,
      );
      await store.remove('u1');

      expect(File(saved).existsSync(), isFalse);
      expect(await store.load('u1'), isNull);
    });

    test('a picture whose file disappeared is forgotten', () async {
      final saved = await store.save(
        userId: 'u1',
        sourcePath: photo('a.jpg', [1]).path,
      );
      File(saved).deleteSync();

      expect(await store.load('u1'), isNull);
    });
  });

  group('AvatarProvider', () {
    test('choosing, cancelling, failing and removing', () async {
      final picker = _FakePicker();
      final auth = _FakeAuth();
      final avatar = AvatarProvider(store, auth, picker: picker);

      picker.next = photo('x.jpg', [1, 2, 3]).path;
      expect(await avatar.choose(PhotoSource.gallery), AvatarChange.changed);
      expect(avatar.hasPhoto, isTrue);
      expect(File(avatar.path!).existsSync(), isTrue);
      expect(picker.lastSource, PhotoSource.gallery);

      picker.next = null; // the user backs out
      expect(await avatar.choose(PhotoSource.camera), AvatarChange.cancelled);
      expect(avatar.hasPhoto, isTrue); // nothing changed

      picker.failWith = StateError('boom');
      expect(await avatar.choose(PhotoSource.gallery), AvatarChange.failed);
      expect(avatar.hasPhoto, isTrue);

      await avatar.remove();
      expect(avatar.hasPhoto, isFalse);
      expect(await store.load('user-1'), isNull);
      avatar.dispose();
    });

    test('each account sees its own picture', () async {
      final picker = _FakePicker()..next = photo('y.jpg', [9]).path;
      final auth = _FakeAuth();
      final avatar = AvatarProvider(store, auth, picker: picker);

      await avatar.choose(PhotoSource.gallery);
      final mine = avatar.path;
      expect(mine, isNotNull);

      auth.switchTo('user-2'); // somebody else logs in
      expect(avatar.path, isNull); // right away: not mine
      await _waitFor(() => !avatar.hasPhoto);

      auth.switchTo('user-1'); // I come back
      await _waitFor(() => avatar.path == mine);
      avatar.dispose();
    });

    test('nobody signed in means nothing to change', () async {
      final auth = _FakeAuth()..id = null;
      final avatar = AvatarProvider(store, auth, picker: _FakePicker());
      expect(await avatar.choose(PhotoSource.gallery), AvatarChange.failed);
      avatar.dispose();
    });
  });

  group('widgets', () {
    void bigScreen(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 2600);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
    }

    testWidgets('the avatar shows the initial, or a picture when it has one', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: UserAvatar(name: 'juan')),
        ),
      );
      expect(find.text('J'), findsOneWidget);
      expect(find.byType(Image), findsNothing);

      final file = photo('z.jpg', [1, 2, 3]);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: UserAvatar(name: 'juan', photoPath: file.path),
          ),
        ),
      );
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('the photo menu offers Remove only when there is a photo', (
      tester,
    ) async {
      bigScreen(tester);
      PhotoChoice? chosen;

      Future<void> open(bool hasPhoto) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () async =>
                        chosen = await PhotoOptionsSheet.show(
                          context,
                          hasPhoto: hasPhoto,
                        ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
      }

      await open(false);
      expect(find.byKey(const Key('photo-gallery')), findsOneWidget);
      expect(find.byKey(const Key('photo-camera')), findsOneWidget);
      expect(find.byKey(const Key('photo-remove')), findsNothing);
      await tester.tap(find.byKey(const Key('photo-gallery')));
      await tester.pumpAndSettle();
      expect(chosen, PhotoChoice.gallery);

      await open(true);
      expect(find.byKey(const Key('photo-remove')), findsOneWidget);
      await tester.tap(find.byKey(const Key('photo-remove')));
      await tester.pumpAndSettle();
      expect(chosen, PhotoChoice.remove);
    });

    testWidgets(
      'the account screen opens the photo menu, Cancel changes nothing',
      (tester) async {
        bigScreen(tester);
        final auth = _FakeAuth();
        final avatar = AvatarProvider(store, auth, picker: _FakePicker());

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(value: auth),
              ChangeNotifierProvider<HistoryProvider>.value(
                value: HistoryProvider(InMemoryScanRepository(), auth),
              ),
              ChangeNotifierProvider<AvatarProvider>.value(value: avatar),
            ],
            child: MaterialApp(
              theme: AppTheme.dark,
              home: const AccountDetailsScreen(),
            ),
          ),
        );

        expect(find.byKey(const Key('link-change-photo')), findsOneWidget);
        await tester.tap(find.byKey(const Key('btn-change-photo')));
        await tester.pumpAndSettle();
        expect(find.text('Profile photo'), findsOneWidget);

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.text('Profile photo'), findsNothing);
        expect(avatar.hasPhoto, isFalse);
      },
    );
  });

  group('legal text', () {
    test('the minimum age is stated the same way everywhere', () {
      final terms = termsSections.map((s) => s.body).join(' ');
      final children = privacySections
          .firstWhere((s) => s.title.contains('Children'))
          .body;

      expect(terms, contains('users aged $minimumAge and above'));
      expect(children, contains('users aged $minimumAge and above'));
    });

    test('the privacy policy says the profile picture stays on the phone', () {
      final privacy = privacySections.map((s) => s.body).join(' ');
      expect(privacy, contains('profile picture'));
      expect(privacy, contains('never uploaded'));
    });
  });
}
