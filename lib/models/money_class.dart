import '../core/money.dart';

enum MoneyType { coin, bill }

/// One class the model can recognize (e.g. "₱5 NGC" or "₱100 Polymer").
class MoneyClass {
  /// Matches the "Class ID" column in the research table (1 to 19).
  final int id;

  /// Value in centavos (₱5 = 500, ₱1000 = 100000).
  final int valueCentavos;

  final MoneyType type;

  /// Short design label shown in lists and the breakdown ("BSP", "NGC",
  /// "NGC Series", "Polymer").
  final String design;

  /// Extra detail for the reference guide (Part 18).
  final String notes;

  const MoneyClass({
    required this.id,
    required this.valueCentavos,
    required this.type,
    required this.design,
    this.notes = '',
  });

  /// YOLO numbers its classes from 0, our table starts at 1.
  int get yoloIndex => id - 1;

  bool get isCoin => type == MoneyType.coin;
  bool get isBill => type == MoneyType.bill;

  String get shortValue => formatPesoShort(valueCentavos);

  /// "₱5 NGC", used in the breakdown table and history.
  String get displayName => '$shortValue $design';

  String get typeLabel => isCoin ? 'Coin' : 'Bill';

  // Two MoneyClass objects are the same if their ids match.
  @override
  bool operator ==(Object other) => other is MoneyClass && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// The single source of truth for everything the app can detect.
/// Order and ids MUST match your dataset labels (Part 22).
class MoneyClasses {
  MoneyClasses._();

  static const List<MoneyClass> all = [
    // ---- Coins (ids 1 to 10) ----
    MoneyClass(
      id: 1,
      valueCentavos: 5,
      type: MoneyType.coin,
      design: 'NGC',
      notes: 'NGC series',
    ),
    MoneyClass(
      id: 2,
      valueCentavos: 25,
      type: MoneyType.coin,
      design: 'NGC',
      notes: 'NGC series',
    ),
    MoneyClass(
      id: 3,
      valueCentavos: 100,
      type: MoneyType.coin,
      design: 'BSP',
      notes: '1995-2017',
    ),
    MoneyClass(
      id: 4,
      valueCentavos: 100,
      type: MoneyType.coin,
      design: 'NGC',
      notes: 'NGC series',
    ),
    MoneyClass(
      id: 5,
      valueCentavos: 500,
      type: MoneyType.coin,
      design: 'BSP',
      notes: '1995-2017',
    ),
    MoneyClass(
      id: 6,
      valueCentavos: 500,
      type: MoneyType.coin,
      design: 'NGC',
      notes: 'NGC Round (2017-2019)',
    ),
    MoneyClass(
      id: 7,
      valueCentavos: 500,
      type: MoneyType.coin,
      design: 'NGC',
      notes: 'NGC Nonagonal (2019+)',
    ),
    MoneyClass(
      id: 8,
      valueCentavos: 1000,
      type: MoneyType.coin,
      design: 'BSP',
      notes: 'Bonifacio + Mabini',
    ),
    MoneyClass(
      id: 9,
      valueCentavos: 1000,
      type: MoneyType.coin,
      design: 'NGC',
      notes: 'Mabini only',
    ),
    MoneyClass(
      id: 10,
      valueCentavos: 2000,
      type: MoneyType.coin,
      design: 'NGC',
      notes: 'NGC series',
    ),

    // ---- Bills: NGC Paper series (ids 11 to 15) ----
    MoneyClass(
      id: 11,
      valueCentavos: 2000,
      type: MoneyType.bill,
      design: 'NGC Series',
    ),
    MoneyClass(
      id: 12,
      valueCentavos: 5000,
      type: MoneyType.bill,
      design: 'NGC Series',
    ),
    MoneyClass(
      id: 13,
      valueCentavos: 10000,
      type: MoneyType.bill,
      design: 'NGC Series',
    ),
    MoneyClass(
      id: 14,
      valueCentavos: 50000,
      type: MoneyType.bill,
      design: 'NGC Series',
    ),
    MoneyClass(
      id: 15,
      valueCentavos: 100000,
      type: MoneyType.bill,
      design: 'NGC Series',
    ),

    // ---- Bills: Polymer (ids 16 to 19) ----
    MoneyClass(
      id: 16,
      valueCentavos: 5000,
      type: MoneyType.bill,
      design: 'Polymer',
    ),
    MoneyClass(
      id: 17,
      valueCentavos: 10000,
      type: MoneyType.bill,
      design: 'Polymer',
    ),
    MoneyClass(
      id: 18,
      valueCentavos: 50000,
      type: MoneyType.bill,
      design: 'Polymer',
    ),
    MoneyClass(
      id: 19,
      valueCentavos: 100000,
      type: MoneyType.bill,
      design: 'Polymer',
    ),
  ];

  static final List<MoneyClass> coins = all.where((c) => c.isCoin).toList();
  static final List<MoneyClass> bills = all.where((c) => c.isBill).toList();

  static MoneyClass byId(int id) => all.firstWhere((c) => c.id == id);
}
