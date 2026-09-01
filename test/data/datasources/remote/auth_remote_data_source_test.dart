import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/data/datasources/remote/auth_remote_data_source.dart';
import 'package:flutter_app_saludable/domain/entities/user.dart';
import 'package:flutter_test/flutter_test.dart';

class _Stub {
  _Stub(this.method, this.pathContains, this.statusCode, this.data);
  final String method;
  final String pathContains;
  final int statusCode;
  final dynamic data;
}

class _FakeAdapter implements HttpClientAdapter {
  final List<_Stub> _stubs = [];
  final List<RequestOptions> requests = [];

  void stub(
    String method,
    String pathContains, {
    int statusCode = 200,
    dynamic data,
  }) {
    _stubs.add(_Stub(method.toUpperCase(), pathContains, statusCode, data));
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    for (final s in _stubs) {
      if (s.method == options.method && options.uri.path.contains(s.pathContains)) {
        final body = s.data is String ? s.data : jsonEncode(s.data);
        return ResponseBody.fromString(
          body,
          s.statusCode,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
    }
    return ResponseBody.fromString(
      '{"message":"not stubbed: ${options.method} ${options.uri.path}"}',
      404,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _buildDio(_FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
  dio.httpClientAdapter = adapter;
  return dio;
}

dynamic async_(Future<void> Function() body) => body;

void main() {
  late _FakeAdapter adapter;
  late AuthRemoteDataSourceImpl ds;

  setUp(() {
    adapter = _FakeAdapter();
    ds = AuthRemoteDataSourceImpl(_buildDio(adapter));
  });

  group('checkEmailExists', () {
    test('200 con exists true', async_(() async {
      adapter.stub('GET', '/auth/check-email', data: {'exists': true});
      expect(await ds.checkEmailExists('a@a.com'), isTrue);
    }));

    test('200 con exists false', async_(() async {
      adapter.stub('GET', '/auth/check-email', data: {'exists': false});
      expect(await ds.checkEmailExists('a@a.com'), isFalse);
    }));

    test('normaliza email en query (trim + lowercase)', async_(() async {
      adapter.stub('GET', '/auth/check-email', data: {'exists': false});
      await ds.checkEmailExists('  SOCIO1@DEMO.COM  ');
      final emailParam =
          adapter.requests.last.uri.queryParameters['email'];
      expect(emailParam, 'socio1@demo.com');
    }));

    test('error se mapea a AppException', async_(() async {
      adapter.stub('GET', '/auth/check-email', statusCode: 500, data: {});
      await expectLater(
        () => ds.checkEmailExists('a@a.com'),
        throwsA(isA<AppException>()),
      );
    }));
  });

  group('login', () {
    test('normaliza email antes del POST', async_(() async {
      adapter.stub('POST', '/auth/login', data: {
        'token': 'tok',
        'id': 1,
        'nombre': 'Socio',
        'apellido': 'Uno',
        'email': 'socio1@demo.com',
        'rolNombre': 'SOCIO',
      });
      await ds.login('  SOCIO1@DEMO.COM  ', 'secret');
      final body = adapter.requests.last.data as Map;
      expect(body['email'], 'socio1@demo.com');
    }));

    test('ADMIN anidado en rol Map lanza ADMIN_MOBILE_NOT_SUPPORTED',
        async_(() async {
      adapter.stub('POST', '/auth/login', data: {
        'token': 'tok123',
        'usuario': {
          'id': 1,
          'nombre': 'Ana',
          'apellido': 'Perez',
          'email': 'ana@test.com',
          'rol': {'id': 1, 'nombre': 'ADMIN'},
          'telefono': '123',
        },
      });
      await expectLater(
        () => ds.login('ana@test.com', 'pass'),
        throwsA(
          isA<AdminMobileNotSupportedException>()
              .having((e) => e.code, 'code', 'ADMIN_MOBILE_NOT_SUPPORTED'),
        ),
      );
    }));

    test('ANFITRION → host', async_(() async {
      adapter.stub('POST', '/auth/login', data: {
        'token': 'tok',
        'id': 10,
        'nombre': 'Host',
        'apellido': 'User',
        'email': 'host@test.com',
        'rolNombre': 'ANFITRION',
      });
      final user = await ds.login('host@test.com', 'pass');
      expect(user.role, 'host');
    }));

    test('SOCIO → member', async_(() async {
      adapter.stub('POST', '/auth/login', data: {
        'token': 'tok',
        'id': 11,
        'nombre': 'Socio',
        'apellido': 'User',
        'email': 'socio@test.com',
        'rolNombre': 'SOCIO',
      });
      final user = await ds.login('socio@test.com', 'pass');
      expect(user.role, 'member');
    }));

    test('USUARIO_BASICO → basic_user', async_(() async {
      adapter.stub('POST', '/auth/login', data: {
        'token': 'tok',
        'id': 3,
        'nombre': 'Carla',
        'apellido': 'Ruiz',
        'email': 'carla@test.com',
        'rol': 'USUARIO_BASICO',
      });
      final user = await ds.login('carla@test.com', 'pass');
      expect(user.role, 'basic_user');
    }));

    test('rolId arbitrario + rolNombre SOCIO → member (ignora id)',
        async_(() async {
      adapter.stub('POST', '/auth/login', data: {
        'token': 'tok',
        'id': 99,
        'nombre': 'Id',
        'apellido': 'Libre',
        'email': 'idlibre@test.com',
        'rolId': 99,
        'rolNombre': 'SOCIO',
      });
      final user = await ds.login('idlibre@test.com', 'pass');
      expect(user.role, 'member');
    }));

    test('/me-style rol Map: id irrelevante, nombre ANFITRION → host',
        async_(() async {
      adapter.stub('POST', '/auth/login', data: {
        'token': 'tok',
        'id': 12,
        'nombre': 'Me',
        'apellido': 'Style',
        'email': 'me@test.com',
        'rol': {'id': 999, 'nombre': 'ANFITRION'},
      });
      final user = await ds.login('me@test.com', 'pass');
      expect(user.role, 'host');
    }));

    test('solo rolId sin nombre lanza UNKNOWN_ROLE', async_(() async {
      adapter.stub('POST', '/auth/login', data: {
        'token': 'tok',
        'id': 2,
        'nombre': 'Beto',
        'apellido': 'Diaz',
        'email': 'beto@test.com',
        'rolId': 4,
      });
      await expectLater(
        () => ds.login('beto@test.com', 'pass'),
        throwsA(
          isA<ServerException>()
              .having((e) => e.code, 'code', 'UNKNOWN_ROLE'),
        ),
      );
    }));

    test('sin datos de rol lanza UNKNOWN_ROLE (no cae a member)',
        async_(() async {
      adapter.stub('POST', '/auth/login', data: {
        'token': 'tok',
        'id': 4,
        'nombre': 'Dan',
        'apellido': 'Lopez',
        'email': 'dan@test.com',
      });
      await expectLater(
        () => ds.login('dan@test.com', 'pass'),
        throwsA(
          isA<ServerException>()
              .having((e) => e.code, 'code', 'UNKNOWN_ROLE'),
        ),
      );
    }));

    test('rol desconocido lanza UNKNOWN_ROLE', async_(() async {
      adapter.stub('POST', '/auth/login', data: {
        'token': 'tok',
        'id': 5,
        'nombre': 'X',
        'apellido': 'Y',
        'email': 'xy@test.com',
        'rolNombre': 'SUPER_ADMIN',
      });
      await expectLater(
        () => ds.login('xy@test.com', 'pass'),
        throwsA(
          isA<ServerException>()
              .having((e) => e.code, 'code', 'UNKNOWN_ROLE'),
        ),
      );
    }));

    test('redesSociales como String se parsea como instagram',
        async_(() async {
      adapter.stub('POST', '/auth/login', data: {
        'token': 'tok',
        'id': 5,
        'nombre': 'Eva',
        'apellido': 'Mora',
        'email': 'eva@test.com',
        'rolNombre': 'SOCIO',
        'redesSociales': '@eva',
      });
      final user = await ds.login('eva@test.com', 'pass');
      expect(user.socialMedia?['instagram'], '@eva');
    }));

    test('credenciales inválidas lanzan AppException', async_(() async {
      adapter.stub('POST', '/auth/login', statusCode: 401, data: {});
      await expectLater(
        () => ds.login('x@x.com', 'bad'),
        throwsA(isA<AppException>()),
      );
    }));

    test('403 EMAIL_NOT_VERIFIED lanza EmailNotVerifiedException',
        async_(() async {
      adapter.stub('POST', '/auth/login', statusCode: 403, data: {
        'success': false,
        'error': 'EMAIL_NOT_VERIFIED',
        'message': 'Debes verificar tu correo para continuar.',
      });
      await expectLater(
        () => ds.login('pendiente@test.com', 'secret'),
        throwsA(
          isA<EmailNotVerifiedException>()
              .having((e) => e.code, 'code', 'EMAIL_NOT_VERIFIED')
              .having(
                (e) => e.message,
                'message',
                contains('verificar'),
              ),
        ),
      );
    }));

    test('403 deshabilitado genérico lanza ForbiddenException sin código OTP',
        async_(() async {
      adapter.stub('POST', '/auth/login', statusCode: 403, data: {
        'success': false,
        'message': 'Usuario deshabilitado. Contacte al administrador.',
      });
      await expectLater(
        () => ds.login('off@test.com', 'secret'),
        throwsA(
          isA<ForbiddenException>()
              .having((e) => e is EmailNotVerifiedException, 'is OTP', isFalse)
              .having(
                (e) => e.message,
                'message',
                contains('deshabilitado'),
              ),
        ),
      );
    }));

    test('status distinto de 200/201 lanza ServerException', async_(() async {
      adapter.stub('POST', '/auth/login', statusCode: 202, data: {'id': 1});
      await expectLater(
        () => ds.login('x@x.com', 'bad'),
        throwsA(isA<AppException>()),
      );
    }));
  });

  group('mapBackendRoleToAppRole', () {
    test('ADMIN lanza ADMIN_MOBILE_NOT_SUPPORTED', () {
      expect(
        () => AuthRemoteDataSourceImpl.mapBackendRoleToAppRole('ADMIN'),
        throwsA(
          isA<AdminMobileNotSupportedException>()
              .having((e) => e.code, 'code', 'ADMIN_MOBILE_NOT_SUPPORTED'),
        ),
      );
    });

    test('ANFITRION → host', () {
      expect(
          AuthRemoteDataSourceImpl.mapBackendRoleToAppRole('ANFITRION'), 'host');
    });

    test('SOCIO → member', () {
      expect(
          AuthRemoteDataSourceImpl.mapBackendRoleToAppRole('SOCIO'), 'member');
    });

    test('USUARIO_BASICO → basic_user', () {
      expect(
        AuthRemoteDataSourceImpl.mapBackendRoleToAppRole('USUARIO_BASICO'),
        'basic_user',
      );
    });

    test('rol desconocido lanza UNKNOWN_ROLE', () {
      expect(
        () => AuthRemoteDataSourceImpl.mapBackendRoleToAppRole('SUPER_ADMIN'),
        throwsA(
          isA<ServerException>().having((e) => e.code, 'code', 'UNKNOWN_ROLE'),
        ),
      );
    });
  });

  group('register', () {
    test('éxito hace POST con rolId cuando se provee', async_(() async {
      adapter.stub('POST', '/auth/register', statusCode: 201, data: {
        'token': 'tok',
        'id': 6,
        'nombre': 'Fer',
        'apellido': 'Gomez',
        'email': 'fer@test.com',
        'rolNombre': 'USUARIO_BASICO',
      });
      final user = await ds.register(
        'Fer',
        'Gomez',
        'fer@test.com',
        'pass',
        '555',
        rolId: 2,
      );
      expect(user.id, '6');
      expect(user.role, 'basic_user');

      final sentBody = adapter.requests.last.data as Map;
      expect(sentBody['rolId'], 2);
    }));

    test('error de servidor se mapea', async_(() async {
      adapter.stub('POST', '/auth/register', statusCode: 500, data: {});
      await expectLater(
        () => ds.register('N', 'A', 'n@a.com', 'pass', '1'),
        throwsA(isA<AppException>()),
      );
    }));
  });

  group('updateUser', () {
    test('200 parsea la respuesta como usuario actualizado', async_(() async {
      adapter.stub('PUT', '/usuarios/perfil/7', data: {
        'token': 'tok',
        'id': 7,
        'nombre': 'Gina Torres',
        'apellido': '',
        'email': 'gina@test.com',
        'rolNombre': 'SOCIO',
      });
      final updated = await ds.updateUser(User(
        id: '7',
        name: 'Gina Torres',
        email: 'gina@test.com',
        role: 'member',
      ));
      expect(updated.id, '7');
      expect(updated.role, 'member');
    }));

    test('status distinto de 200 devuelve el usuario local sin parsear',
        async_(() async {
      adapter.stub('PUT', '/usuarios/perfil/8', statusCode: 204, data: '');
      final local = User(id: '8', name: 'Hugo', email: 'hugo@test.com', role: 'member');
      final result = await ds.updateUser(local);
      expect(result, same(local));
    }));

    test('instagram en socialMedia se extrae al enviar', async_(() async {
      adapter.stub('PUT', '/usuarios/perfil/9', statusCode: 204, data: '');
      await ds.updateUser(User(
        id: '9',
        name: 'Ivan Solo',
        email: 'ivan@test.com',
        role: 'member',
        socialMedia: {'instagram': '@ivan'},
      ));
      final sentBody = adapter.requests.last.data as Map;
      expect(sentBody['redesSociales'], '@ivan');
    }));

    test('error de servidor se mapea', async_(() async {
      adapter.stub('PUT', '/usuarios/perfil/10', statusCode: 500, data: {});
      await expectLater(
        () => ds.updateUser(
            User(id: '10', name: 'J', email: 'j@test.com', role: 'member')),
        throwsA(isA<AppException>()),
      );
    }));
  });

  group('getMe', () {
    test('200 parsea el usuario actual por nombre de rol anidado',
        async_(() async {
      adapter.stub('GET', '/auth/me', data: {
        'token': 'tok',
        'id': 11,
        'nombre': 'Ka',
        'apellido': 'Ren',
        'email': 'ka@test.com',
        'rol': {'id': 2, 'nombre': 'SOCIO'},
      });
      final user = await ds.getMe();
      expect(user.id, '11');
      expect(user.role, 'member');
    }));

    test('error se mapea', async_(() async {
      adapter.stub('GET', '/auth/me', statusCode: 401, data: {});
      await expectLater(() => ds.getMe(), throwsA(isA<AppException>()));
    }));
  });

  group('verifyEmail', () {
    test('200 con verified true parsea usuario por rolNombre', async_(() async {
      adapter.stub('POST', '/auth/verify-email', data: {
        'verified': true,
        'token': 'jwt-otp',
        'userId': 20,
        'nombre': 'Otp',
        'apellido': 'User',
        'email': 'a@a.com',
        'rolNombre': 'USUARIO_BASICO',
      });
      final user = await ds.verifyEmail('a@a.com', '123456');
      expect(user, isNotNull);
      expect(user!.role, 'basic_user');
      expect(user.token, 'jwt-otp');
    }));

    test('normaliza email en el body', async_(() async {
      adapter.stub('POST', '/auth/verify-email', data: {
        'verified': true,
        'token': 'jwt',
        'userId': 1,
        'nombre': 'A',
        'apellido': 'B',
        'email': 'socio1@demo.com',
        'rolNombre': 'SOCIO',
      });
      await ds.verifyEmail('  SOCIO1@DEMO.COM  ', '123456');
      final body = adapter.requests.last.data as Map;
      expect(body['email'], 'socio1@demo.com');
    }));

    test('200 con verified false', async_(() async {
      adapter.stub('POST', '/auth/verify-email', data: {'verified': false});
      expect(await ds.verifyEmail('a@a.com', '000000'), isNull);
    }));

    test('error se mapea', async_(() async {
      adapter.stub('POST', '/auth/verify-email', statusCode: 400, data: {});
      await expectLater(
        () => ds.verifyEmail('a@a.com', '123456'),
        throwsA(isA<AppException>()),
      );
    }));
  });

  group('resendVerificationCode', () {
    test('200 con success true', async_(() async {
      adapter.stub('POST', '/auth/resend-code', data: {'success': true});
      expect(await ds.resendVerificationCode('a@a.com'), isTrue);
    }));

    test('normaliza email en el body', async_(() async {
      adapter.stub('POST', '/auth/resend-code', data: {'success': true});
      await ds.resendVerificationCode('  SOCIO1@DEMO.COM  ');
      final body = adapter.requests.last.data as Map;
      expect(body['email'], 'socio1@demo.com');
    }));

    test('200 con success false', async_(() async {
      adapter.stub('POST', '/auth/resend-code', data: {'success': false});
      expect(await ds.resendVerificationCode('a@a.com'), isFalse);
    }));

    test('error se mapea', async_(() async {
      adapter.stub('POST', '/auth/resend-code', statusCode: 500, data: {});
      await expectLater(
        () => ds.resendVerificationCode('a@a.com'),
        throwsA(isA<AppException>()),
      );
    }));

    test('429 OTP_RESEND_COOLDOWN lanza excepción dedicada', async_(() async {
      adapter.stub('POST', '/auth/resend-code', statusCode: 429, data: {
        'success': false,
        'error': 'OTP_RESEND_COOLDOWN',
        'message': 'Espera unos segundos antes de solicitar otro código.',
        'retryAfterSeconds': 37,
      });
      await expectLater(
        () => ds.resendVerificationCode('a@a.com'),
        throwsA(
          isA<OtpResendCooldownException>().having(
            (e) => e.retryAfterSeconds,
            'retryAfterSeconds',
            37,
          ),
        ),
      );
    }));

    test('429 genérico sigue usando ErrorMapper', async_(() async {
      adapter.stub('POST', '/auth/resend-code', statusCode: 429, data: {
        'message': 'Demasiadas solicitudes',
      });
      await expectLater(
        () => ds.resendVerificationCode('a@a.com'),
        throwsA(isA<RateLimitException>()),
      );
    }));
  });

  group('password reset endpoints', () {
    test('requestPasswordReset normaliza email y acepta 200 genérico', async_(() async {
      adapter.stub('POST', '/auth/forgot-password', data: {
        'success': true,
        'message':
            'Si el correo está registrado, recibirás un código para restablecer tu contraseña.',
      });
      await ds.requestPasswordReset('  USER@TEST.COM  ');
      final body = adapter.requests.last.data as Map;
      expect(body['email'], 'user@test.com');
    }));

    test('verifyPasswordResetCode devuelve resetToken', async_(() async {
      adapter.stub('POST', '/auth/verify-reset-code', data: {
        'success': true,
        'resetToken': 'opaque-token-value',
      });
      final token =
          await ds.verifyPasswordResetCode('user@test.com', '123456');
      expect(token, 'opaque-token-value');
    }));

    test('verifyPasswordResetCode 400 mapea RESET_CODE_INVALID', async_(() async {
      adapter.stub('POST', '/auth/verify-reset-code', statusCode: 400, data: {
        'success': false,
        'error': 'RESET_CODE_INVALID',
        'message': 'Código inválido o expirado.',
      });
      await expectLater(
        () => ds.verifyPasswordResetCode('user@test.com', '000000'),
        throwsA(isA<ResetCodeInvalidException>()),
      );
    }));

    test('resetPassword envía solo resetToken y password', async_(() async {
      adapter.stub('POST', '/auth/reset-password', data: {
        'success': true,
        'message': 'Contraseña actualizada correctamente.',
      });
      await ds.resetPassword('opaque-token', 'NewPass123!');
      final body = adapter.requests.last.data as Map;
      expect(body['resetToken'], 'opaque-token');
      expect(body['password'], 'NewPass123!');
      expect(body.containsKey('confirmPassword'), isFalse);
    }));

    test('resetPassword 400 mapea RESET_TOKEN_INVALID', async_(() async {
      adapter.stub('POST', '/auth/reset-password', statusCode: 400, data: {
        'success': false,
        'error': 'RESET_TOKEN_INVALID',
        'message':
            'El enlace de recuperación es inválido o expiró. Solicita un nuevo código.',
      });
      await expectLater(
        () => ds.resetPassword('bad', 'NewPass123!'),
        throwsA(isA<ResetTokenInvalidException>()),
      );
    }));
  });
}
