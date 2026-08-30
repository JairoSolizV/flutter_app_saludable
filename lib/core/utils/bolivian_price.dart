/// Formato visual de precios en bolivianos. No usa `$`.
class BolivianPrice {
  BolivianPrice._();

  static String formatBs(num amount) {
    final fixed = amount.toStringAsFixed(2).replaceAll('.', ',');
    return 'Bs $fixed';
  }

  /// `effectivePrice <= 0` = backend "sin precio configurado".
  static String label(num amount) {
    if (!isConfigured(amount)) return 'Precio no configurado';
    return formatBs(amount);
  }

  static bool isConfigured(num amount) => amount > 0;
}
