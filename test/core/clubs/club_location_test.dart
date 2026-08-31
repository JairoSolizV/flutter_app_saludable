import 'package:dio/dio.dart';
import 'package:flutter_app_saludable/core/clubs/club_location.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/core/errors/error_mapper.dart';
import 'package:flutter_app_saludable/data/datasources/remote/club_remote_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

Club _clubFromJson(Map<String, dynamic> json) => Club.fromJson({
      'id': 1,
      'hubId': 1,
      'anfitrionId': 2,
      ...json,
    });

void main() {
  group('ClubLocationValidation', () {
    test('sin ubicación no es válida', () {
      expect(ClubLocationValidation.isValidCoordinates(null, null), isFalse);
    });

    test('lat inválida fuera de rango', () {
      expect(ClubLocationValidation.isValidLatitude(91), isFalse);
      expect(
        ClubLocationValidation.isValidCoordinates(91, -63.0),
        isFalse,
      );
    });

    test('lng inválida fuera de rango', () {
      expect(ClubLocationValidation.isValidLongitude(181), isFalse);
      expect(
        ClubLocationValidation.isValidCoordinates(-17.0, 181),
        isFalse,
      );
    });

    test('0,0 es coordenada válida y distinta de ausencia', () {
      expect(ClubLocationValidation.isValidCoordinates(0, 0), isTrue);
      expect(ClubLocationValidation.isValidCoordinates(null, 0), isFalse);
      expect(ClubLocationValidation.isValidCoordinates(0, null), isFalse);
    });

    test('coordenadas finitas en rango son válidas', () {
      expect(
        ClubLocationValidation.isValidCoordinates(-17.78, -63.18),
        isTrue,
      );
    });
  });

  group('Club.fromJson ubicación', () {
    test('lat null se conserva null, no 0.0', () {
      final club = _clubFromJson({'lat': null, 'lng': -63.1});
      expect(club.lat, isNull);
      expect(club.hasValidLocation, isFalse);
    });

    test('lng null se conserva null', () {
      final club = _clubFromJson({'lat': -17.7, 'lng': null});
      expect(club.lng, isNull);
      expect(club.hasValidLocation, isFalse);
    });

    test('hasValidLocation true para coordenadas válidas', () {
      final club = _clubFromJson({'lat': -17.7, 'lng': -63.1});
      expect(club.hasValidLocation, isTrue);
    });

    test('hasValidLocation false para null o fuera de rango', () {
      expect(_clubFromJson({'lat': null, 'lng': null}).hasValidLocation, isFalse);
      expect(_clubFromJson({'lat': 100, 'lng': -63}).hasValidLocation, isFalse);
    });
  });

  group('CREATE — reglas de submit', () {
    test('sin ubicación no puede enviarse', () {
      expect(ClubLocationValidation.isValidCoordinates(null, null), isFalse);
    });

    test('cancelar picker deja ausencia de ubicación', () {
      double? lat;
      double? lng;
      expect(ClubLocationValidation.isValidCoordinates(lat, lng), isFalse);
    });

    test('ubicación válida permite request con lat/lng', () {
      const lat = -17.5;
      const lng = -63.2;
      expect(ClubLocationValidation.isValidCoordinates(lat, lng), isTrue);
    });
  });

  group('UPDATE — conservar coordenadas', () {
    test('editar otro campo conserva lat/lng existentes', () {
      final club = _clubFromJson({
        'nombreClub': 'Club Norte',
        'lat': -17.5,
        'lng': -63.2,
      });
      final data = {
        'nombreClub': 'Club Norte',
        'direccion': 'Nueva dir',
        'horario': '8-18',
        'lat': club.lat,
        'lng': club.lng,
      };
      expect(data['lat'], -17.5);
      expect(data['lng'], -63.2);
      expect(data['lat'], isNotNull);
      expect(data['lng'], isNotNull);
    });

    test('club histórico sin coords no puede guardarse sin ubicación', () {
      final club = _clubFromJson({'lat': null, 'lng': null});
      expect(club.hasValidLocation, isFalse);
    });

    test('update no envía null accidentalmente cuando hay coords válidas', () {
      final club = _clubFromJson({'lat': 0, 'lng': 0});
      expect(club.hasValidLocation, isTrue);
      final data = <String, dynamic>{
        'lat': club.lat,
        'lng': club.lng,
      };
      expect(data['lat'], isNotNull);
      expect(data['lng'], isNotNull);
    });
  });

  group('ClubLocationErrorMessages', () {
    test('CLUB_LOCATION_REQUIRED', () {
      expect(
        ClubLocationErrorMessages.forCode(ClubLocationErrorCodes.required),
        ClubLocationFormMessages.selectLocation,
      );
    });

    test('CLUB_LOCATION_INVALID', () {
      expect(
        ClubLocationErrorMessages.forCode(ClubLocationErrorCodes.invalid),
        contains('no es válida'),
      );
    });

    test('CLUB_LOCATION_UNAVAILABLE', () {
      expect(
        ClubLocationErrorMessages.forCode(ClubLocationErrorCodes.unavailable),
        contains('ubicación válida'),
      );
    });
  });

  group('ErrorMapper club location codes', () {
    DioException httpError({required int status, required String code}) {
      final opts = RequestOptions(path: '/clubes');
      return DioException(
        requestOptions: opts,
        response: Response(
          requestOptions: opts,
          statusCode: status,
          data: {'error': code, 'message': 'raw'},
        ),
        type: DioExceptionType.badResponse,
      );
    }

    test('400 CLUB_LOCATION_REQUIRED → mensaje UX', () {
      final mapped = ErrorMapper.fromDio(
        httpError(status: 400, code: ClubLocationErrorCodes.required),
      );
      expect(mapped, isA<ValidationException>());
      expect(mapped.message, ClubLocationFormMessages.selectLocation);
    });

    test('400 CLUB_LOCATION_INVALID → mensaje UX', () {
      final mapped = ErrorMapper.fromDio(
        httpError(status: 400, code: ClubLocationErrorCodes.invalid),
      );
      expect(mapped.message, contains('no es válida'));
    });

    test('409 CLUB_LOCATION_UNAVAILABLE → mensaje UX', () {
      final mapped = ErrorMapper.fromDio(
        httpError(status: 409, code: ClubLocationErrorCodes.unavailable),
      );
      expect(mapped, isA<ValidationException>());
      expect(mapped.message, contains('ubicación válida'));
    });
  });

  group('REGRESIÓN parseo getClubes', () {
    test('club con coords válidas sigue parseando', () {
      final club = _clubFromJson({
        'nombreClub': 'Club X',
        'lat': -17.7,
        'lng': -63.1,
        'estado': 'ACTIVO',
      });
      expect(club.nombreClub, 'Club X');
      expect(club.lat, -17.7);
      expect(club.lng, -63.1);
    });
  });
}
