/// Códigos estables de POST /asistencias/registrar (MOB-ATT-002-BE).
class AttendanceErrorCodes {
  AttendanceErrorCodes._();

  static const outOfRange = 'ATTENDANCE_OUT_OF_RANGE';
  static const locationRequired = 'ATTENDANCE_LOCATION_REQUIRED';
  static const locationInvalid = 'ATTENDANCE_LOCATION_INVALID';
  static const clubLocationUnavailable = 'ATTENDANCE_CLUB_LOCATION_UNAVAILABLE';

  static const Set<String> all = {
    outOfRange,
    locationRequired,
    locationInvalid,
    clubLocationUnavailable,
  };

  static bool isAttendanceCode(String? code) {
    if (code == null || code.trim().isEmpty) return false;
    return all.contains(code.trim().toUpperCase());
  }
}

/// Mensajes UX seguros para errores de asistencia por ubicación.
class AttendanceErrorMessages {
  AttendanceErrorMessages._();

  static String forCode(String code) {
    switch (code.trim().toUpperCase()) {
      case AttendanceErrorCodes.outOfRange:
        return 'Estás demasiado lejos del club para registrar tu asistencia.';
      case AttendanceErrorCodes.locationRequired:
        return 'No pudimos obtener tu ubicación. Activa la ubicación e inténtalo nuevamente.';
      case AttendanceErrorCodes.locationInvalid:
        return 'No pudimos validar tu ubicación. Inténtalo nuevamente.';
      case AttendanceErrorCodes.clubLocationUnavailable:
        return 'Este club aún no tiene una ubicación configurada. Contacta al anfitrión.';
      default:
        return 'No pudimos registrar tu asistencia. Inténtalo nuevamente.';
    }
  }
}
