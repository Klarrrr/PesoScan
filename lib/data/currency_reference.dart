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
  // ---- Coins (10 Types) ----
  // 1: coin_005_ngc
  1: ReferenceInfo(
    'NGC series',
    'Small copper-toned coin with Katmon flower and BSP logo.',
  ),
  // 2: coin_025_ngc
  2: ReferenceInfo(
    'NGC series',
    'Plain-edged coin with Katmon flower and stylized BSP logo.',
  ),
  // 3: coin_1_bsp
  3: ReferenceInfo(
    '1995–2017 (BSP)',
    'Round coin with the portrait of José Rizal and reeded edge.',
  ),
  // 4: coin_1_ngc
  4: ReferenceInfo(
    'NGC series (2018+)',
    'Nickel-plated coin with José Rizal and the Kalingag plant.',
  ),
  // 5: coin_5_bsp
  5: ReferenceInfo(
    '1995–2017 (BSP)',
    'Gold/brass-colored coin with the portrait of Emilio Aguinaldo.',
  ),
  // 6: coin_5_ngc_round
  6: ReferenceInfo(
    'NGC series (2017–2019)',
    'Round silver coin with Andrés Bonifacio and Tayabak plant.',
  ),
  // 7: coin_5_ngc_nonagonal
  7: ReferenceInfo(
    'NGC series (2019+)',
    'Nine-sided (nonagonal) silver coin with Andrés Bonifacio.',
  ),
  // 8: coin_10_bsp
  8: ReferenceInfo(
    'BSP series (2000–2017)',
    'Two-colour (bi-metallic) coin with Andrés Bonifacio and Apolinario Mabini.',
  ),
  // 9: coin_10_ngc
  9: ReferenceInfo(
    'NGC series (2018+)',
    'Single-colour silver coin with Apolinario Mabini only.',
  ),
  // 10: coin_20_ngc
  10: ReferenceInfo(
    'NGC series (2019+)',
    'Two-colour coin with bronze center, silver ring, and Manuel L. Quezon.',
  ),

  // ---- Bills / Banknotes (NGC Paper Series) ----
  // 11: bill_20_ngc
  11: ReferenceInfo(
    'NGC series (Paper)',
    'Orange note with Manuel L. Quezon, Banaue Rice Terraces, and Palm Civet.',
  ),
  // 12: bill_50_ngc
  12: ReferenceInfo(
    'NGC series (Paper)',
    'Red note with Sergio Osmeña, Taal Lake, and Giant Trevally (Maliputo).',
  ),
  // 13: bill_100_ngc
  13: ReferenceInfo(
    'NGC series (Paper)',
    'Violet note with Manuel A. Roxas, Mayon Volcano, and Whale Shark (Butanding).',
  ),
  // 14: bill_500_ngc
  14: ReferenceInfo(
    'NGC series (Paper)',
    'Yellow note with Corazon and Benigno Aquino Jr., Subterranean River, and Blue-naped Parrot.',
  ),
  // 15: bill_1000_ngc
  15: ReferenceInfo(
    'NGC series (Paper)',
    'Blue note with Josefa Llanes Escoda, José Abad Santos, and Vicente Lim.',
  ),

  // ---- Bills / Banknotes (Polymer Series) ----
  // 16: bill_50_polymer
  16: ReferenceInfo(
    'Polymer',
    'Plastic (polymer) red note with a transparent security window and tactile features.',
  ),
  // 17: bill_100_polymer
  17: ReferenceInfo(
    'Polymer',
    'Plastic (polymer) violet note with a clear window and enhanced micro-printing.',
  ),
  // 18: bill_500_polymer
  18: ReferenceInfo(
    'Polymer',
    'Plastic (polymer) yellow note with clear window accents and fauna designs.',
  ),
  // 19: bill_1000_polymer
  19: ReferenceInfo(
    'Polymer',
    'Plastic (polymer) blue note featuring the Philippine Eagle and Tubbataha Reefs.',
  ),
};

const ReferenceInfo _unknown = ReferenceInfo('', '');

ReferenceInfo referenceFor(int classId) => referenceInfo[classId] ?? _unknown;
