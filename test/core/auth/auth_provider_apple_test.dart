import 'package:flutter_app_saludable/core/auth/apple_auth_service.dart';
import 'package:flutter_app_saludable/core/auth/secure_token_store.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/data/datasources/remote/auth_remote_data_source.dart';
import 'package:flutter_app_saludable/domain/entities/user.dart';
import 'package:flutter_app_saludable/presentation/providers/auth_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_apple_auth_service.dart';
import 'fake_google_auth_service.dart';
import 'fake_user_repository.dart';
import 'in_memory_secure_storage_gateway.dart';

class _AppleRemote implements AuthRemoteDataSource {
  User? appleResult;
  Object? appleError;
  Map<String, dynamic>? lastAppleBody;
  Map<String, dynamic>? lastLinkBody;
  Object? linkError;
  int linkCalls = 0;

  @override
  Future<User> loginWithApple({
    required String identityToken,
    required String nonce,
    String? authorizationCode,
    String? givenName,
    String? familyName,
  }) async {
    lastAppleBody = {
      'identityToken': identityToken,
      'nonce': nonce,
    };
    final code = authorizationCode?.trim();
    if (code != null && code.isNotEmpty) {
      lastAppleBody!['authorizationCode'] = code;
    }
    if (givenName != null && givenName.trim().isNotEmpty) {
      lastAppleBody!['nombre'] = givenName.trim();
    }
    if (familyName != null && familyName.trim().isNotEmpty) {
      lastAppleBody!['apellido'] = familyName.trim();
    }
    if (appleError != null) throw appleError!;
    return appleResult!;
  }

  @override
  Future<void> linkAppleAccount({
    required String identityToken,
    required String nonce,
    String? authorizationCode,
  }) async {
    linkCalls++;
    lastLinkBody = {
      'identityToken': identityToken,
      'nonce': nonce,
    };
    final code = authorizationCode?.trim();
    if (code != null && code.isNotEmpty) {
      lastLinkBody!['authorizationCode'] = code;
    }
    if (linkError != null) throw linkError!;
  }

  @override
  Future<User> loginWithGoogle(String idToken) async =>
      throw UnimplementedError();

  @override
  Future<User> getMe() async => appleResult!;


  @override
  Future<void> deleteAccount() async => throw UnimplementedError();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeUserRepository users;
  late SecureTokenStore tokenStore;
  late _AppleRemote remote;
  late FakeAppleAuthService apple;

  setUp(() async {
    users = FakeUserRepository();
    final storage = InMemorySecureStorageGateway();
    tokenStore = SecureTokenStore(storage: storage);
    await tokenStore.initialize();
    remote = _AppleRemote();
    apple = FakeAppleAuthService(
      credentials: const AppleAuthCredentials(
        identityToken: 'id.token.value',
        authorizationCode: 'auth.code.value',
        nonce: 'raw-nonce-value',
        givenName: 'Ana',
        familyName: 'Pérez',
      ),
    );
  });

  AuthProvider buildAuth() => AuthProvider(
        remote,
        users,
        tokenStore,
        googleAuthService: FakeGoogleAuthService(),
        appleAuthService: apple,
      );

  test('loginWithApple persiste sesión solo tras éxito remoto', () async {
    remote.appleResult = User(
      id: '9',
      name: 'Ana Pérez',
      email: 'ana@privaterelay.appleid.com',
      role: 'basic_user',
      token: 'jwt-apple',
    );

    final auth = buildAuth();
    final ok = await auth.loginWithApple();

    expect(ok, isTrue);
    expect(auth.currentUser?.id, '9');
    expect(tokenStore.getToken(), 'jwt-apple');
    expect(users.current?.email, 'ana@privaterelay.appleid.com');
    expect(remote.lastAppleBody!['nonce'], 'raw-nonce-value');
    expect(remote.lastAppleBody!['nombre'], 'Ana');
    expect(remote.lastAppleBody!['apellido'], 'Pérez');
  });

  test('sin authorizationCode aún persiste sesión si backend responde 200', () async {
    apple = FakeAppleAuthService(
      credentials: const AppleAuthCredentials(
        identityToken: 'id.token.value',
        nonce: 'raw-nonce-no-code',
      ),
    );
    remote.appleResult = User(
      id: '9',
      name: 'Ana',
      email: 'ana@privaterelay.appleid.com',
      role: 'basic_user',
      token: 'jwt-no-code',
    );
    final auth = buildAuth();
    final ok = await auth.loginWithApple();
    expect(ok, isTrue);
    expect(tokenStore.getToken(), 'jwt-no-code');
    expect(remote.lastAppleBody!.containsKey('authorizationCode'), isFalse);
    expect(remote.lastAppleBody!['identityToken'], 'id.token.value');
    expect(remote.lastAppleBody!['nonce'], 'raw-nonce-no-code');
  });

  test('cancelación de Apple no crea sesión', () async {
    apple = FakeAppleAuthService(credentials: null);
    final auth = buildAuth();
    final ok = await auth.loginWithApple();
    expect(ok, isFalse);
    expect(auth.currentUser, isNull);
    expect(tokenStore.getToken(), isNull);
    expect(remote.lastAppleBody, isNull);
  });

  test('error de servidor no guarda sesión', () async {
    remote.appleError = ValidationException(
      'Token Apple inválido',
      code: 'APPLE_TOKEN_INVALID',
    );
    final auth = buildAuth();
    final ok = await auth.loginWithApple();
    expect(ok, isFalse);
    expect(auth.currentUser, isNull);
    expect(tokenStore.getToken(), isNull);
    expect(auth.errorMessage, isNotNull);
  });

  test('ACCOUNT_LINK_REQUIRED no crea sesión local', () async {
    remote.appleError = AppleAccountLinkRequiredException();
    final auth = buildAuth();
    final ok = await auth.loginWithApple();
    expect(ok, isFalse);
    expect(auth.currentUser, isNull);
    expect(tokenStore.getToken(), isNull);
    expect(
      auth.errorMessage,
      AppleAccountLinkRequiredException.defaultMessage,
    );
  });

  test('autorización posterior sin nombre omite nombre/apellido', () async {
    apple = FakeAppleAuthService(
      credentials: const AppleAuthCredentials(
        identityToken: 'id.token.value',
        authorizationCode: 'auth.code.value',
        nonce: 'raw-nonce-2',
      ),
    );
    remote.appleResult = User(
      id: '9',
      name: 'Usuario',
      email: 'u@privaterelay.appleid.com',
      role: 'member',
      token: 'jwt-2',
    );
    final auth = buildAuth();
    await auth.loginWithApple();
    expect(remote.lastAppleBody!.containsKey('nombre'), isFalse);
    expect(remote.lastAppleBody!.containsKey('apellido'), isFalse);
  });

  test('doble pulsación mientras carga no lanza segunda llamada nativa', () async {
    remote.appleResult = User(
      id: '1',
      name: 'A',
      email: 'a@a.com',
      role: 'basic_user',
      token: 'jwt',
    );
    final auth = buildAuth();
    final first = auth.loginWithApple();
    final second = auth.loginWithApple();
    await Future.wait([first, second]);
    expect(apple.signInCalls, 1);
  });

  test('linkAppleAccount llama remoto sin reemplazar sesión', () async {
    await tokenStore.saveToken('existing-jwt');
    final existing = User(
      id: '3',
      name: 'Existente',
      email: 'existente@test.com',
      role: 'member',
      token: 'existing-jwt',
    );
    await users.saveUser(existing);

    final auth = buildAuth();
    // Hidratar sesión actual sin pasar por login Apple.
    expect(tokenStore.getToken(), 'existing-jwt');

    final ok = await auth.linkAppleAccount();
    expect(ok, isTrue);
    expect(remote.linkCalls, 1);
    expect(remote.lastLinkBody!['identityToken'], 'id.token.value');
    expect(remote.lastLinkBody!['authorizationCode'], 'auth.code.value');
    expect(remote.lastLinkBody!['nonce'], 'raw-nonce-value');
    expect(tokenStore.getToken(), 'existing-jwt');
  });

  test('linkAppleAccount cancelado no llama remoto', () async {
    apple = FakeAppleAuthService(credentials: null);
    final auth = buildAuth();
    final ok = await auth.linkAppleAccount();
    expect(ok, isFalse);
    expect(remote.linkCalls, 0);
  });

  test('linkAppleAccount error expone mensaje sin tocar token', () async {
    await tokenStore.saveToken('jwt-keep');
    remote.linkError = ConflictException(
      'Esta cuenta de Apple ya está vinculada a otro usuario.',
      code: 'APPLE_ALREADY_LINKED',
    );
    final auth = buildAuth();
    final ok = await auth.linkAppleAccount();
    expect(ok, isFalse);
    expect(auth.errorMessage, contains('vinculada'));
    expect(tokenStore.getToken(), 'jwt-keep');
  });
}
