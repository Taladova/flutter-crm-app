String formatCurrencyText(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';

  final normalized = trimmed
      .replaceAll(RegExp(r'\s*€\s*'), ' €')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  if (normalized.contains('€')) return normalized;
  return '$normalized €';
}

String formatCurrencyAmount(double amount) {
  if (amount <= 0) return '0 €';

  if (amount >= 1000) {
    final value = amount / 1000;
    final formatted = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1).replaceAll('.', ',');
    return '${formatted}k €';
  }

  return '${amount.round()} €';
}
