/// Regla compartida para nombres de persona en formatter y validator.
class NamePattern {
  NamePattern._();

  /// Caracteres permitidos al escribir (formatter).
  static final RegExp inputCharacters =
      RegExp(r"[A-Za-zÁÉÍÓÚÜÑáéíóúüñ '\-]");

  /// Valor completo válido (validator).
  static final RegExp fullValue = RegExp(
    r"^[a-zA-ZáéíóúÁÉÍÓÚüÜñÑ '\-]+$",
  );
}
