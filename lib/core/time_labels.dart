import 'package:intl/intl.dart';

/// "09:55 AM" for today, "Yesterday, 09:55 AM", or "Sep 28, 09:55 AM".
String scanTimeLabel(DateTime time, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final clock = DateFormat('hh:mm a').format(time);

  DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);
  final daysAgo = dayOf(today).difference(dayOf(time)).inDays;

  if (daysAgo == 0) return clock;
  if (daysAgo == 1) return 'Yesterday, $clock';
  return '${DateFormat('MMM d').format(time)}, $clock';
}
