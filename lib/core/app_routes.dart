import 'package:flutter/material.dart';

import '../screens/home/dev_home_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/onboarding/permission_screen.dart';
import '../screens/onboarding/splash_screen.dart';
import '../widgets/placeholder_screen.dart';

/// Every screen has a name. Navigate with:
///   Navigator.pushNamed(context, AppRoutes.history);
class AppRoutes {
  AppRoutes._();

  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const permission = '/permission';
  static const login = '/login';
  static const register = '/register';
  static const verifyCode = '/verify-code';
  static const home = '/home';
  static const scanner = '/scanner';
  static const scanResult = '/scan-result';
  static const history = '/history';
  static const historyDetail = '/history-detail';
  static const statistics = '/statistics';
  static const guide = '/guide';
  static const help = '/help';
  static const settings = '/settings';

  /// Called by MaterialApp whenever we navigate to a named route.
  /// In later parts we replace each placeholder with the real screen.
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    Widget screen;
    switch (settings.name) {
      case splash:
        screen = const SplashScreen();
      case onboarding:
        screen = const OnboardingScreen();
      case permission:
        screen = const CameraPermissionScreen();
      case home:
        screen = const DevHomeScreen();
      default:
        screen = PlaceholderScreen(title: settings.name ?? 'Unknown');
    }
    return MaterialPageRoute(builder: (_) => screen, settings: settings);
  }
}
