import 'package:flutter/services.dart';

/// Validación y sugerencias para iniciales de club (CLUB-PREFIX-001).
class ClubPrefixValidation {
  ClubPrefixValidation._();

  static final _pattern = RegExp(r'^[A-Z]{2}$');

  static bool isValid(String? value) {
    if (value == null || value.trim().isEmpty) return false;
    return _pattern.hasMatch(value.trim().toUpperCase());
  }

  static String normalize(String value) => value.trim().toUpperCase();

  static String? validateForm(String? value) {
    if (value == null || value.trim().isEmpty) {
      return ClubPrefixFormMessages.required;
    }
    if (!isValid(value)) {
      return ClubPrefixFormMessages.invalid;
    }
    return null;
  }
}

/// Sugerencia automática de iniciales desde el nombre (solo UX).
class ClubPrefixSuggestion {
  ClubPrefixSuggestion._();

  static String? fromClubName(String name) {
    final words =
        name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    String lettersOnly(String word) =>
        word.replaceAll(RegExp(r'[^A-Za-z]'), '');

    if (words.length >= 2) {
      final first = lettersOnly(words[0]);
      final second = lettersOnly(words[1]);
      if (first.isNotEmpty && second.isNotEmpty) {
        return '${first[0]}${second[0]}'.toUpperCase();
      }
    }

    if (words.length == 1) {
      final letters = lettersOnly(words[0]);
      if (letters.length >= 2) {
        return letters.substring(0, 2).toUpperCase();
      }
    }

    return null;
  }
}

/// Formatea entrada: máximo 2 letras A-Z en mayúsculas.
class ClubPrefixInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final filtered =
        newValue.text.replaceAll(RegExp(r'[^A-Za-z]'), '').toUpperCase();
    final clipped =
        filtered.length > 2 ? filtered.substring(0, 2) : filtered;
    return TextEditingValue(
      text: clipped,
      selection: TextSelection.collapsed(offset: clipped.length),
    );
  }
}

/// Mensajes locales de formulario.
class ClubPrefixFormMessages {
  ClubPrefixFormMessages._();

  static const required = 'Ingresa las iniciales del club.';
  static const invalid =
      'Las iniciales del club deben tener exactamente 2 letras.';
  static const editNeedsPrefix =
      'Este club necesita iniciales válidas antes de guardar los cambios.';
  static const helper =
      '2 letras que identificarán a los socios. Ejemplo: Club Vital → CV';
}

/// Códigos estables del backend para prefijo de club.
class ClubPrefixErrorCodes {
  ClubPrefixErrorCodes._();

  static const required = 'CLUB_PREFIX_REQUIRED';
  static const invalid = 'CLUB_PREFIX_INVALID';
  static const conflict = 'CLUB_PREFIX_CONFLICT';
  static const unavailable = 'CLUB_PREFIX_UNAVAILABLE';

  static const Set<String> all = {required, invalid, conflict, unavailable};

  static bool isClubPrefixCode(String? code) {
    if (code == null || code.trim().isEmpty) return false;
    return all.contains(code.trim().toUpperCase());
  }
}

/// Mensajes UX seguros para errores de prefijo de club.
class ClubPrefixErrorMessages {
  ClubPrefixErrorMessages._();

  static String forCode(String code) {
    switch (code.trim().toUpperCase()) {
      case ClubPrefixErrorCodes.required:
        return ClubPrefixFormMessages.required;
      case ClubPrefixErrorCodes.invalid:
        return ClubPrefixFormMessages.invalid;
      case ClubPrefixErrorCodes.conflict:
        return 'Estas iniciales ya están siendo utilizadas por otro club. Elige otras.';
      case ClubPrefixErrorCodes.unavailable:
        return 'Este club necesita iniciales válidas antes de continuar.';
      default:
        return 'No pudimos procesar las iniciales del club. Inténtalo nuevamente.';
    }
  }
}
