String frPlural(int count, String singular, String plural) {
  return '$count ${count == 1 ? singular : plural}';
}

String frCountLabel(int count, String singular, String plural) {
  return count == 1 ? singular : plural;
}

String frDays(int count) {
  return frPlural(count, 'jour', 'jours');
}

String frDocumentsProgress({
  required int missingCount,
  required int requiredCount,
}) {
  final missing = frPlural(
    missingCount,
    'document manquant',
    'documents manquants',
  );
  final required = frPlural(
    requiredCount,
    'document obligatoire',
    'documents obligatoires',
  );
  return '$missing sur $required';
}
