import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_app_saludable/core/attendance/attendance_error_messages.dart';
import 'package:flutter_app_saludable/core/attendance/attendance_location_params.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/core/errors/error_mapper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';

void main() {
  group('AttendanceLocationParams', () {
    test('usa latitude, longitude y accuracy del Position', () {
      final position = Position(
        latitude: -17.78,
        longitude: -63.18,
        timestamp: DateTime(2026, 8, 31),
        accuracy: 8.3,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );

      final params = AttendanceLocationParams.fromPosition(position);

      expect(params.latitud, -17.78);
      expect(params.longitud, -63.18);
      expect(params.precisionMetros, 8.3);
    });

    test('omite precisionMetros si accuracy no es finita', () {
      final position = Position(
        latitude: -17.78,
        longitude: -63.18,
        timestamp: DateTime(2026, 8, 31),
        accuracy: double.nan,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );

      final params = AttendanceLocationParams.fromPosition(position);
      expect(params.precisionMetros, isNull);
    });
  });

  group('AttendanceErrorMessages', () {
    test('mapea códigos estables del backend', () {
      expect(
        AttendanceErrorMessages.forCode(AttendanceErrorCodes.outOfRange),
        contains('demasiado lejos'),
      );
      expect(
        AttendanceErrorMessages.forCode(AttendanceErrorCodes.locationRequired),
        contains('ubicación'),
      );
      expect(
        AttendanceErrorMessages.forCode(AttendanceErrorCodes.locationInvalid),
        contains('validar tu ubicación'),
      );
      expect(
        AttendanceErrorMessages.forCode(
          AttendanceErrorCodes.clubLocationUnavailable,
        ),
        contains('ubicación configurada'),
      );
    });
  });

  group('member_qr_scan_screen sin bypass local', () {
    test('no contiene diálogo Continuar ni regla 40m', () {
      final source = File(
        'lib/presentation/screens/member/qrcode/member_qr_scan_screen.dart',
      ).readAsStringSync();

      expect(source.contains('Continuar'), isFalse);
      expect(source.contains('40.0'), isFalse);
      expect(source.contains('maxDistance'), isFalse);
      expect(source.contains('club_remote_data_source'), isFalse);
      expect(source.contains('AttendanceLocationParams.fromPosition'), isTrue);
      expect(source.contains('precisionMetros'), isTrue);
    });
  });

  group('ErrorMapper attendance codes', () {
    test('400 ATTENDANCE_OUT_OF_RANGE usa mensaje seguro', () {
      final mapped = ErrorMapper.fromDio(
        DioException(
          requestOptions: RequestOptions(path: '/asistencias/registrar'),
          response: Response(
            requestOptions: RequestOptions(path: '/asistencias/registrar'),
            statusCode: 400,
            data: {
              'error': 'ATTENDANCE_OUT_OF_RANGE',
              'message': 'raw',
            },
          ),
          type: DioExceptionType.badResponse,
        ),
      );
      expect(mapped, isA<ValidationException>());
      expect(mapped.message, AttendanceErrorMessages.forCode(
        AttendanceErrorCodes.outOfRange,
      ));
    });
  });
}
