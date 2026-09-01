/// Parseo de timestamps ISO-8601 del API a hora local del dispositivo.
library;

/// Convierte un valor de fecha del API a [DateTime] local.
///
/// Acepta strings con `Z` o offset explícito (`+00:00`, etc.).
/// Retorna `null` si el valor es nulo o no parseable.
DateTime? parseApiDateTimeToLocal(dynamic value) {
  if (value == null) return null;

  final text = value.toString().trim();
  if (text.isEmpty) return null;

  final parsed = DateTime.tryParse(text);
  if (parsed == null) return null;

  return parsed.toLocal();
}
