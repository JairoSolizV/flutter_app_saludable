import 'package:flutter_app_saludable/domain/entities/product.dart';
import 'package:flutter_app_saludable/domain/entities/product_option_selection.dart';
import 'package:flutter_test/flutter_test.dart';

ProductOptionGroup _sabores({
  int min = 1,
  int? max = 2,
  bool repeat = true,
  List<ProductOption>? options,
}) {
  return ProductOptionGroup(
    id: 2,
    name: 'Sabores',
    orden: 0,
    minSelections: min,
    maxSelections: max,
    allowRepeat: repeat,
    options: options ??
        [
          ProductOption(id: 3, name: 'Frutilla', orden: 0),
          ProductOption(id: 4, name: 'Cookies', orden: 1),
          ProductOption(id: 5, name: 'Durazno', orden: 2),
        ],
  );
}

ProductOptionGroup _consistencia({
  int min = 1,
  int? max = 1,
}) {
  return ProductOptionGroup(
    id: 8,
    name: 'Consistencia',
    orden: 1,
    minSelections: min,
    maxSelections: max,
    options: [
      ProductOption(id: 20, name: 'Cremoso', orden: 0),
      ProductOption(id: 21, name: 'Líquido', orden: 1),
    ],
  );
}

Product _product(List<ProductOptionGroup>? groups) {
  return Product(
    id: '7',
    name: 'Batido de leche',
    description: 'Clásico',
    optionGroups: groups,
  );
}

void main() {
  group('PARSING / producto sin grupos', () {
    test('draft vacío es válido y no inventa Sabores', () {
      final draft = ProductConfigurationDraft(_product(null));
      expect(draft.groups, isEmpty);
      expect(draft.isValid, isTrue);
      expect(draft.toSelections(), isEmpty);

      final empty = ProductConfigurationDraft(_product(const []));
      expect(empty.groups, isEmpty);
      expect(empty.isValid, isTrue);
    });
  });

  group('SINGLE max=1', () {
    test('modo single y solo una opción activa a la vez', () {
      final group = _consistencia();
      expect(ProductConfigurationDraft.modeFor(group), OptionGroupUiMode.single);
      final draft = ProductConfigurationDraft(_product([group]));
      expect(draft.isValid, isFalse);

      draft.selectSingle(group, group.options[0]);
      expect(draft.quantity(group, group.options[0]), 1);
      draft.selectSingle(group, group.options[1]);
      expect(draft.quantity(group, group.options[0]), 0);
      expect(draft.quantity(group, group.options[1]), 1);
      expect(draft.groupTotal(group), 1);
      expect(draft.isValid, isTrue);
    });
  });

  group('MULTI sin repetición', () {
    test('permite varias hasta max y respeta min', () {
      final group = _sabores(min: 1, max: 2, repeat: false);
      expect(ProductConfigurationDraft.modeFor(group), OptionGroupUiMode.multi);
      final draft = ProductConfigurationDraft(_product([group]));
      expect(draft.isValid, isFalse);

      draft.setMultiSelected(group, group.options[0], true);
      expect(draft.isValid, isTrue);
      draft.setMultiSelected(group, group.options[1], true);
      expect(draft.groupTotal(group), 2);

      draft.setMultiSelected(group, group.options[2], true);
      expect(draft.groupTotal(group), 2);
      expect(draft.quantity(group, group.options[2]), 0);

      draft.setMultiSelected(group, group.options[0], false);
      expect(draft.quantity(group, group.options[0]), 0);
      expect(draft.isValid, isTrue);
    });
  });

  group('REPEAT contador', () {
    test('Frutilla x2 válido con max=2 y total 3 bloqueado', () {
      final group = _sabores(min: 1, max: 2, repeat: true);
      expect(ProductConfigurationDraft.modeFor(group), OptionGroupUiMode.counter);
      final draft = ProductConfigurationDraft(_product([group]));
      final frutilla = group.options[0];
      final cookies = group.options[1];

      draft.increment(group, frutilla);
      draft.increment(group, frutilla);
      expect(draft.quantity(group, frutilla), 2);
      expect(draft.isValid, isTrue);
      expect(draft.canIncrement(group, frutilla), isFalse);

      draft.decrement(group, frutilla);
      draft.increment(group, cookies);
      expect(draft.groupTotal(group), 2);
      expect(draft.isValid, isTrue);

      draft.increment(group, cookies);
      expect(draft.groupTotal(group), 2);
      expect(draft.isValid, isTrue);
    });
  });

  group('NULL MAX', () {
    test('max=null no limita el total', () {
      final group = _sabores(min: 1, max: null, repeat: true);
      final draft = ProductConfigurationDraft(_product([group]));
      final frutilla = group.options[0];
      for (var i = 0; i < 5; i++) {
        draft.increment(group, frutilla);
      }
      expect(draft.quantity(group, frutilla), 5);
      expect(draft.isValid, isTrue);
    });
  });

  group('EMPTY', () {
    test('grupo requerido sin opciones bloquea', () {
      final group = ProductOptionGroup(
        id: 2,
        name: 'Sabores',
        minSelections: 1,
        maxSelections: 2,
        options: const [],
      );
      final draft = ProductConfigurationDraft(_product([group]));
      expect(draft.isValid, isFalse);
      expect(
        draft.groupError(group),
        ProductConfigurationDraft.emptyRequiredGroupMessage,
      );
    });

    test('grupo opcional vacío no bloquea', () {
      final group = ProductOptionGroup(
        id: 2,
        name: 'Extras',
        minSelections: 0,
        maxSelections: null,
        options: const [],
      );
      final draft = ProductConfigurationDraft(_product([group]));
      expect(draft.isValid, isTrue);
      expect(draft.groupError(group), isNull);
    });

    test('opción inactiva no es seleccionable', () {
      final group = _sabores(
        min: 1,
        max: 1,
        repeat: false,
        options: [
          ProductOption(id: 3, name: 'Frutilla', orden: 0, active: false),
          ProductOption(id: 4, name: 'Cookies', orden: 1, active: true),
        ],
      );
      final draft = ProductConfigurationDraft(_product([group]));
      expect(group.selectableOptions.map((o) => o.name), ['Cookies']);
      draft.selectSingle(group, group.selectableOptions.first);
      expect(draft.toSelections().single.optionName, 'Cookies');
    });
  });

  group('MULTI-GROUP', () {
    test('un grupo inválido invalida el producto', () {
      final sabores = _sabores(min: 1, max: 2, repeat: true);
      final consistencia = _consistencia();
      final draft = ProductConfigurationDraft(_product([sabores, consistencia]));
      draft.increment(sabores, sabores.options[0]);
      expect(draft.groupError(sabores), isNull);
      expect(draft.groupError(consistencia), isNotNull);
      expect(draft.isValid, isFalse);
    });

    test('ambos válidos permite continuar y expone IDs', () {
      final sabores = _sabores(min: 1, max: 2, repeat: true);
      final consistencia = _consistencia();
      final draft = ProductConfigurationDraft(_product([sabores, consistencia]));
      draft.increment(sabores, sabores.options[0]);
      draft.increment(sabores, sabores.options[0]);
      draft.selectSingle(consistencia, consistencia.options[0]);
      expect(draft.isValid, isTrue);

      final sels = draft.toSelections();
      expect(sels, hasLength(2));
      expect(sels.first.groupId, 2);
      expect(sels.first.optionId, 3);
      expect(sels.first.optionName, 'Frutilla');
      expect(sels.first.quantity, 2);
      expect(sels.last.groupId, 8);
      expect(sels.last.optionId, 20);
      expect(sels.last.quantity, 1);

      final keyA = ProductOptionSelection.cartKey('7', sels);
      final other = [
        ProductOptionSelection(
          groupId: 2,
          groupName: 'Sabores',
          optionId: 4,
          optionName: 'Cookies',
          quantity: 1,
        ),
        ProductOptionSelection(
          groupId: 8,
          groupName: 'Consistencia',
          optionId: 20,
          optionName: 'Cremoso',
          quantity: 1,
        ),
      ];
      final keyB = ProductOptionSelection.cartKey('7', other);
      expect(keyA, isNot(keyB));
      expect(keyA.startsWith('7#'), isTrue);
      expect(keyA.contains('Batido'), isFalse);
    });
  });
}
