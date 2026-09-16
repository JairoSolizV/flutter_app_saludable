import 'package:flutter_app_saludable/domain/entities/user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('User codigoSorteo', () {
    test('fromMap parsea codigo_sorteo desde SQLite', () {
      final user = User.fromMap({
        'id': '1',
        'name': 'Ana',
        'email': 'a@a.com',
        'role': 'basic_user',
        'codigo_sorteo': '4827',
      });

      expect(user.codigoSorteo, '4827');
    });

    test('fromMap con null/vacío no inventa valor', () {
      expect(
        User.fromMap({
          'id': '1',
          'name': 'Ana',
          'email': 'a@a.com',
          'role': 'member',
          'codigo_sorteo': null,
        }).codigoSorteo,
        isNull,
      );
      expect(
        User.fromMap({
          'id': '1',
          'name': 'Ana',
          'email': 'a@a.com',
          'role': 'member',
          'codigo_sorteo': '   ',
        }).codigoSorteo,
        isNull,
      );
      expect(
        User.fromMap({
          'id': '1',
          'name': 'Ana',
          'email': 'a@a.com',
          'role': 'member',
        }).codigoSorteo,
        isNull,
      );
    });

    test('toMap persiste codigo_sorteo', () {
      final map = User(
        id: '1',
        name: 'Ana',
        email: 'a@a.com',
        role: 'member',
        codigoSorteo: '4827',
      ).toMap();

      expect(map['codigo_sorteo'], '4827');
      expect(map['token'], isNull);
    });

    test('copyWith conserva codigoSorteo al editar perfil', () {
      final original = User(
        id: '1',
        name: 'Ana',
        email: 'a@a.com',
        role: 'member',
        phone: '70000000',
        birthDate: '1990-01-01',
        socialMedia: {'instagram': '@ana'},
        codigoSorteo: '4827',
      );

      final updated = original.copyWith(
        name: 'Ana Pérez',
        phone: '71111111',
        birthDate: '1991-02-02',
        socialMedia: {'instagram': '@ana2'},
      );

      expect(updated.codigoSorteo, '4827');
      expect(updated.name, 'Ana Pérez');
      expect(updated.phone, '71111111');
    });

    test('withoutToken conserva codigoSorteo', () {
      final user = User(
        id: '1',
        name: 'Ana',
        email: 'a@a.com',
        role: 'member',
        token: 'jwt.token.value',
        codigoSorteo: '4827',
      );

      expect(user.withoutToken().token, isNull);
      expect(user.withoutToken().codigoSorteo, '4827');
    });
  });
}
