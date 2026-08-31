import 'package:flutter/services.dart';

import 'name_pattern.dart';

/// Formatters de UI reutilizables para limitar qué se puede escribir en un
/// campo. Regla: bloquear lo IMPOSIBLE al escribir; nunca transformar un
/// valor que ya es válido (eso queda para el validator, si hace falta).
class AppFormatters {
  AppFormatters._();

  /// Entero (solo dígitos).
  static List<TextInputFormatter> entero(int maxDigitos) => [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(maxDigitos),
      ];

  /// Decimal con hasta 2 decimales. Acepta punto o coma como separador.
  ///
  /// No usa FilteringTextInputFormatter.allow con un regex ancla (^...$):
  /// ese formatter reemplaza cualquier tramo que NO matchee el patrón
  /// completo, y con un regex de estructura (no de caracteres sueltos) eso
  /// borra el campo ENTERO en cuanto el texto no calza (por ejemplo, al
  /// escribir un tercer decimal). Este formatter en cambio rechaza el
  /// cambio y mantiene el valor anterior, que es lo seguro.
  static List<TextInputFormatter> decimal({int enteros = 6}) =>
      [_DecimalInputFormatter(enteros)];

  /// Teléfono boliviano: hasta 8 dígitos.
  static List<TextInputFormatter> get telefono => [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(8),
      ];

  /// Solo letras. Incluye acentos, ñ, ü, y permite ' y - (María-José, D'Angelo).
  static List<TextInputFormatter> letras(int max) => [
        FilteringTextInputFormatter.allow(NamePattern.inputCharacters),
        LengthLimitingTextInputFormatter(max),
      ];

  /// Correo, URL o usuario de red social: sin espacios.
  static List<TextInputFormatter> sinEspacios(int max) => [
        FilteringTextInputFormatter.deny(RegExp(r'\s')),
        LengthLimitingTextInputFormatter(max),
      ];

  /// Texto libre / alfanumérico: solo tope de largo.
  static List<TextInputFormatter> largo(int max) =>
      [LengthLimitingTextInputFormatter(max)];
}

class _DecimalInputFormatter extends TextInputFormatter {
  _DecimalInputFormatter(int enteros)
      : _pattern = RegExp(r'^\d{0,' + '$enteros' + r'}([.,]\d{0,2})?$');

  final RegExp _pattern;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty || _pattern.hasMatch(newValue.text)) {
      return newValue;
    }
    return oldValue;
  }
}
