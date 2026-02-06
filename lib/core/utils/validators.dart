class Validators {
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Este campo es obligatorio';
    }
    // Permite letras, espacios y acentos, pero NO números.
    final nameExp = RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$');
    if (!nameExp.hasMatch(value)) {
      return 'No se permiten números ni caracteres especiales';
    }
    return null;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El correo es obligatorio';
    }
    // Regex estándar básica para email
    final emailExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailExp.hasMatch(value)) {
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

  static String? validateBolivianPhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El teléfono es obligatorio';
    }
    // Valida números de Bolivia: 8 dígitos, empieza con 6 o 7
    final phoneExp = RegExp(r'^[67]\d{7}$');
    if (!phoneExp.hasMatch(value)) {
      return 'Número inválido (8 dígitos, empieza con 6 o 7)';
    }
    return null;
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
