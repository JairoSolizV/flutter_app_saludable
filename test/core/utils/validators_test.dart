import 'package:flutter_app_saludable/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators.validateName', () {
    test('null es inválido', () {
      expect(Validators.validateName(null), isNotNull);
    });

    test('vacío o solo espacios es inválido', () {
      expect(Validators.validateName(''), isNotNull);
      expect(Validators.validateName('   '), isNotNull);
    });

    test('menos de 2 caracteres es inválido', () {
      expect(Validators.validateName('A'), isNotNull);
    });

    test('con números es inválido', () {
      expect(Validators.validateName('Juan123'), isNotNull);
    });

    test('con caracteres especiales es inválido', () {
      expect(Validators.validateName('Juan_Perez!'), isNotNull);
    });

    test('nombre simple válido', () {
      expect(Validators.validateName('Juan'), isNull);
    });

    test('nombre con espacios y acentos válido', () {
      expect(Validators.validateName('José María Ñañez'), isNull);
    });
  });

  group('Validators.normalizeEmail', () {
    test('trim + lowercase', () {
      expect(
        Validators.normalizeEmail('  SOCIO1@DEMO.COM  '),
        'socio1@demo.com',
      );
    });
  });

  group('Validators.validateEmail', () {
    test('null es inválido', () {
      expect(Validators.validateEmail(null), isNotNull);
    });

    test('vacío es inválido', () {
      expect(Validators.validateEmail(''), isNotNull);
    });

    test('sin @ es inválido', () {
      expect(Validators.validateEmail('correo.sin.arroba.com'), isNotNull);
      expect(Validators.validateEmail('usuario'), isNotNull);
    });

    test('sin dominio es inválido', () {
      expect(Validators.validateEmail('correo@'), isNotNull);
      expect(Validators.validateEmail('usuario@'), isNotNull);
    });

    test('sin parte local es inválido', () {
      expect(Validators.validateEmail('@gmail.com'), isNotNull);
    });

    test('con espacios en el local es inválido', () {
      expect(Validators.validateEmail('correo raro@dominio.com'), isNotNull);
      expect(Validators.validateEmail('usuario gmail@gmail.com'), isNotNull);
    });

    test('correo simple válido', () {
      expect(Validators.validateEmail('usuario@dominio.com'), isNull);
      expect(Validators.validateEmail('usuario@gmail.com'), isNull);
    });

    test('correo con puntos en local válido', () {
      expect(Validators.validateEmail('usuario.nombre@gmail.com'), isNull);
    });

    test('correo con + alias válido', () {
      expect(Validators.validateEmail('usuario+alias@gmail.com'), isNull);
      expect(Validators.validateEmail('evis96568+prueba@gmail.com'), isNull);
    });

    test('mayúsculas se aceptan (se validan normalizadas)', () {
      expect(Validators.validateEmail('USUARIO@GMAIL.COM'), isNull);
    });

    test('TLD largo válido', () {
      expect(Validators.validateEmail('usuario@dominio.technology'), isNull);
    });

    test('correo con subdominio y puntos válido', () {
      expect(Validators.validateEmail('user.name@mail.sub.dominio.com'), isNull);
    });
  });

  group('Validators.validatePassword', () {
    test('null es inválido', () {
      expect(Validators.validatePassword(null), isNotNull);
    });

    test('vacío es inválido', () {
      expect(Validators.validatePassword(''), isNotNull);
    });

    test('menos de 8 caracteres es inválido', () {
      expect(Validators.validatePassword('1234567'), isNotNull);
    });

    test('exactamente 8 caracteres es válido', () {
      expect(Validators.validatePassword('12345678'), isNull);
    });

    test('contraseña larga es válida', () {
      expect(Validators.validatePassword('unaContraseñaSegura123'), isNull);
    });
  });

  group('Validators.validateBolivianPhone', () {
    test('null es inválido', () {
      expect(Validators.validateBolivianPhone(null), isNotNull);
    });

    test('vacío es inválido', () {
      expect(Validators.validateBolivianPhone(''), isNotNull);
    });

    test('menos de 8 dígitos es inválido', () {
      expect(Validators.validateBolivianPhone('7123456'), isNotNull);
    });

    test('más de 8 dígitos es inválido', () {
      expect(Validators.validateBolivianPhone('712345678'), isNotNull);
    });

    test('no empieza con 6 o 7 es inválido', () {
      expect(Validators.validateBolivianPhone('81234567'), isNotNull);
    });

    test('con letras es inválido', () {
      expect(Validators.validateBolivianPhone('7abc4567'), isNotNull);
    });

    test('empieza con 7 y 8 dígitos es válido', () {
      expect(Validators.validateBolivianPhone('71234567'), isNull);
    });

    test('empieza con 6 y 8 dígitos es válido', () {
      expect(Validators.validateBolivianPhone('61234567'), isNull);
    });
  });

  group('Validators.validateTextNoNumbers', () {
    test('null es inválido', () {
      expect(Validators.validateTextNoNumbers(null), isNotNull);
    });

    test('vacío es inválido', () {
      expect(Validators.validateTextNoNumbers(''), isNotNull);
    });

    test('con números es inválido', () {
      expect(Validators.validateTextNoNumbers('Santa Cruz 2'), isNotNull);
    });

    test('texto simple es válido', () {
      expect(Validators.validateTextNoNumbers('Santa Cruz'), isNull);
    });

    test('texto con acentos es válido', () {
      expect(Validators.validateTextNoNumbers('Cochabamba'), isNull);
    });
  });
}
