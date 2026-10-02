import 'package:intl/intl.dart';

import '../models/scan_record.dart';
import 'date_groups.dart';
import 'money.dart';

/// True if the scan matches every word of [query].
/// Searches the amount, denominations, designs, coin/bill, count and date.
bool scanMatchesQuery(ScanRecord scan, String query, {DateTime? now}) {
  final words = query
      .toLowerCase()
      .replaceAll('₱', '')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return true;

  final haystack = _haystack(scan, now ?? DateTime.now());
  return words.every(haystack.contains);
}

String _haystack(ScanRecord scan, DateTime now) {
  final parts = <String>[
    formatPeso(scan.totalCentavos),
    (scan.totalCentavos / 100).toStringAsFixed(2),
    '${scan.itemCount} items',
    dateGroupLabel(scan.createdAt, now),
    DateFormat('EEEE MMMM MMM d yyyy').format(scan.createdAt),
  ];
  for (final money in scan.detections.map((d) => d.money).toSet()) {
    parts
      ..add(money.displayName)
      ..add(money.shortValue)
      ..add(money.design)
      ..add(money.typeLabel);
  }
  return parts.join(' ').toLowerCase().replaceAll('₱', '');
}
