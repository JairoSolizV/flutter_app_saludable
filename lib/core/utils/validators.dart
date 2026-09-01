import 'name_pattern.dart';

class Validators {
  /// Regla de auth: trim de espacios exteriores + lowercase.
  static String normalizeEmail(String email) => email.trim().toLowerCase();

  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Este campo es obligatorio';
    }
    if (value.trim().length < 2) {
      return 'Debe tener al menos 2 caracteres';
    }
    // Coherente con AppFormatters.letras(): letras, acentos, ñ, ü, espacio, ', -
    if (!NamePattern.fullValue.hasMatch(value)) {
      return 'Solo se permiten letras, espacios, apóstrofe y guion';
    }
    return null;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El correo es obligatorio';
    }
    final email = normalizeEmail(value);
    // Formato razonable: local@dominio.tld — acepta +, puntos y TLD largos.
    // No intenta comprobar si la casilla existe.
    final emailExp = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');
    if (!emailExp.hasMatch(email)) {
      return 'Ingresa un correo válido';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña es obligatoria';
    }
    if (value.length < 8) {
      return 'La contraseña debe tener al menos 8 caracteres';
    }
    return null;
  }

  /// Compara [confirmation] con [password] de forma exacta (sin trim ni normalizar).
  static String? validatePasswordConfirmation(
    String? confirmation,
    String password,
  ) {
    if (confirmation == null || confirmation.isEmpty) {
      return 'Confirma tu contraseña.';
    }
    if (confirmation != password) {
      return 'Las contraseñas no coinciden.';
    }
    return null;
  }

  static String? validateBolivianPhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El teléfono es obligatorio';
    }
    final local = stripBoliviaCountryCode(value);
    // Valida números de Bolivia: 8 dígitos, empieza con 6 o 7
    final phoneExp = RegExp(r'^[67]\d{7}$');
    if (!phoneExp.hasMatch(local)) {
      return 'Número inválido (8 dígitos, empieza con 6 o 7)';
    }
    return null;
  }

  /// Quita el prefijo +591/591 para mostrar u validar los 8 dígitos locales.
  static String stripBoliviaCountryCode(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('+591')) {
      return trimmed.substring(4);
    }
    if (trimmed.startsWith('591') && trimmed.length > 8) {
      return trimmed.substring(3);
    }
    return trimmed;
  }

  /// Formato E.164 que el backend ya espera (+591 + 8 dígitos locales).
  ///
  /// Vacío devuelve vacío: los diálogos de perfil de socio y anfitrión no
  /// validan el campo, y mandar '+591' pelado guardaría basura en el backend.
  static String toBoliviaE164(String value) {
    final local = stripBoliviaCountryCode(value);
    if (local.isEmpty) return '';
    return '+591$local';
  }
  
  // Para campos genéricos que no deben tener números (ej. Ciudad)
  static String? validateTextNoNumbers(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Este campo es obligatorio';
    }
    final exp = RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$');
    if (!exp.hasMatch(value)) {
      return 'No se permiten números';
    }
    return null;
  }
}
