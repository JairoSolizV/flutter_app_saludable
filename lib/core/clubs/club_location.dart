/// Validación y mensajes UX para ubicación de club (CLUB-LOCATION-001).
class ClubLocationValidation {
  ClubLocationValidation._();

  static bool isValidLatitude(double? lat) {
    if (lat == null) return false;
    if (!lat.isFinite) return false;
    return lat >= -90 && lat <= 90;
  }

  static bool isValidLongitude(double? lng) {
    if (lng == null) return false;
    if (!lng.isFinite) return false;
    return lng >= -180 && lng <= 180;
  }

  static bool isValidCoordinates(double? lat, double? lng) {
    return isValidLatitude(lat) && isValidLongitude(lng);
  }
}

/// Mensajes locales de formulario (no dependen del backend).
class ClubLocationFormMessages {
  ClubLocationFormMessages._();

  static const selectLocation = 'Selecciona la ubicación de tu club.';
  static const editNeedsLocation =
      'Este club necesita una ubicación antes de guardar los cambios.';
  static const locationSelected = 'Ubicación seleccionada';
}

/// Códigos estables del backend para ubicación de club.
class ClubLocationErrorCodes {
  ClubLocationErrorCodes._();

  static const required = 'CLUB_LOCATION_REQUIRED';
  static const invalid = 'CLUB_LOCATION_INVALID';
  static const unavailable = 'CLUB_LOCATION_UNAVAILABLE';

  static const Set<String> all = {required, invalid, unavailable};

  static bool isClubLocationCode(String? code) {
    if (code == null || code.trim().isEmpty) return false;
    return all.contains(code.trim().toUpperCase());
  }
}

/// Mensajes UX seguros para errores de ubicación de club.
class ClubLocationErrorMessages {
  ClubLocationErrorMessages._();

  static String forCode(String code) {
    switch (code.trim().toUpperCase()) {
      case ClubLocationErrorCodes.required:
        return ClubLocationFormMessages.selectLocation;
      case ClubLocationErrorCodes.invalid:
        return 'La ubicación seleccionada no es válida. Inténtalo nuevamente.';
      case ClubLocationErrorCodes.unavailable:
        return 'Este club necesita una ubicación válida antes de continuar.';
      default:
        return 'No pudimos procesar la ubicación del club. Inténtalo nuevamente.';
    }
  }
}
