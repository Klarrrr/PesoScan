import 'dart:math';

// ignore: unused_import
import '../../providers/auth_provider.dart';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_images.dart';
import '../../core/app_routes.dart';
import '../../core/app_theme.dart';
import '../../core/constants.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/app_image.dart';

/// Page 1 of the prototype. Doubles as the app's loading screen:
/// orbiting dots around the logo + a gold progress line that fills up.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

// TickerProviderStateMixin (not "Single...") because we use TWO controllers.
class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // The splash always uses the dark palette, even in light mode (as designed).
  static const _c = PesoColors.dark;

  late final AnimationController _progress; // 0 -> 1 while "loading"
  late final AnimationController _orbit; // loops forever
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  String _version = '';

  @override
  void initState() {
    super.initState();

    _progress = AnimationController(
      vsync: this,
      duration: AppConstants.splashDuration,
    );
    _orbit = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _fade = CurvedAnimation(
      parent: _progress,
      curve: const Interval(0, 0.35, curve: Curves.easeOut),
    );
    _scale = Tween<double>(begin: 0.85, end: 1).animate(
      CurvedAnimation(
        parent: _progress,
        curve: const Interval(0, 0.4, curve: Curves.easeOutBack),
      ),
    );

    _start();
  }

  Future<void> _start() async {
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = 'v${info.version}');
    });

    // Later (Part 22) the real model loads here too, and the splash waits for it.
    await _progress.forward();
    if (!mounted) return;

    final done = context.read<SettingsProvider>().onboardingDone;
    final signedIn = context.read<AuthProvider>().isSignedIn;

    // First run: permission -> onboarding -> login.
    // Later runs: home if logged in, otherwise the login screen.
    final String next;
    if (!done) {
      next = AppRoutes.permission;
    } else if (signedIn) {
      next = AppRoutes.home;
    } else {
      next = AppRoutes.login;
    }
    Navigator.pushReplacementNamed(context, next);
  }

  @override
  void dispose() {
    _progress.dispose();
    _orbit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF030B1C), Color(0xFF0A1226), Color(0xFF081633)],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Soft golden glow behind the logo.
            Center(
              child: Container(
                width: 340,
                height: 340,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _c.gold.withValues(alpha: 0.14),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 5),
                  FadeTransition(
                    opacity: _fade,
                    child: ScaleTransition(
                      scale: _scale,
                      child: Column(
                        children: [
                          SizedBox(
                            width: 210,
                            height: 210,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                AnimatedBuilder(
                                  animation: _orbit,
                                  builder: (context, _) => CustomPaint(
                                    size: const Size(210, 210),
                                    painter: _OrbitPainter(
                                      _orbit.value,
                                      _c.gold,
                                    ),
                                  ),
                                ),
                                const AppImage(
                                  AppImages.logo,
                                  width: 112,
                                  height: 112,
                                  fallback: _CoinLogo(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text.rich(
                            TextSpan(
                              style: const TextStyle(
                                fontFamily: AppFonts.heading,
                                fontWeight: FontWeight.w700,
                                fontSize: 42,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Peso',
                                  style: TextStyle(color: _c.textPrimary),
                                ),
                                TextSpan(
                                  text: 'Scan',
                                  style: TextStyle(color: _c.gold),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'COIN & BILL DETECTION',
                            style: TextStyle(
                              fontSize: 13,
                              letterSpacing: 3,
                              color: _c.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(flex: 3),
                  // The loading line.
                  AnimatedBuilder(
                    animation: _progress,
                    builder: (context, _) {
                      final value = Curves.easeInOut.transform(_progress.value);
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: SizedBox(
                          width: 240,
                          height: 3,
                          child: Stack(
                            children: [
                              Container(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                              FractionallySizedBox(
                                widthFactor: value,
                                child: Container(color: _c.gold),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _version.isEmpty ? '' : '$_version — YOLO26 Powered',
                    style: AppText.mono(
                      size: 12,
                      weight: FontWeight.w400,
                      color: _c.textMuted,
                    ),
                  ),
                  const Spacer(flex: 3),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Six small dots that circle the logo.
class _OrbitPainter extends CustomPainter {
  final double t; // 0..1 around the circle
  final Color color;
  _OrbitPainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 8;
    const count = 6;
    for (var i = 0; i < count; i++) {
      final angle = 2 * pi * (t + i / count);
      final pos = center + Offset(cos(angle), sin(angle)) * radius;
      canvas.drawCircle(
        pos,
        3.0 + (i % 3),
        Paint()..color = color.withValues(alpha: 0.35),
      );
    }
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => old.t != t;
}

/// Built-in gold coin logo, shown until you add assets/images/image_1.png.
class _CoinLogo extends StatelessWidget {
  const _CoinLogo();

  @override
  Widget build(BuildContext context) {
    const c = PesoColors.dark;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: c.goldGradient,
      ),
      child: Center(
        child: Container(
          width: 78,
          height: 78,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF0A1226),
          ),
          child: Center(
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: c.goldGradient,
              ),
              child: const Center(
                child: Text(
                  '₱',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0A1226),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
