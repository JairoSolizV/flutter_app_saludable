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

    test('error se mapea a AppException', async_(() async {
      adapter.stub('GET', '/auth/check-email', statusCode: 500, data: {});
      await expectLater(
        () => ds.checkEmailExists('a@a.com'),
        throwsA(isA<AppException>()),
      );
    }));
  });

  group('login', () {
    test('éxito con rol Map anidado (admin) devuelve host', async_(() async {
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
      final user = await ds.login('ana@test.com', 'pass');
      expect(user.role, 'host');
      expect(user.name, 'Ana Perez');
      expect(user.token, 'tok123');
      expect(user.phone, '123');
    }));

    test('rolId 4 mapea a basic_user', async_(() async {
      adapter.stub('POST', '/auth/login', data: {
        'token': 'tok',
        'id': 2,
        'nombre': 'Beto',
        'apellido': 'Diaz',
        'email': 'beto@test.com',
        'rolId': 4,
      });
      final user = await ds.login('beto@test.com', 'pass');
      expect(user.role, 'basic_user');
    }));

    test('rolNombre string USUARIO_BASICO mapea a basic_user', async_(() async {
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

    test('sin datos de rol reconocidos mantiene member por defecto',
        async_(() async {
      adapter.stub('POST', '/auth/login', data: {
        'token': 'tok',
        'id': 4,
        'nombre': 'Dan',
        'apellido': 'Lopez',
        'email': 'dan@test.com',
      });
      final user = await ds.login('dan@test.com', 'pass');
      expect(user.role, 'member');
    }));

    test('redesSociales como String se parsea como instagram',
        async_(() async {
      adapter.stub('POST', '/auth/login', data: {
        'token': 'tok',
        'id': 5,
        'nombre': 'Eva',
        'apellido': 'Mora',
        'email': 'eva@test.com',
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

    test('status distinto de 200/201 lanza ServerException', async_(() async {
      adapter.stub('POST', '/auth/login', statusCode: 202, data: {'id': 1});
      await expectLater(
        () => ds.login('x@x.com', 'bad'),
        throwsA(isA<AppException>()),
      );
    }));
  });

  group('register', () {
    test('éxito hace POST con rolId cuando se provee', async_(() async {
      adapter.stub('POST', '/auth/register', statusCode: 201, data: {
        'token': 'tok',
        'id': 6,
        'nombre': 'Fer',
        'apellido': 'Gomez',
        'email': 'fer@test.com',
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
      });
      final updated = await ds.updateUser(User(
        id: '7',
        name: 'Gina Torres',
        email: 'gina@test.com',
        role: 'member',
      ));
      expect(updated.id, '7');
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
    test('200 parsea el usuario actual', async_(() async {
      adapter.stub('GET', '/auth/me', data: {
        'token': 'tok',
        'id': 11,
        'nombre': 'Ka',
        'apellido': 'Ren',
        'email': 'ka@test.com',
      });
      final user = await ds.getMe();
      expect(user.id, '11');
    }));

    test('error se mapea', async_(() async {
      adapter.stub('GET', '/auth/me', statusCode: 401, data: {});
      await expectLater(() => ds.getMe(), throwsA(isA<AppException>()));
    }));
  });

  group('verifyEmail', () {
    test('200 con verified true', async_(() async {
      adapter.stub('POST', '/auth/verify-email', data: {'verified': true});
      expect(await ds.verifyEmail('a@a.com', '123456'), isTrue);
    }));

    test('200 con verified false', async_(() async {
      adapter.stub('POST', '/auth/verify-email', data: {'verified': false});
      expect(await ds.verifyEmail('a@a.com', '000000'), isFalse);
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
  });
}
