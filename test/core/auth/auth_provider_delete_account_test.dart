import 'package:flutter_app_saludable/core/auth/secure_token_store.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/data/datasources/remote/auth_remote_data_source.dart';
import 'package:flutter_app_saludable/domain/entities/user.dart';
import 'package:flutter_app_saludable/presentation/providers/auth_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_google_auth_service.dart';
import 'fake_user_repository.dart';
import 'in_memory_secure_storage_gateway.dart';

class _DeleteRemote implements AuthRemoteDataSource {
  int deleteCalls = 0;
  Object? deleteError;

  @override
  Future<void> deleteAccount() async {
    deleteCalls++;
    if (deleteError != null) throw deleteError!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeUserRepository users;
  late SecureTokenStore tokenStore;
  late _DeleteRemote remote;

  setUp(() async {
    users = FakeUserRepository();
    final storage = InMemorySecureStorageGateway();
    tokenStore = SecureTokenStore(storage: storage);
    await tokenStore.initialize();
    remote = _DeleteRemote();
  });

  Future<AuthProvider> buildAuthed() async {
    await tokenStore.saveToken('jwt-alive');
    await users.saveUser(User(
      id: '7',
      name: 'Ana',
      email: 'ana@test.com',
      role: 'member',
      token: 'jwt-alive',
    ));
    final auth = AuthProvider(
      remote,
      users,
      tokenStore,
      googleAuthService: FakeGoogleAuthService(),
    );
    // Hidratar currentUser vía bootstrap path simplificado: set vía login no disponible.
    // deleteAccount solo necesita token + remote; logout limpia users/token.
    return auth;
  }

  test('deleteAccount éxito llama endpoint y limpia sesión', () async {
    final auth = await buildAuthed();
    expect(tokenStore.getToken(), 'jwt-alive');

    final result = await auth.deleteAccount();

    expect(result, DeleteAccountResult.success);
    expect(remote.deleteCalls, 1);
    expect(tokenStore.getToken(), isNull);
    expect(users.current, isNull);
    expect(auth.currentUser, isNull);
  });

  test('409 ACCOUNT_HAS_CLUB no limpia sesión', () async {
    remote.deleteError = AccountHasClubException();
    final auth = await buildAuthed();

    final result = await auth.deleteAccount();

    expect(result, DeleteAccountResult.blocked);
    expect(remote.deleteCalls, 1);
    expect(tokenStore.getToken(), 'jwt-alive');
    expect(users.current, isNotNull);
    expect(auth.errorMessage, AccountHasClubException.defaultMessage);
  });

  test('409 ACCOUNT_DELETE_FORBIDDEN no limpia sesión', () async {
    remote.deleteError = AccountDeleteForbiddenException();
    final auth = await buildAuthed();

    final result = await auth.deleteAccount();

    expect(result, DeleteAccountResult.blocked);
    expect(tokenStore.getToken(), 'jwt-alive');
    expect(users.current, isNotNull);
    expect(auth.errorMessage, AccountDeleteForbiddenException.defaultMessage);
  });

  test('401 limpia sesión local', () async {
    remote.deleteError = UnauthorizedException('Sesión inválida');
    final auth = await buildAuthed();

    final result = await auth.deleteAccount();

    expect(result, DeleteAccountResult.sessionExpired);
    expect(tokenStore.getToken(), isNull);
    expect(users.current, isNull);
    expect(auth.currentUser, isNull);
  });

  test('error genérico no limpia sesión', () async {
    remote.deleteError = ServerException('Fallo temporal');
    final auth = await buildAuthed();

    final result = await auth.deleteAccount();

    expect(result, DeleteAccountResult.failed);
    expect(tokenStore.getToken(), 'jwt-alive');
    expect(users.current, isNotNull);
    expect(auth.errorMessage, isNotNull);
  });
}
