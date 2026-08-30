import 'package:flutter_app_saludable/domain/entities/product_option.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';

ProductOptionGroup _group({
  String name = 'Sabores',
  int min = 1,
  int? max = 2,
  bool repeat = false,
  List<String> options = const ['Frutilla', 'Vainilla'],
}) {
  return ProductOptionGroup(
    name: name,
    minSelections: min,
    maxSelections: max,
    allowRepeat: repeat,
    options: [
      for (var i = 0; i < options.length; i++)
        ProductOption(name: options[i], orden: i),
    ],
  );
}

void main() {
  group('ProductOptionGroup.toApiMap', () {
    test('serializa maxSelecciones null de forma explícita', () {
      final json = jsonEncode(_group(max: null, repeat: true).toApiMap());
      expect(json, contains('"maxSelecciones":null'));
      expect(json, contains('"permiteRepetir":true'));
    });
  });

  group('ProductOptionGroupValidator', () {
    test('acepta grupos válidos', () {
      expect(ProductOptionGroupValidator.validate([_group()]), isEmpty);
    });

    test('grupo vacío de opciones invalida', () {
      final issues = ProductOptionGroupValidator.validate([
        ProductOptionGroup(name: 'Sabores', options: const []),
      ]);
      expect(issues.any((e) => e.field == 'options'), isTrue);
    });

    test('nombre de grupo vacío invalida', () {
      final issues = ProductOptionGroupValidator.validate([_group(name: '  ')]);
      expect(issues.any((e) => e.field == 'name'), isTrue);
    });

    test('grupos duplicados case-insensitive invalidan', () {
      final issues = ProductOptionGroupValidator.validate([
        _group(name: 'Sabores'),
        _group(name: 'sabores', options: const ['Chocolate']),
      ]);
      expect(issues.any((e) => e.message.contains('Ya existe un grupo')), isTrue);
    });

    test('opción vacía invalida', () {
      final issues = ProductOptionGroupValidator.validate([
        _group(options: const ['Frutilla', '  ']),
      ]);
      expect(issues.any((e) => e.field == 'optionName'), isTrue);
    });

    test('opción duplicada invalida', () {
      final issues = ProductOptionGroupValidator.validate([
        _group(options: const ['Frutilla', 'frutilla']),
      ]);
      expect(issues.any((e) => e.message.contains('duplicada')), isTrue);
    });

    test('max menor que min invalida', () {
      final issues = ProductOptionGroupValidator.validate([
        _group(min: 2, max: 1),
      ]);
      expect(issues.any((e) => e.field == 'max'), isTrue);
    });

    test('max imposible sin repetición invalida', () {
      final issues = ProductOptionGroupValidator.validate([
        _group(min: 1, max: 3, repeat: false, options: const ['A', 'B']),
      ]);
      expect(
        issues.any((e) => e.message.contains('no puede superar la cantidad')),
        isTrue,
      );
    });

    test('con repetición max puede superar cantidad de opciones', () {
      expect(
        ProductOptionGroupValidator.validate([
          _group(min: 1, max: 3, repeat: true, options: const ['A', 'B']),
        ]),
        isEmpty,
      );
    });
  });

  group('selectionRuleLabel', () {
    test('describe min/max y exactamente', () {
      expect(_group(min: 1, max: 2).selectionRuleLabel, 'Selecciona de 1 a 2');
      expect(
        _group(min: 1, max: 1).selectionRuleLabel,
        'Selecciona exactamente 1',
      );
      expect(
        _group(min: 1, max: null).selectionRuleLabel,
        'Selecciona al menos 1',
      );
    });
  });
}
