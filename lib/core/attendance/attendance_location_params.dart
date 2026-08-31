import 'package:geolocator/geolocator.dart';

/// Coordenadas GPS para registrar asistencia (backend autoritativo).
class AttendanceLocationParams {
  const AttendanceLocationParams({
    required this.latitud,
    required this.longitud,
    this.precisionMetros,
  });

  final double latitud;
  final double longitud;
  final double? precisionMetros;

  static AttendanceLocationParams fromPosition(Position position) {
    return AttendanceLocationParams(
      latitud: position.latitude,
      longitud: position.longitude,
      precisionMetros: _finiteOrNull(position.accuracy),
    );
  }

  static double? _finiteOrNull(double value) {
    if (value.isNaN || value.isInfinite) return null;
    return value;
  }
}
