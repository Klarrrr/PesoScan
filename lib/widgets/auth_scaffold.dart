import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_images.dart';
import '../core/app_theme.dart';
import 'app_image.dart';
import 'offline_banner.dart';

/// Logo that uses assets/images/image_1.png, or a drawn gold coin until you add it.
class BrandLogo extends StatelessWidget {
  final double size;
  const BrandLogo({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) {
    return AppImage(
      AppImages.logo,
      width: size,
      height: size,
      fallback: _DrawnCoin(size: size),
    );
  }
}

class _DrawnCoin extends StatelessWidget {
  final double size;
  const _DrawnCoin({required this.size});

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
          width: size * 0.70,
          height: size * 0.70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.background,
          ),
          child: Center(
            child: Container(
              width: size * 0.48,
              height: size * 0.48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: c.goldGradient,
              ),
              child: Center(
                child: Text(
                  '₱',
                  style: TextStyle(
                    fontSize: size * 0.23,
                    fontWeight: FontWeight.w800,
                    color: c.background,
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

/// Shared layout for every auth screen: logo, wordmark, title, subtitle, content.
class AuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool showBack;

  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: showBack ? AppBar() : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const OfflineBanner(),
                  const Center(child: BrandLogo(size: 72)),
                  const SizedBox(height: 14),
                  Center(
                    child: Text.rich(
                      TextSpan(
                        style: const TextStyle(
                          fontFamily: AppFonts.heading,
                          fontWeight: FontWeight.w700,
                          fontSize: 28,
                        ),
                        children: [
                          TextSpan(
                            text: 'Peso',
                            style: TextStyle(color: c.textPrimary),
                          ),
                          TextSpan(
                            text: 'Scan',
                            style: TextStyle(color: c.gold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: text.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: text.bodyMedium,
                  ),
                  const SizedBox(height: 28),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Red box for errors, or green box when `success` is true.
class ErrorBanner extends StatelessWidget {
  final String message;
  final bool success;
  const ErrorBanner({super.key, required this.message, this.success = false});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = success ? c.success : c.danger;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            success ? Icons.check_circle_outline : Icons.error_outline,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TextStyle(color: color, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
