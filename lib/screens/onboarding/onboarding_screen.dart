import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_images.dart';
import '../../core/app_routes.dart';
import '../../core/money.dart';
import '../../models/money_class.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/app_image.dart';
import '../../widgets/gold_button.dart';
import '../../widgets/tip_chip.dart';

class _OnboardingPage {
  final String image; // image_N slot
  final IconData fallbackIcon; // shown until the image file exists
  final String title;
  final String body;
  final String tip;
  const _OnboardingPage(
    this.image,
    this.fallbackIcon,
    this.title,
    this.body,
    this.tip,
  );
}

/// Page 3 says "coins (₱0.05-₱10) or bills (₱20-₱1000)". We build the range
/// from the class list, so it updates itself if you edit the classes.
String _range(Iterable<MoneyClass> classes) {
  final values = classes.map((c) => c.valueCentavos);
  return '${formatPesoShort(values.reduce(min))}–${formatPesoShort(values.reduce(max))}';
}

List<_OnboardingPage> _buildPages() => [
  const _OnboardingPage(
    AppImages.onboardingFlat,
    Icons.account_balance_rounded,
    'Place Currency on a Flat Surface',
    'Spread coins and bills flat on a plain, non-reflective background. '
        'Avoid patterned or glossy surfaces for best results.',
    'Plain white or dark backgrounds work best.',
  ),
  const _OnboardingPage(
    AppImages.onboardingSpacing,
    Icons.swap_horiz_rounded,
    'Avoid Overlapping',
    'PesoScan detects each coin and bill individually. Overlapping items '
        'may reduce accuracy — separate them slightly for a precise count.',
    'Leave at least 5mm between each item.',
  ),
  _OnboardingPage(
    AppImages.onboardingInstant,
    Icons.bolt_rounded,
    'Instant Value Calculation',
    'Point your camera at Philippine coins (${_range(MoneyClasses.coins)}) '
        'or bills (${_range(MoneyClasses.bills)}) and watch PesoScan '
        'calculate the total in real time.',
    'Powered by YOLO26 deep learning.',
  ),
];

/// Pages 3-5 of the prototype.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  late final List<_OnboardingPage> _pages = _buildPages();
  int _index = 0;

  bool get _isLast => _index == _pages.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Remember that first-run setup is finished, then enter the app.
  /// (In Part 7 this goes through the login screen first.)
  Future<void> _finish() async {
    await context.read<SettingsProvider>().setOnboardingDone(true);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip stays visible on every page, like the prototype.
            SizedBox(
              height: 56,
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _finish,
                  child: Text('Skip', style: TextStyle(color: c.textMuted)),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final page = _pages[i];
                  // Scrollable so small phones never overflow.
                  return Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 116,
                            height: 116,
                            decoration: BoxDecoration(
                              color: c.chip,
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: c.border),
                            ),
                            alignment: Alignment.center,
                            child: AppImage(
                              page.image,
                              width: 56,
                              height: 56,
                              fallback: Icon(
                                page.fallbackIcon,
                                size: 48,
                                color: c.gold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),
                          Text(
                            page.title,
                            textAlign: TextAlign.center,
                            style: text.headlineSmall,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            page.body,
                            textAlign: TextAlign.center,
                            style: text.bodyLarge,
                          ),
                          const SizedBox(height: 24),
                          TipChip(page.tip),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Page dots: the active one is a wide gold pill.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 28 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? c.gold : c.textMuted.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: GoldButton(
                label: _isLast ? 'Get Started' : 'Next',
                onPressed: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
