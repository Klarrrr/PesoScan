import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_routes.dart';
import 'core/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/settings_provider.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  // Required before using plugins (storage, camera, Supabase).
  WidgetsFlutterBinding.ensureInitialized();

  // Load saved settings BEFORE the first screen so the theme doesn't flash.
  final settings = SettingsProvider();
  await settings.load();

  // Start the backend connection (restores a saved login if there is one).
  await SupabaseService.init();

  runApp(
    // MultiProvider puts our state at the top of the app, so any screen can use it.
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const PesoScanApp(),
    ),
  );
}

class PesoScanApp extends StatelessWidget {
  const PesoScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    // select = rebuild only when the theme mode changes, not for other settings.
    final themeMode = context.select<SettingsProvider, ThemeMode>(
      (s) => s.themeMode,
    );

    return MaterialApp(
      title: 'PesoScan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
