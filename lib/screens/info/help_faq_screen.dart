import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../data/help_content.dart';
import '../../data/legal_content.dart';
import '../../widgets/expandable_section.dart';
import '../../widgets/screen_header.dart';

/// Page 15 of the prototype.
class HelpFaqScreen extends StatelessWidget {
  const HelpFaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final faqs = faqItems();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            const ScreenHeader(
              title: 'Help & FAQ',
              subtitle: 'Scanning tips and answers',
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.chip,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: c.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Scanning Tips',
                    style: text.titleMedium?.copyWith(color: c.gold),
                  ),
                  const SizedBox(height: 10),
                  for (final tip in quickTips)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('✦  ', style: TextStyle(color: c.gold)),
                          Expanded(child: Text(tip, style: text.bodyMedium)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text('Frequently Asked Questions', style: text.titleMedium),
            const SizedBox(height: 12),
            for (final (i, item) in faqs.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ExpandableSection(
                  key: Key('faq-$i'),
                  title: item.title,
                  body: item.body,
                ),
              ),
            const SizedBox(height: 10),
            Text(
              'Still stuck? Email us at $contactEmail.',
              textAlign: TextAlign.center,
              style: text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
