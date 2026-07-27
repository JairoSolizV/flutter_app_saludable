import 'package:dio/dio.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/core/errors/error_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RequestOptions req() => RequestOptions(path: '/x');

  DioException httpError({
    required int status,
    dynamic data,
  }) {
    final opts = req();
    return DioException(
      requestOptions: opts,
      response: Response(requestOptions: opts, statusCode: status, data: data),
      type: DioExceptionType.badResponse,
    );
  }

  group('ErrorMapper.fromDio - tipos de conexión', () {
    test('connectionError → NetworkException', () {
      final mapped = ErrorMapper.fromDio(
        DioException(requestOptions: req(), type: DioExceptionType.connectionError),
      );
      expect(mapped, isA<NetworkException>());
      expect(mapped.message, contains('conexión'));
    });

    test('cancel → NetworkException con mensaje de cancelación', () {
      final mapped = ErrorMapper.fromDio(
        DioException(requestOptions: req(), type: DioExceptionType.cancel),
      );
      expect(mapped, isA<NetworkException>());
      expect(mapped.message, contains('cancelada'));
    });

    test('badCertificate → NetworkException de conexión segura', () {
      final mapped = ErrorMapper.fromDio(
        DioException(requestOptions: req(), type: DioExceptionType.badCertificate),
      );
      expect(mapped, isA<NetworkException>());
      expect(mapped.message, contains('segura'));
    });

    test('connectionTimeout → TimeoutException', () {
      final mapped = ErrorMapper.fromDio(
        DioException(requestOptions: req(), type: DioExceptionType.connectionTimeout),
      );
      expect(mapped, isA<TimeoutException>());
    });

    test('sendTimeout → TimeoutException', () {
      final mapped = ErrorMapper.fromDio(
        DioException(requestOptions: req(), type: DioExceptionType.sendTimeout),
      );
      expect(mapped, isA<TimeoutException>());
    });
  });

  group('ErrorMapper.fromDio - códigos HTTP adicionales', () {
    test('429 → RateLimitException', () {
      final mapped = ErrorMapper.fromDio(
        httpError(status: 429, data: {'message': 'Demasiadas solicitudes'}),
      );
      expect(mapped, isA<RateLimitException>());
      expect(mapped.statusCode, 429);
    });

    test('422 → ValidationException', () {
      final mapped = ErrorMapper.fromDio(
        httpError(status: 422, data: {'message': 'Entidad no procesable'}),
      );
      expect(mapped, isA<ValidationException>());
    });

    test('body como String simple se usa como mensaje directo', () {
      final mapped = ErrorMapper.fromDio(
        httpError(status: 400, data: 'Solo texto de error de negocio'),
      );
      expect(mapped.message, 'Solo texto de error de negocio');
    });

    test('fieldErrors se extraen de data.data y se sanitizan', () {
      final mapped = ErrorMapper.fromDio(
        httpError(status: 400, data: {
          'message': 'Datos inválidos',
          'data': {'email': 'formato inválido', 'edad': 15, 'activo': true},
        }),
      ) as ValidationException;

      expect(mapped.fieldErrors, isNotNull);
      expect(mapped.fieldErrors!['email'], 'formato inválido');
      expect(mapped.fieldErrors!['edad'], '15');
      expect(mapped.fieldErrors!['activo'], 'true');
    });

    test('sin fieldErrors cuando data.data no es Map', () {
      final mapped = ErrorMapper.fromDio(
        httpError(status: 400, data: {'message': 'Error', 'data': 'no-es-mapa'}),
      ) as ValidationException;
      expect(mapped.fieldErrors, isNull);
    });
  });

  group('ErrorMapper.sanitizePublicMessage - datos sensibles', () {
    test('oculta mensajes con Bearer token', () {
      final result = ErrorMapper.sanitizePublicMessage(
        'Fallo de autenticación: Bearer abc.def.ghi',
        fallback: 'Error genérico',
      );
      expect(result, 'Error genérico');
    });

    test('oculta mensajes con jwt', () {
      final result = ErrorMapper.sanitizePublicMessage(
        'El jwt expiró inesperadamente',
        fallback: 'Error genérico',
      );
      expect(result, 'Error genérico');
    });

    test('oculta mensajes con password', () {
      final result = ErrorMapper.sanitizePublicMessage(
        'password incorrecto en base de datos',
        fallback: 'Error genérico',
      );
      expect(result, 'Error genérico');
    });

    test('oculta mensajes con stack trace o rutas dart:', () {
      final result = ErrorMapper.sanitizePublicMessage(
        'Exception thrown at dart:core/errors.dart #0 main',
        fallback: 'Error genérico',
      );
      expect(result, 'Error genérico');
    });

    test('mensaje limpio se conserva tal cual (trim + espacios colapsados)', () {
      final result = ErrorMapper.sanitizePublicMessage('  Mensaje   válido  ');
      expect(result, 'Mensaje válido');
    });

    test('mensaje vacío retorna fallback', () {
      final result = ErrorMapper.sanitizePublicMessage('   ', fallback: 'Def');
      expect(result, 'Def');
    });
  });

  group('ErrorMapper.fromObject / publicMessage', () {
    test('fromObject con DioException delega a fromDio', () {
      final dioError = httpError(status: 404, data: null);
      final mapped = ErrorMapper.fromObject(dioError);
      expect(mapped, isA<NotFoundException>());
    });

    test('fromObject con Exception genérica retorna UnknownException', () {
      final mapped = ErrorMapper.fromObject(Exception('algo raro'));
      expect(mapped, isA<UnknownException>());
    });

    test('fromObject respeta fallback personalizado', () {
      final mapped = ErrorMapper.fromObject(
        Exception('algo raro'),
        fallback: 'Mensaje de repuesto',
      );
      expect(mapped.message, 'Mensaje de repuesto');
    });

    test('publicMessage retorna el mensaje de un AppException existente', () {
      final original = ForbiddenException('Acceso denegado');
      expect(ErrorMapper.publicMessage(original), 'Acceso denegado');
    });

    test('publicMessage con DioException devuelve mensaje mapeado', () {
      final dioError = httpError(status: 500, data: {'message': 'Falla interna'});
      expect(ErrorMapper.publicMessage(dioError), 'Falla interna');
    });

    test('publicMessage con error desconocido usa fallback por defecto', () {
      final message = ErrorMapper.publicMessage(Exception('boom'));
      expect(message, isNotEmpty);
    });
  });
}
