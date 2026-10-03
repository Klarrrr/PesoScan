/// Short text shown in the Currency Reference, one entry per class id.
///
/// ⚠️ CHECK THIS FILE against the Bangko Sentral ng Pilipinas (bsp.gov.ph)
/// before you present: it is the one place with facts about the real money.
class ReferenceInfo {
  /// When or which series.
  final String period;

  /// What to look for.
  final String look;

  const ReferenceInfo(this.period, this.look);
}

const Map<int, ReferenceInfo> referenceInfo = {
  // ---- Coins ----
  1: ReferenceInfo('NGC series', 'The smallest coin PesoScan counts.'),
  2: ReferenceInfo('NGC series', 'The second-smallest coin PesoScan counts.'),
  3: ReferenceInfo('1995–2017', 'Round coin with the portrait of José Rizal.'),
  4: ReferenceInfo(
    'NGC and NGC Minted',
    'Round coin with the portrait of José Rizal.',
  ),
  5: ReferenceInfo(
    '1995–2017',
    'Round coin with the portrait of Emilio Aguinaldo.',
  ),
  6: ReferenceInfo(
    'Round 2017–2019, nine-sided 2019+',
    'Emilio Aguinaldo. Both the round and the nine-sided coin count as this item.',
  ),
  7: ReferenceInfo(
    'BSP series',
    'Two-colour coin with Andrés Bonifacio and Apolinario Mabini.',
  ),
  8: ReferenceInfo(
    'NGC series',
    'Two-colour coin with Apolinario Mabini only.',
  ),
  9: ReferenceInfo(
    'NGC series, 2019+',
    'Two-colour coin with Manuel L. Quezon.',
  ),

  // ---- Bills (NGC series) ----
  10: ReferenceInfo('NGC series', 'Orange note with Manuel L. Quezon.'),
  11: ReferenceInfo('NGC series', 'Red note with Sergio Osmeña.'),
  12: ReferenceInfo('NGC series', 'Violet note with Manuel A. Roxas.'),
  13: ReferenceInfo('NGC series', 'Green note with Diosdado Macapagal.'),
  14: ReferenceInfo(
    'NGC series',
    'Yellow note with Corazon and Benigno Aquino Jr.',
  ),
  15: ReferenceInfo(
    'NGC series',
    'Blue note with Josefa Llanes Escoda, José Abad Santos and Vicente Lim.',
  ),

  // ---- Bills (polymer) ----
  16: ReferenceInfo(
    'Polymer',
    'Plastic (polymer) note, red, with a clear window.',
  ),
  17: ReferenceInfo(
    'Polymer',
    'Plastic (polymer) note, violet, with a clear window.',
  ),
  18: ReferenceInfo(
    'Polymer',
    'Plastic (polymer) note, yellow, with a clear window.',
  ),
  19: ReferenceInfo(
    'Polymer',
    'Plastic (polymer) note, blue, with a clear window.',
  ),
};

const ReferenceInfo _unknown = ReferenceInfo('', '');

ReferenceInfo referenceFor(int classId) => referenceInfo[classId] ?? _unknown;
