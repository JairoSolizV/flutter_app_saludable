import 'package:flutter_app_saludable/core/auth/google_auth_service.dart';

/// Fake inyectable en [AuthProvider] para tests de logout Google (AUTH-022).
class FakeGoogleAuthService extends GoogleAuthService {
  FakeGoogleAuthService({this.throwOnSignOut = false});

  int signOutCalls = 0;
  bool throwOnSignOut;

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (throwOnSignOut) {
      throw StateError('Google signOut failed');
    }
  }
}
