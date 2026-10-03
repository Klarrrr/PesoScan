import 'package:flutter/material.dart';

import '../../data/info_section.dart';
import '../../data/legal_content.dart';
import '../../widgets/expandable_section.dart';
import '../../widgets/screen_header.dart';

/// Used for both the Terms of Service and the Privacy Policy.
class LegalScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<InfoSection> sections;

  const LegalScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            ScreenHeader(title: title, subtitle: subtitle),
            const SizedBox(height: 14),
            Text('Last updated: $legalLastUpdated', style: text.labelSmall),
            const SizedBox(height: 14),
            for (final (i, section) in sections.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ExpandableSection(
                  key: Key('legal-$i'),
                  title: section.title,
                  body: section.body,
                  initiallyExpanded: i == 0, // the first one is open
                ),
              ),
          ],
        ),
      ),
    );
  }
}
