import 'package:dio/dio.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/core/errors/throw_app_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RequestOptions req() => RequestOptions(path: '/x');

  group('throwAppError', () {
    test('mapea cualquier error a AppException y conserva el stack trace', () {
      try {
        throwAppError(Exception('boom'), fallback: 'Fallback genérico');
        fail('debía lanzar');
      } catch (e, st) {
        expect(e, isA<UnknownException>());
        expect((e as UnknownException).message, 'Fallback genérico');
        expect(st, isNotNull);
      }
    });

    test('con un DioException delega a ErrorMapper.fromDio', () {
      final dioError = DioException(
        requestOptions: req(),
        response: Response(
          requestOptions: req(),
          statusCode: 404,
          data: {'message': 'No encontrado'},
        ),
        type: DioExceptionType.badResponse,
      );

      try {
        throwAppError(dioError);
        fail('debía lanzar');
      } catch (e) {
        expect(e, isA<NotFoundException>());
      }
    });
  });

  group('throwDioAsApp', () {
    test('convierte DioException de conexión en NetworkException', () {
      final dioError = DioException(
        requestOptions: req(),
        type: DioExceptionType.connectionError,
      );

      try {
        throwDioAsApp(dioError, fallback: 'Sin conexión');
        fail('debía lanzar');
      } catch (e) {
        expect(e, isA<NetworkException>());
      }
    });

    test('convierte 500 en ServerException con statusCode', () {
      final dioError = DioException(
        requestOptions: req(),
        response: Response(
          requestOptions: req(),
          statusCode: 500,
          data: {'message': 'Falla interna'},
        ),
        type: DioExceptionType.badResponse,
      );

      try {
        throwDioAsApp(dioError);
        fail('debía lanzar');
      } catch (e) {
        expect(e, isA<ServerException>());
        expect((e as ServerException).statusCode, 500);
      }
    });
  });

  group('rethrowApp', () {
    test('si ya es AppException, lo relanza sin re-envolver', () {
      final original = ForbiddenException('Acceso denegado');
      try {
        rethrowApp(original, fallback: 'No debería usarse');
        fail('debía lanzar');
      } catch (e) {
        expect(identical(e, original), isTrue);
        expect((e as ForbiddenException).message, 'Acceso denegado');
      }
    });

    test('si no es AppException, lo mapea con el fallback dado', () {
      try {
        rethrowApp(Exception('otro error'), fallback: 'Mensaje seguro');
        fail('debía lanzar');
      } catch (e) {
        expect(e, isA<UnknownException>());
        expect((e as UnknownException).message, 'Mensaje seguro');
      }
    });

    test('con un DioException delega a ErrorMapper.fromDio', () {
      final dioError = DioException(
        requestOptions: req(),
        response: Response(
          requestOptions: req(),
          statusCode: 403,
          data: {'message': 'Prohibido'},
        ),
        type: DioExceptionType.badResponse,
      );

      try {
        rethrowApp(dioError);
        fail('debía lanzar');
      } catch (e) {
        expect(e, isA<ForbiddenException>());
      }
    });
  });
}
