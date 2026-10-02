import '../models/scan_record.dart';

class DenominationCount {
  final int valueCentavos;
  final int count;
  const DenominationCount(this.valueCentavos, this.count);
}

class ScanStats {
  final int sessions;
  final int items;
  final int totalCentavos;

  /// Most frequent first.
  final List<DenominationCount> byDenomination;

  const ScanStats({
    required this.sessions,
    required this.items,
    required this.totalCentavos,
    required this.byDenomination,
  });

  bool get isEmpty => sessions == 0;

  int get averageCentavos =>
      sessions == 0 ? 0 : (totalCentavos / sessions).round();
}

ScanStats computeStats(List<ScanRecord> scans) {
  var total = 0;
  var items = 0;
  final counts = <int, int>{};

  for (final scan in scans) {
    total += scan.totalCentavos;
    items += scan.itemCount;
    for (final d in scan.detections) {
      counts[d.valueCentavos] = (counts[d.valueCentavos] ?? 0) + 1;
    }
  }

  final byDenomination =
      [for (final e in counts.entries) DenominationCount(e.key, e.value)]
        ..sort((a, b) {
          final byCount = b.count.compareTo(a.count);
          return byCount != 0
              ? byCount
              : b.valueCentavos.compareTo(a.valueCentavos);
        });

  return ScanStats(
    sessions: scans.length,
    items: items,
    totalCentavos: total,
    byDenomination: byDenomination,
  );
}
