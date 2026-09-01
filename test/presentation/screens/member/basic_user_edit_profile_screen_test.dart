import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/domain/entities/user.dart';
import 'package:flutter_app_saludable/presentation/providers/user_provider.dart';
import 'package:flutter_app_saludable/presentation/screens/member/basic_user_edit_profile_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/fake_user_repository.dart';

final _user = User(
  id: '42',
  name: 'Ana Pérez',
  email: 'ana@example.com',
  role: 'basic_user',
  phone: '+59173429001',
);

Future<void> _pumpEditProfile(WidgetTester tester, FakeUserRepository users) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final userProvider = UserProvider(users)..setUser(_user);

  await tester.pumpWidget(
    ChangeNotifierProvider<UserProvider>.value(
      value: userProvider,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => const BasicUserEditProfileScreen(),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('BasicUserEditProfileScreen PROFILE-SOCIAL-FL-001', () {
    testWidgets('Facebook permite espacios mientras escribe', (tester) async {
      final users = FakeUserRepository();
      await _pumpEditProfile(tester, users);

      final facebookField = find.byType(TextFormField).at(5);
      await tester.enterText(facebookField, 'Mi Pagina Oficial');
      await tester.pump();

      expect(find.text('Mi Pagina Oficial'), findsOneWidget);
    });
  });

  group('BasicUserEditProfileScreen BASIC-PROFILE-PHONE-FL-001', () {
    testWidgets('teléfono +591 existente se muestra sin prefijo y es válido',
        (tester) async {
      final users = FakeUserRepository();
      await _pumpEditProfile(tester, users);

      final phoneField = find.byType(TextFormField).at(2);
      final field = tester.widget<TextFormField>(phoneField);
      expect(field.controller?.text, '73429001');
      expect(field.validator?.call('73429001'), isNull);
    });

    testWidgets('editar otro dato guarda sin error de teléfono', (tester) async {
      final users = FakeUserRepository();
      await _pumpEditProfile(tester, users);

      final nameField = find.byType(TextFormField).at(0);
      await tester.enterText(nameField, 'Ana María Pérez');
      await tester.pump();

      final saveButton = find.text('Guardar Cambios');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(users.current?.name, 'Ana María Pérez');
      expect(users.current?.phone, '+59173429001');
      expect(find.textContaining('8 dígitos'), findsNothing);
    });
  });
}
