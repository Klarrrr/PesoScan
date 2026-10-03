// ignore_for_file: duplicate_ignore, unused_import

import 'package:flutter/material.dart';

import '../screens/auth/code_entry_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/new_password_screen.dart';
import '../screens/auth/register_screen.dart';
//import '../screens/home/dev_home_screen.dart';
import '../screens/shell/main_shell.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/onboarding/permission_screen.dart';
import '../screens/onboarding/splash_screen.dart';
import '../widgets/placeholder_screen.dart';
// ignore: unused_import
import '../screens/scanner/scanner_screen.dart';

// ignore: unused_import
import '../models/scan_record.dart';
import '../screens/history/scan_detail_screen.dart';
import '../screens/stats/statistics_screen.dart';
import '../screens/info/currency_reference_screen.dart';

/// Every screen has a name. Navigate with:
///   Navigator.pushNamed(context, AppRoutes.history);
class AppRoutes {
  AppRoutes._();

  /// Lets code OUTSIDE a screen navigate (used by the auth guard in main.dart).
  static final navigatorKey = GlobalKey<NavigatorState>();

  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const permission = '/permission';
  static const login = '/login';
  static const register = '/register';
  static const codeEntry = '/code';
  static const forgotPassword = '/forgot-password';
  static const newPassword = '/new-password';
  static const home = '/home';
  static const scanner = '/scanner';
  static const scanResult = '/scan-result';
  static const history = '/history';
  static const historyDetail = '/history-detail';
  static const statistics = '/statistics';
  static const guide = '/guide';
  static const help = '/help';
  static const settings = '/settings';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    Widget screen;
    switch (settings.name) {
      case splash:
        screen = const SplashScreen();
      case historyDetail:
        final record = settings.arguments;
        screen = record is ScanRecord
            ? ScanDetailScreen(record: record)
            : const PlaceholderScreen(title: 'Scan not found');
      case onboarding:
        screen = const OnboardingScreen();
      case permission:
        screen = const CameraPermissionScreen();
      case login:
        screen = const LoginScreen();
      case register:
        screen = const RegisterScreen();
      case scanner:
        screen = const ScannerScreen();
      case forgotPassword:
        screen = const ForgotPasswordScreen();
      case newPassword:
        screen = const NewPasswordScreen();
      case statistics:
        screen = const StatisticsScreen();
      case guide:
        screen = const CurrencyReferenceScreen();
      case codeEntry:
        final args = settings.arguments;
        screen = args is CodeEntryArgs
            ? CodeEntryScreen(args: args)
            : const PlaceholderScreen(title: 'Missing code details');
      case home:
        screen = const MainShell();
      default:
        screen = PlaceholderScreen(title: settings.name ?? 'Unknown');
    }
    return MaterialPageRoute(builder: (_) => screen, settings: settings);
  }
}
