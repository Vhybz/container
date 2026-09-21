enum WeightUnit { kg, lb, g, unit }

class WeightConverter {
  static double toKg(double lbs) => lbs * 0.453592;
  static double toLbs(double kgs) => kgs * 2.20462;
  static double toLb(double kgs) => toLbs(kgs);
  static double fromG(double g) => g / 1000;
  static double toG(double kg) => kg * 1000;

  static double convert({
    required double value,
    required WeightUnit from,
    required WeightUnit to,
  }) {
    if (from == to) return value;
    
    // Normalize to KG first
    double kg;
    switch (from) {
      case WeightUnit.kg: kg = value; break;
      case WeightUnit.lb: kg = toKg(value); break;
      case WeightUnit.g: kg = fromG(value); break;
      case WeightUnit.unit: kg = value; break; // Units stay as is
    }

    // Convert to target
    switch (to) {
      case WeightUnit.kg: return kg;
      case WeightUnit.lb: return toLbs(kg);
      case WeightUnit.g: return toG(kg);
      case WeightUnit.unit: return kg;
    }
  }

  static String formatShort(
    double weight, {
    String? unit,
    String? productName,
    String? category,
  }) {
    final lowerUnit = unit?.toLowerCase().trim() ?? '';
    final lowerName = productName?.toLowerCase().trim() ?? '';
    final lowerCat = category?.toLowerCase().trim() ?? '';

    final count = weight == weight.roundToDouble() ? weight.toInt() : weight;

    // 1. Shave service detection
    if (lowerUnit == 'shave' || lowerUnit == 'shaves' ||
        lowerName.contains('shave') || lowerName.contains('shaving') ||
        (lowerName.contains('beard') && !lowerName.contains('oil'))) {
      return count == 1 ? '1 shave' : '$count shaves';
    }

    // 2. Haircut / Barber cut service detection
    if (lowerUnit == 'cut' || lowerUnit == 'cuts' ||
        lowerCat.contains('barber') ||
        lowerCat.contains('hair') ||
        lowerName.contains('cut') ||
        lowerName.contains('haircut') ||
        lowerName.contains('fade') ||
        lowerName.contains('trim') ||
        lowerName.contains('shampoo') ||
        lowerName.contains('dye') ||
        lowerName.contains('wave') ||
        lowerName.contains('sponge') ||
        lowerName.contains('styling')) {
      return count == 1 ? '1 cut' : '$count cuts';
    }

    // 3. Tech repair service detection
    if (lowerUnit == 'repair' || lowerUnit == 'repairs' ||
        ((lowerCat.contains('repair') || lowerCat.contains('tech')) &&
         (lowerUnit == 'service' || lowerUnit == 'unit'))) {
      return count == 1 ? '1 repair' : '$count repairs';
    }

    // 4. Other services
    if (lowerUnit == 'service' || lowerUnit == 'services') {
      return count == 1 ? '1 service' : '$count services';
    }

    // 5. Piece / Unit counts
    if (lowerUnit == 'unit' || lowerUnit == 'units' || lowerUnit == 'qty' || lowerUnit == 'pcs' || lowerUnit == 'pc') {
      return count == 1 ? '1 pc' : '$count pcs';
    }

    // 6. Weight (g / kg / t)
    if (lowerUnit == 'g' || (weight < 0.1 && weight > 0 && (lowerUnit.isEmpty || lowerUnit == 'kg'))) {
      return '${(weight * 1000).toStringAsFixed(0)}g';
    }
    if (weight >= 1000 && lowerUnit != 'g') {
      return '${(weight / 1000).toStringAsFixed(1)}t';
    }
    if (lowerUnit == 'kg') {
      return '${weight.toStringAsFixed(1)}kg';
    }

    if (lowerUnit.isNotEmpty) {
      return count == 1 ? '$count $lowerUnit' : '$count ${lowerUnit}s';
    }

    return count == 1 ? '$count pc' : '$count pcs';
  }
}

class IdGenerator {
  static String generate({String prefix = 'ID'}) {
    final now = DateTime.now();
    final dateStr = '${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final random = (100 + (now.microsecond % 900)).toString();
    return '$prefix-$dateStr-$timeStr-$random';
  }
}
