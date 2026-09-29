import 'package:intl/intl.dart';

// IMPORTANT DESIGN CHOICE:
// We store money as whole CENTAVOS (int), never as double.
// Doubles have rounding errors (0.1 + 0.2 = 0.30000000000000004),
// which is unacceptable for a calculator app. 100 centavos = ₱1.

final NumberFormat _pesoFormat = NumberFormat.currency(
  locale: 'en_PH',
  symbol: '₱',
  decimalDigits: 2,
);

/// Full format for totals: 4625 -> "₱46.25", 123456 -> "₱1,234.56"
String formatPeso(int centavos) => _pesoFormat.format(centavos / 100);

/// Short format for labels: 500 -> "₱5", 25 -> "₱0.25"
String formatPesoShort(int centavos) {
  if (centavos % 100 == 0) return '₱${centavos ~/ 100}';
  return '₱${(centavos / 100).toStringAsFixed(2)}';
}
