import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/data/datasources/remote/club_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/product_remote_data_source.dart';
import 'package:flutter_app_saludable/domain/entities/product.dart';
import 'package:flutter_app_saludable/domain/entities/product_option.dart';
import 'package:flutter_app_saludable/presentation/screens/host/products/host_product_proposal_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

class _FakeClubDs extends ClubRemoteDataSource {
  _FakeClubDs() : super(Dio());

  @override
  Future<Club?> getMyClub() async => Club(
        id: 3,
        hubId: 1,
        hubNombre: 'Hub',
        anfitrionId: 20,
        anfitrionNombre: 'Host',
        nombreClub: 'Club Test',
        direccion: '',
        horario: '',
        lat: 0,
        lng: 0,
        estado: 'ACTIVO',
      );
}

class _FakeProductRemote implements ProductRemoteDataSource {
  int createCalls = 0;
  int updateCalls = 0;
  int reenviarCalls = 0;
  List<ProductOptionGroup>? lastCreateGroups;
  Product? lastUpdated;

  @override
  Future<List<Product>> getProducts(
          {required int hubId, required int clubId}) async =>
      [];

  @override
  Future<List<Product>> getAvailableProductsByClub(int clubId) async => [];

  @override
  Future<void> createProduct(Product product, int clubId) async {}

  @override
  Future<String> uploadProductImage(File imageFile) async => '';

  @override
  Future<void> createProductProposal({
    required int hubId,
    required String nombre,
    required String descripcion,
    required String ingredientes,
    required int puntosValor,
    String? imagenUrl,
    List<ProductOptionGroup>? optionGroups,
  }) async {
    createCalls++;
    lastCreateGroups = optionGroups;
  }

  @override
  Future<Product> updateProduct(Product product) async {
    updateCalls++;
    lastUpdated = product;
    return product;
  }

  @override
  Future<Product> reenviarProducto(String productId) async {
    reenviarCalls++;
    return Product(id: productId, name: '', description: '');
  }

  @override
  Future<void> deleteProduct(String id) async {}

  @override
  Future<void> toggleProductAvailability(int clubId, String productId) async {}
}

Widget _app(ProductRemoteDataSource remote, {Product? product}) {
  return MultiProvider(
    providers: [
      Provider<ProductRemoteDataSource>.value(value: remote),
      Provider<ClubRemoteDataSource>.value(value: _FakeClubDs()),
    ],
    child: MaterialApp(
      home: HostProductProposalScreen(product: product),
    ),
  );
}

Future<void> _fillRequired(WidgetTester tester) async {
  await tester.enterText(
      find.widgetWithIcon(TextFormField, LucideIcons.coffee), 'Batido');
  await tester.enterText(
      find.widgetWithIcon(TextFormField, LucideIcons.list), 'proteína');
  await tester.enterText(
      find.widgetWithIcon(TextFormField, LucideIcons.star), '10');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpForm(WidgetTester tester, Widget app) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app);
  }

  testWidgets('producto sin grupos se envía en el POST', (tester) async {
    final remote = _FakeProductRemote();
    await pumpForm(tester, _app(remote));
    await _fillRequired(tester);
    await tester.ensureVisible(find.text('Enviar a Revisión'));
    await tester.tap(find.text('Enviar a Revisión'));
    await tester.pump();
    await tester.pump();

    expect(remote.createCalls, 1);
    expect(remote.lastCreateGroups, isNull);
    expect(find.text('Propuesta enviada'), findsOneWidget);
  });

  testWidgets('agregar y eliminar grupo/opción', (tester) async {
    await pumpForm(tester, _app(_FakeProductRemote()));

    await tester.ensureVisible(find.byKey(const Key('add-option-group')));
    await tester.tap(find.byKey(const Key('add-option-group')));
    await tester.pump();
    expect(find.byKey(const Key('option-group-0')), findsOneWidget);

    await tester.tap(find.byKey(const Key('option-group-0-add-option')));
    await tester.pump();
    expect(find.byKey(const Key('option-group-0-option-1-name')), findsOneWidget);

    await tester.tap(find.byKey(const Key('option-group-0-option-1-remove')));
    await tester.pump();
    expect(find.byKey(const Key('option-group-0-option-1-name')), findsNothing);

    await tester.tap(find.byKey(const Key('option-group-0-remove')));
    await tester.pump();
    expect(find.byKey(const Key('option-group-0')), findsNothing);
  });

  testWidgets('grupo vacío invalida y no envía', (tester) async {
    final remote = _FakeProductRemote();
    await pumpForm(tester, _app(remote));
    await _fillRequired(tester);
    await tester.ensureVisible(find.byKey(const Key('add-option-group')));
    await tester.tap(find.byKey(const Key('add-option-group')));
    await tester.pump();
    await tester.enterText(
        find.byKey(const Key('option-group-0-name')), 'Sabores');
    await tester.ensureVisible(find.text('Enviar a Revisión'));
    await tester.tap(find.text('Enviar a Revisión'));
    await tester.pumpAndSettle();

    expect(remote.createCalls, 0);
    expect(find.textContaining('no puede estar vacío'), findsWidgets);
  });

  testWidgets('grupo duplicado invalida', (tester) async {
    final remote = _FakeProductRemote();
    await pumpForm(tester, _app(remote));
    await _fillRequired(tester);
    await tester.ensureVisible(find.byKey(const Key('add-option-group')));
    await tester.tap(find.byKey(const Key('add-option-group')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('add-option-group')));
    await tester.pump();

    await tester.enterText(
        find.byKey(const Key('option-group-0-name')), 'Sabores');
    await tester.enterText(
        find.byKey(const Key('option-group-0-option-0-name')), 'Frutilla');
    await tester.enterText(
        find.byKey(const Key('option-group-1-name')), 'sabores');
    await tester.enterText(
        find.byKey(const Key('option-group-1-option-0-name')), 'Chocolate');

    await tester.ensureVisible(find.text('Enviar a Revisión'));
    await tester.tap(find.text('Enviar a Revisión'));
    await tester.pumpAndSettle();
    expect(remote.createCalls, 0);
    expect(find.textContaining('Ya existe un grupo'), findsWidgets);
  });

  testWidgets('opción duplicada invalida', (tester) async {
    final remote = _FakeProductRemote();
    await pumpForm(tester, _app(remote));
    await _fillRequired(tester);
    await tester.ensureVisible(find.byKey(const Key('add-option-group')));
    await tester.tap(find.byKey(const Key('add-option-group')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('option-group-0-add-option')));
    await tester.pump();
    await tester.enterText(
        find.byKey(const Key('option-group-0-name')), 'Sabores');
    await tester.enterText(
        find.byKey(const Key('option-group-0-option-0-name')), 'Frutilla');
    await tester.enterText(
        find.byKey(const Key('option-group-0-option-1-name')), 'frutilla');
    await tester.ensureVisible(find.text('Enviar a Revisión'));
    await tester.tap(find.text('Enviar a Revisión'));
    await tester.pumpAndSettle();
    expect(remote.createCalls, 0);
    expect(find.textContaining('duplicada'), findsWidgets);
  });

  testWidgets('max menor que min invalida', (tester) async {
    final remote = _FakeProductRemote();
    await pumpForm(tester, _app(remote));
    await _fillRequired(tester);
    await tester.ensureVisible(find.byKey(const Key('add-option-group')));
    await tester.tap(find.byKey(const Key('add-option-group')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('option-group-0-unlimited')));
    await tester.pump();
    await tester.enterText(
        find.byKey(const Key('option-group-0-name')), 'Sabores');
    await tester.enterText(find.byKey(const Key('option-group-0-min')), '2');
    await tester.enterText(find.byKey(const Key('option-group-0-max')), '1');
    await tester.enterText(
        find.byKey(const Key('option-group-0-option-0-name')), 'Frutilla');
    await tester.enterText(
        find.byKey(const Key('option-group-0-option-0-name')), 'Frutilla');
    await tester.tap(find.byKey(const Key('option-group-0-add-option')));
    await tester.pump();
    await tester.enterText(
        find.byKey(const Key('option-group-0-option-1-name')), 'Vainilla');
    await tester.ensureVisible(find.text('Enviar a Revisión'));
    await tester.tap(find.text('Enviar a Revisión'));
    await tester.pumpAndSettle();
    expect(remote.createCalls, 0);
    expect(find.textContaining('máximo no puede ser menor'), findsWidgets);
  });

  testWidgets('max imposible sin repetición invalida', (tester) async {
    final remote = _FakeProductRemote();
    await pumpForm(tester, _app(remote));
    await _fillRequired(tester);
    await tester.ensureVisible(find.byKey(const Key('add-option-group')));
    await tester.tap(find.byKey(const Key('add-option-group')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('option-group-0-unlimited')));
    await tester.pump();
    await tester.enterText(
        find.byKey(const Key('option-group-0-name')), 'Sabores');
    await tester.enterText(find.byKey(const Key('option-group-0-min')), '1');
    await tester.enterText(find.byKey(const Key('option-group-0-max')), '3');
    await tester.enterText(
        find.byKey(const Key('option-group-0-option-0-name')), 'Frutilla');
    await tester.ensureVisible(find.text('Enviar a Revisión'));
    await tester.tap(find.text('Enviar a Revisión'));
    await tester.pumpAndSettle();
    expect(remote.createCalls, 0);
    expect(find.textContaining('no puede superar la cantidad'), findsWidgets);
  });

  testWidgets('creación con grupos manda la definición', (tester) async {
    final remote = _FakeProductRemote();
    await pumpForm(tester, _app(remote));
    await _fillRequired(tester);
    await tester.ensureVisible(find.byKey(const Key('add-option-group')));
    await tester.tap(find.byKey(const Key('add-option-group')));
    await tester.pump();
    await tester.enterText(
        find.byKey(const Key('option-group-0-name')), 'Sabores');
    await tester.enterText(
        find.byKey(const Key('option-group-0-option-0-name')), 'Frutilla');
    await tester.tap(find.byKey(const Key('option-group-0-add-option')));
    await tester.pump();
    await tester.enterText(
        find.byKey(const Key('option-group-0-option-1-name')), 'Vainilla');
    await tester.ensureVisible(find.text('Enviar a Revisión'));
    await tester.tap(find.text('Enviar a Revisión'));
    await tester.pump();
    await tester.pump();

    expect(remote.createCalls, 1);
    expect(remote.lastCreateGroups, hasLength(1));
    expect(remote.lastCreateGroups!.first.name, 'Sabores');
    expect(
      remote.lastCreateGroups!.first.options.map((o) => o.name),
      ['Frutilla', 'Vainilla'],
    );
    expect(remote.lastCreateGroups!.first.maxSelections, isNull);
  });
}
