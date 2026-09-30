import 'package:flutter/material.dart';

/// Stand-in for screens we haven't built yet.
class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.construction, size: 56),
            const SizedBox(height: 12),
            Text('Coming soon', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
