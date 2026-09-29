import '../models/detection.dart';
import '../models/money_class.dart';

/// Sum of all values, in centavos.
int totalCentavos(List<Detection> detections) =>
    detections.fold(0, (sum, d) => sum + d.valueCentavos);

/// How many of each class, e.g. {₱100 Polymer: 1, ₱10 BSP: 2}.
/// Sorted from highest value to lowest, ready for the breakdown table.
Map<MoneyClass, int> countByClass(List<Detection> detections) {
  final counts = <MoneyClass, int>{};
  for (final d in detections) {
    counts[d.money] = (counts[d.money] ?? 0) + 1;
  }
  final sorted = counts.entries.toList()
    ..sort((a, b) => b.key.valueCentavos.compareTo(a.key.valueCentavos));
  return {for (final e in sorted) e.key: e.value};
}

/// Number of coins vs bills in a scan (used for the result summary).
int countOfType(List<Detection> detections, MoneyType type) =>
    detections.where((d) => d.money.type == type).length;
