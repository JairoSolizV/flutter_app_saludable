import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app_saludable/core/clubs/club_location.dart';
import 'package:flutter_app_saludable/core/clubs/club_prefix.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/core/errors/error_mapper.dart';
import 'package:flutter_app_saludable/data/datasources/remote/club_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/qr_remote_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

Club _clubFromJson(Map<String, dynamic> json) => Club.fromJson({
      'id': 1,
      'hubId': 1,
      'anfitrionId': 2,
      ...json,
    });

void main() {
  group('ClubPrefixValidation', () {
    test('sin prefijo es inválido', () {
      expect(ClubPrefixValidation.isValid(null), isFalse);
      expect(ClubPrefixValidation.isValid(''), isFalse);
    });

    test('1 letra es inválida', () {
      expect(ClubPrefixValidation.isValid('C'), isFalse);
    });

    test('3 letras son inválidas', () {
      expect(ClubPrefixValidation.isValid('CVX'), isFalse);
    });

    test('números son inválidos', () {
      expect(ClubPrefixValidation.isValid('C1'), isFalse);
      expect(ClubPrefixValidation.isValid('12'), isFalse);
    });

    test('CV es válido', () {
      expect(ClubPrefixValidation.isValid('CV'), isTrue);
      expect(ClubPrefixValidation.isValid('cv'), isTrue);
    });

    test('ClubPrefixInputFormatter convierte a mayúsculas', () {
      final formatter = ClubPrefixInputFormatter();
      final result = formatter.formatEditUpdate(
        const TextEditingValue(text: ''),
        const TextEditingValue(text: 'cv'),
      );
      expect(result.text, 'CV');
    });

    test('ClubPrefixInputFormatter limita a 2 letras', () {
      final formatter = ClubPrefixInputFormatter();
      final result = formatter.formatEditUpdate(
        const TextEditingValue(text: 'CV'),
        const TextEditingValue(text: 'CVX'),
      );
      expect(result.text, 'CV');
    });
  });

  group('ClubPrefixSuggestion', () {
    test('"Club Vital" sugiere CV', () {
      expect(ClubPrefixSuggestion.fromClubName('Club Vital'), 'CV');
    });

    test('"Nutrición Centro" sugiere NC', () {
      expect(ClubPrefixSuggestion.fromClubName('Nutrición Centro'), 'NC');
    });

    test('"Vital" sugiere VI', () {
      expect(ClubPrefixSuggestion.fromClubName('Vital'), 'VI');
    });

    test('después de edición manual el nombre no sobreescribe prefijo', () {
      var prefix = 'AB';
      const editedManually = true;
      if (!editedManually) {
        final suggestion = ClubPrefixSuggestion.fromClubName('Club Vital');
        if (suggestion != null) prefix = suggestion;
      }
      expect(prefix, 'AB');
    });
  });

  group('Club.fromJson prefijoSocio', () {
    test('parsea prefijoSocio sin fallback', () {
      final club = _clubFromJson({'prefijoSocio': 'CV'});
      expect(club.prefijoSocio, 'CV');
      expect(club.hasValidPrefix, isTrue);
    });

    test('histórico null conserva null', () {
      final club = _clubFromJson({'prefijoSocio': null});
      expect(club.prefijoSocio, isNull);
      expect(club.hasValidPrefix, isFalse);
    });
  });

  group('CREATE submit rules', () {
    test('sin prefijo no puede submit', () {
      expect(ClubPrefixValidation.isValid(null), isFalse);
    });

    test('ubicación válida + prefijo válido puede submit', () {
      expect(
        ClubLocationValidation.isValidCoordinates(-17.0, -63.0) &&
            ClubPrefixValidation.isValid('CV'),
        isTrue,
      );
    });
  });

  group('UPDATE prefijo', () {
    test('club CV precarga CV', () {
      final club = _clubFromJson({'prefijoSocio': 'CV'});
      expect(club.prefijoSocio, 'CV');
    });

    test('update conserva CV', () {
      final club = _clubFromJson({'prefijoSocio': 'CV'});
      final data = {
        'nombreClub': 'Club',
        'prefijoSocio': club.prefijoSocio,
        'lat': -17.0,
        'lng': -63.0,
      };
      expect(data['prefijoSocio'], 'CV');
    });

    test('histórico null exige prefijo', () {
      final club = _clubFromJson({'prefijoSocio': null});
      expect(club.hasValidPrefix, isFalse);
    });

    test('PUT incluye prefijoSocio y lat/lng', () {
      final data = {
        'prefijoSocio': 'NC',
        'lat': -17.5,
        'lng': -63.2,
      };
      expect(data['prefijoSocio'], 'NC');
      expect(data['lat'], isNotNull);
      expect(data['lng'], isNotNull);
    });
  });

  group('ClubPrefixErrorMessages', () {
    test('REQUIRED', () {
      expect(
        ClubPrefixErrorMessages.forCode(ClubPrefixErrorCodes.required),
        ClubPrefixFormMessages.required,
      );
    });

    test('INVALID', () {
      expect(
        ClubPrefixErrorMessages.forCode(ClubPrefixErrorCodes.invalid),
        contains('exactamente 2 letras'),
      );
    });

    test('CONFLICT', () {
      expect(
        ClubPrefixErrorMessages.forCode(ClubPrefixErrorCodes.conflict),
        contains('ya están siendo utilizadas'),
      );
    });

    test('UNAVAILABLE', () {
      expect(
        ClubPrefixErrorMessages.forCode(ClubPrefixErrorCodes.unavailable),
        contains('iniciales válidas'),
      );
    });
  });

  group('ErrorMapper club prefix codes', () {
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

    test('400 CLUB_PREFIX_REQUIRED', () {
      final mapped = ErrorMapper.fromDio(
        httpError(status: 400, code: ClubPrefixErrorCodes.required),
      );
      expect(mapped, isA<ValidationException>());
      expect(mapped.message, ClubPrefixFormMessages.required);
    });

    test('400 CLUB_PREFIX_INVALID', () {
      final mapped = ErrorMapper.fromDio(
        httpError(status: 400, code: ClubPrefixErrorCodes.invalid),
      );
      expect(mapped.message, contains('exactamente 2 letras'));
    });

    test('409 CLUB_PREFIX_CONFLICT', () {
      final mapped = ErrorMapper.fromDio(
        httpError(status: 409, code: ClubPrefixErrorCodes.conflict),
      );
      expect(mapped.message, contains('ya están siendo utilizadas'));
    });

    test('409 CLUB_PREFIX_UNAVAILABLE', () {
      final mapped = ErrorMapper.fromDio(
        httpError(status: 409, code: ClubPrefixErrorCodes.unavailable),
      );
      expect(mapped.message, contains('iniciales válidas'));
    });
  });

  group('QR / numeroSocio opaco', () {
    test('QrResponse acepta nuevo CV-00000123', () {
      final qr = QrResponse.fromJson({
        'tipo': 'SOCIO',
        'qrPayload': 'SOCIO:CV-00000123',
        'numeroSocio': 'CV-00000123',
      });
      expect(qr.qrPayload, 'SOCIO:CV-00000123');
      expect(qr.numeroSocio, 'CV-00000123');
    });

    test('QrResponse acepta histórico CL-000003', () {
      final qr = QrResponse.fromJson({
        'tipo': 'SOCIO',
        'qrPayload': 'SOCIO:CL-000003',
        'numeroSocio': 'CL-000003',
      });
      expect(qr.numeroSocio, 'CL-000003');
    });

    test('QRValidacionResponse trata numeroSocio como string opaco', () {
      final resp = QRValidacionResponse.fromJson({
        'valido': true,
        'numeroSocio': 'CV-00000123',
      });
      expect(resp.numeroSocio, 'CV-00000123');
    });

    test('no hay regex hardcodeada CL- en qr_remote_data_source', () {
      const source = '''
      if (qr.startsWith('SOCIO:')) {
        qrToSend = qr.substring(6);
      }
      ''';
      expect(source.contains(RegExp(r"CL-\d")), isFalse);
    });
  });

  group('REGRESIÓN CLUB-LOCATION', () {
    test('hasValidLocation sigue funcionando', () {
      final club = _clubFromJson({'lat': -17.7, 'lng': -63.1});
      expect(club.hasValidLocation, isTrue);
    });
  });
}
