import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/app_routes.dart';
import 'core/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/history_provider.dart';
import 'providers/settings_provider.dart';
import 'services/app_database.dart';
import 'services/scan_repository.dart';
import 'services/sqlite_scan_repository.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The scanner is designed for portrait.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Load saved settings BEFORE the first screen so the theme doesn't flash.
  final settings = SettingsProvider();
  await settings.load();

  // Start the backend connection.
  await SupabaseService.init();

  // Restore the remembered login (works offline).
  final auth = AuthProvider();
  await auth.load();

  // Saved scans live in SQLite, separately for each user. If the database
  // cannot open, fall back to memory so the app is still usable.
  ScanRepository repository;
  try {
    final database = await AppDatabase.open();
    repository = SqliteScanRepository(database.db, userId: () => auth.userId);
  } catch (e) {
    debugPrint('Database could not be opened, using memory instead: $e');
    repository = InMemoryScanRepository();
  }
  final history = HistoryProvider(repository, auth);
  await history.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: history),
      ],
      child: const PesoScanApp(),
    ),
  );
}

class PesoScanApp extends StatelessWidget {
  const PesoScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<SettingsProvider, ThemeMode>(
      (s) => s.themeMode,
    );

    return MaterialApp(
      title: 'PesoScan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      navigatorKey: AppRoutes.navigatorKey,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.onGenerateRoute,
      // Wraps the whole app, so the guard works on every screen.
      builder: (context, child) =>
          _AuthRedirector(child: child ?? const SizedBox.shrink()),
    );
  }
}

/// The auth guard: if the user goes from signed in to signed out
/// (logout, or the server revoked the session), return to Login and
/// clear the back stack so Back can't return to a private screen.
class _AuthRedirector extends StatefulWidget {
  final Widget child;
  const _AuthRedirector({required this.child});

  @override
  State<_AuthRedirector> createState() => _AuthRedirectorState();
}

class _AuthRedirectorState extends State<_AuthRedirector> {
  AuthStatus? _previous;

  @override
  Widget build(BuildContext context) {
    final status = context.select<AuthProvider, AuthStatus>((a) => a.status);

    if (_previous == AuthStatus.signedIn && status == AuthStatus.signedOut) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppRoutes.navigatorKey.currentState?.pushNamedAndRemoveUntil(
          AppRoutes.login,
          (_) => false,
        );
      });
    }
    _previous = status;

    return widget.child;
  }
}
