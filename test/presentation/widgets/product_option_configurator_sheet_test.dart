import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/domain/entities/product.dart';
import 'package:flutter_app_saludable/domain/entities/product_option_selection.dart';
import 'package:flutter_app_saludable/presentation/widgets/product_option_configurator_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

Product _batido({
  required List<ProductOptionGroup> groups,
}) {
  return Product(
    id: '7',
    name: 'Batido de leche',
    description: 'Clásico del club',
    optionGroups: groups,
  );
}

Widget _app(Product product) {
  return MaterialApp(
    home: Scaffold(
      body: ProductOptionConfiguratorSheet(product: product),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SINGLE max=1 muestra radios y solo una opción activa',
      (tester) async {
    final product = _batido(groups: [
      ProductOptionGroup(
        id: 2,
        name: 'Sabores',
        minSelections: 1,
        maxSelections: 1,
        options: [
          ProductOption(id: 3, name: 'Frutilla', orden: 0),
          ProductOption(id: 4, name: 'Cookies', orden: 1),
        ],
      ),
    ]);
    await tester.pumpWidget(_app(product));

    expect(find.byType(RadioListTile<int>), findsNWidgets(2));
    expect(find.text('Elige 1'), findsOneWidget);
    expect(tester.widget<ElevatedButton>(find.byKey(const Key('configurator-add'))).onPressed, isNull);

    await tester.tap(find.text('Frutilla'));
    await tester.pump();
    await tester.tap(find.text('Cookies'));
    await tester.pump();

    expect(tester.widget<ElevatedButton>(find.byKey(const Key('configurator-add'))).onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('configurator-add')));
    await tester.pump();
  });

  testWidgets('REPEAT usa contador y bloquea total > max', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final product = _batido(groups: [
      ProductOptionGroup(
        id: 2,
        name: 'Sabores',
        minSelections: 1,
        maxSelections: 2,
        allowRepeat: true,
        options: [
          ProductOption(id: 3, name: 'Frutilla', orden: 0),
          ProductOption(id: 4, name: 'Cookies', orden: 1),
        ],
      ),
    ]);
    await tester.pumpWidget(_app(product));

    expect(find.text('Elige entre 1 y 2'), findsOneWidget);
    expect(
      find.text('Puedes elegir la misma opción más de una vez.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('option-3-plus')), findsOneWidget);

    await tester.tap(find.byKey(const Key('option-3-plus')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('option-3-plus')));
    await tester.pump();
    expect(find.text('2'), findsWidgets);

    expect(
      tester
          .widget<IconButton>(find.descendant(
            of: find.byKey(const Key('option-3-plus')),
            matching: find.byType(IconButton),
          ))
          .onPressed,
      isNull,
    );
    expect(
      tester.widget<ElevatedButton>(find.byKey(const Key('configurator-add'))).onPressed,
      isNotNull,
    );
  });

  testWidgets('MULTI sin repetición no supera max', (tester) async {
    final product = _batido(groups: [
      ProductOptionGroup(
        id: 2,
        name: 'Sabores',
        minSelections: 1,
        maxSelections: 2,
        allowRepeat: false,
        options: [
          ProductOption(id: 3, name: 'Frutilla', orden: 0),
          ProductOption(id: 4, name: 'Cookies', orden: 1),
          ProductOption(id: 5, name: 'Durazno', orden: 2),
        ],
      ),
    ]);
    await tester.pumpWidget(_app(product));
    expect(find.byType(CheckboxListTile), findsNWidgets(3));

    await tester.tap(find.text('Frutilla'));
    await tester.pump();
    await tester.tap(find.text('Cookies'));
    await tester.pump();
    await tester.tap(find.text('Durazno'));
    await tester.pump();

    final tiles = tester.widgetList<CheckboxListTile>(find.byType(CheckboxListTile)).toList();
    expect(tiles.where((t) => t.value == true).length, 2);
  });

  testWidgets('grupo requerido sin opciones bloquea Agregar', (tester) async {
    final product = _batido(groups: [
      ProductOptionGroup(
        id: 2,
        name: 'Sabores',
        minSelections: 1,
        maxSelections: 2,
        options: const [],
      ),
    ]);
    await tester.pumpWidget(_app(product));
    expect(
      find.text('No hay opciones disponibles para completar este producto.'),
      findsOneWidget,
    );
    expect(
      tester.widget<ElevatedButton>(find.byKey(const Key('configurator-add'))).onPressed,
      isNull,
    );
  });

  testWidgets('multi-grupo: Consistencia inválida bloquea, luego permite',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final product = _batido(groups: [
      ProductOptionGroup(
        id: 2,
        name: 'Sabores',
        minSelections: 1,
        maxSelections: 2,
        allowRepeat: true,
        options: [
          ProductOption(id: 3, name: 'Frutilla', orden: 0),
        ],
      ),
      ProductOptionGroup(
        id: 8,
        name: 'Consistencia',
        minSelections: 1,
        maxSelections: 1,
        options: [
          ProductOption(id: 20, name: 'Cremoso', orden: 0),
          ProductOption(id: 21, name: 'Líquido', orden: 1),
        ],
      ),
    ]);
    await tester.pumpWidget(_app(product));

    await tester.tap(find.byKey(const Key('option-3-plus')));
    await tester.pump();
    expect(
      tester.widget<ElevatedButton>(find.byKey(const Key('configurator-add'))).onPressed,
      isNull,
    );

    await tester.tap(find.text('Cremoso'));
    await tester.pump();
    expect(
      tester.widget<ElevatedButton>(find.byKey(const Key('configurator-add'))).onPressed,
      isNotNull,
    );
  });

  testWidgets('opción inactiva no se muestra', (tester) async {
    final product = _batido(groups: [
      ProductOptionGroup(
        id: 2,
        name: 'Sabores',
        minSelections: 1,
        maxSelections: 1,
        options: [
          ProductOption(id: 3, name: 'Frutilla', orden: 0, active: false),
          ProductOption(id: 4, name: 'Cookies', orden: 1),
        ],
      ),
    ]);
    await tester.pumpWidget(_app(product));
    expect(find.text('Frutilla'), findsNothing);
    expect(find.text('Cookies'), findsOneWidget);
  });

  testWidgets('Agregar devuelve IDs nombres y cantidad', (tester) async {
    List<ProductOptionSelection>? result;
    final product = _batido(groups: [
      ProductOptionGroup(
        id: 2,
        name: 'Sabores',
        minSelections: 1,
        maxSelections: 2,
        allowRepeat: true,
        options: [
          ProductOption(id: 3, name: 'Frutilla', orden: 0),
        ],
      ),
    ]);

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result = await showProductOptionConfigurator(
                context: context,
                product: product,
              );
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('option-3-plus')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('option-3-plus')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('configurator-add')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result, hasLength(1));
    expect(result!.single.groupId, 2);
    expect(result!.single.optionId, 3);
    expect(result!.single.optionName, 'Frutilla');
    expect(result!.single.quantity, 2);
  });

  test('flujo nuevo no dispara /sabores ni usa Sabor', () {
    final sheet = File(
            'lib/presentation/widgets/product_option_configurator_sheet.dart')
        .readAsStringSync();
    final screen = File(
            'lib/presentation/screens/member/member_club_products_screen.dart')
        .readAsStringSync();
    expect(sheet.contains('Sabor'), isFalse);
    expect(sheet.contains('/sabores'), isFalse);
    expect(sheet.contains('sabor_remote'), isFalse);
    expect(screen.contains('_loadAllSabores'), isFalse);
  });
}
