import 'package:intl/intl.dart';

import '../models/scan_record.dart';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Monday of the week that contains [d].
DateTime _weekStart(DateTime d) =>
    DateTime(d.year, d.month, d.day - (d.weekday - 1));

/// "Today", "Yesterday", "This Week", "Last Week", or "September 2026".
String dateGroupLabel(DateTime date, DateTime now) {
  final daysAgo = _day(now).difference(_day(date)).inDays;
  if (daysAgo == 0) return 'Today';
  if (daysAgo == 1) return 'Yesterday';

  final weeksApart = _weekStart(now).difference(_weekStart(date)).inDays ~/ 7;
  if (daysAgo > 0 && weeksApart == 0) return 'This Week';
  if (weeksApart == 1) return 'Last Week';
  return DateFormat('MMMM yyyy').format(date);
}

class HistoryGroup {
  final String label;
  final List<ScanRecord> scans;
  HistoryGroup(this.label, this.scans);
}

/// Splits a NEWEST-FIRST list into labelled groups.
List<HistoryGroup> groupScans(List<ScanRecord> scans, DateTime now) {
  final groups = <HistoryGroup>[];
  for (final scan in scans) {
    final label = dateGroupLabel(scan.createdAt, now);
    if (groups.isNotEmpty && groups.last.label == label) {
      groups.last.scans.add(scan);
    } else {
      groups.add(HistoryGroup(label, [scan]));
    }
  }
  return groups;
}
