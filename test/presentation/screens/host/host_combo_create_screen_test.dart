import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/data/datasources/remote/combo_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/product_remote_data_source.dart';
import 'package:flutter_app_saludable/domain/entities/combo.dart';
import 'package:flutter_app_saludable/domain/entities/product.dart';
import 'package:flutter_app_saludable/presentation/screens/host/products/host_combo_create_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakeProductRemote implements ProductRemoteDataSource {
  final List<Product> products;

  _FakeProductRemote(this.products);

  @override
  Future<List<Product>> getProducts({required int hubId, required int clubId}) =>
      Future.value(products);

  @override
  Future<List<Product>> getAvailableProductsByClub(int clubId) async =>
      products;

  @override
  Future<void> createProduct(Product product, int clubId) =>
      throw UnimplementedError();

  @override
  Future<String> uploadProductImage(dynamic imageFile) =>
      throw UnimplementedError();

  @override
  Future<void> createProductProposal({
    required int hubId,
    required String nombre,
    required String descripcion,
    required String ingredientes,
    required int puntosValor,
    required double precio,
    String? imagenUrl,
    List<ProductOptionGroup>? optionGroups,
  }) =>
      throw UnimplementedError();

  @override
  Future<Product> updateProduct(Product product) => throw UnimplementedError();

  @override
  Future<Product?> updateClubSalePrice({
    required int clubId,
    required String productId,
    required double? precioVenta,
  }) =>
      throw UnimplementedError();

  @override
  Future<Product> reenviarProducto(String productId) =>
      throw UnimplementedError();

  @override
  Future<void> deleteProduct(String id) => throw UnimplementedError();

  @override
  Future<void> toggleProductAvailability(int clubId, String productId) =>
      throw UnimplementedError();
}

class _RecordingComboRemote extends ComboRemoteDataSource {
  _RecordingComboRemote() : super(Dio());

  Map<String, dynamic>? lastCreateBody;
  double? lastPrecio;

  @override
  Future<Combo> createCombo(
    int clubId, {
    required String nombre,
    String? descripcion,
    String? imagenUrl,
    int? puntosValor,
    required double precio,
    required List<Map<String, dynamic>> items,
  }) async {
    lastPrecio = precio;
    lastCreateBody = {
      'nombre': nombre,
      'precio': precio,
      'items': items,
    };
    return Combo(
      id: 99,
      clubId: clubId,
      nombre: nombre,
      price: precio,
      items: items
          .map(
            (e) => ComboItem(
              productoId: e['productoId'] as int,
              productoNombre: 'P',
              cantidad: e['cantidad'] as int? ?? 1,
            ),
          )
          .toList(),
    );
  }

  @override
  Future<Combo> updateCombo(
    int clubId,
    int comboId, {
    required String nombre,
    String? descripcion,
    String? imagenUrl,
    int? puntosValor,
    required double precio,
    required List<Map<String, dynamic>> items,
  }) async {
    lastPrecio = precio;
    lastCreateBody = {
      'nombre': nombre,
      'precio': precio,
      'items': items,
    };
    return Combo(
      id: comboId,
      clubId: clubId,
      nombre: nombre,
      price: precio,
      items: const [],
    );
  }
}

Widget _wrap({
  required Widget child,
  required ProductRemoteDataSource products,
  required ComboRemoteDataSource combos,
}) {
  return Provider<ProductRemoteDataSource>.value(
    value: products,
    child: Provider<ComboRemoteDataSource>.value(
      value: combos,
      child: MaterialApp(home: child),
    ),
  );
}

Product _product({
  required String id,
  required String name,
  required double price,
  int puntos = 5,
}) {
  return Product(
    id: id,
    name: name,
    description: '',
    price: price,
    effectivePrice: price,
    category: 'Batidos',
    imageUrl: '',
    puntosValor: puntos,
  );
}

void main() {
  group('HostComboCreateScreen', () {
    testWidgets('muestra referencia total por separado y preview puntos',
        (tester) async {
      final products = [
        _product(id: '7', name: 'Batido', price: 20),
        _product(id: '2', name: 'Té', price: 15),
      ];
      final comboRemote = _RecordingComboRemote();

      await tester.pumpWidget(
        _wrap(
          products: _FakeProductRemote(products),
          combos: comboRemote,
          child: const HostComboCreateScreen(clubId: 1),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Agregar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Batido'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agregar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Té'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('host-combo-reference-total')), findsOneWidget);
      expect(find.textContaining('Bs 35'), findsOneWidget);
      expect(find.byKey(const Key('host-combo-points-preview')), findsOneWidget);
      expect(find.textContaining('Puntos del combo:'), findsOneWidget);
      expect(find.text('Sabor'), findsNothing);
    });

    testWidgets('precio mayor que referencia no bloquea guardado', (tester) async {
      final products = [_product(id: '7', name: 'Batido', price: 20)];
      final comboRemote = _RecordingComboRemote();

      await tester.pumpWidget(
        _wrap(
          products: _FakeProductRemote(products),
          combos: comboRemote,
          child: const HostComboCreateScreen(clubId: 1),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'Combo test');
      await tester.tap(find.text('Agregar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Batido'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('host-combo-price-field')),
        '50',
      );

      await tester.tap(find.text('Crear Combo'));
      await tester.pumpAndSettle();

      expect(comboRemote.lastPrecio, 50);
      expect(comboRemote.lastCreateBody?['precio'], 50);
    });

    testWidgets('precio <= 0 bloquea guardado', (tester) async {
      final products = [_product(id: '7', name: 'Batido', price: 20)];

      await tester.pumpWidget(
        _wrap(
          products: _FakeProductRemote(products),
          combos: _RecordingComboRemote(),
          child: const HostComboCreateScreen(clubId: 1),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'Combo test');
      await tester.tap(find.text('Agregar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Batido'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('host-combo-price-field')),
        '0',
      );
      await tester.tap(find.text('Crear Combo'));
      await tester.pumpAndSettle();

      expect(find.text('Ingresa un precio mayor a 0'), findsOneWidget);
    });

    testWidgets('edición precarga precio legacy', (tester) async {
      final products = [_product(id: '7', name: 'Batido', price: 20)];
      final existing = Combo(
        id: 4,
        clubId: 1,
        nombre: 'Combo desayuno',
        price: 38,
        puntosValor: 15,
        items: [ComboItem(productoId: 7, productoNombre: 'Batido')],
      );

      await tester.pumpWidget(
        _wrap(
          products: _FakeProductRemote(products),
          combos: _RecordingComboRemote(),
          child: HostComboCreateScreen(clubId: 1, existingCombo: existing),
        ),
      );
      await tester.pumpAndSettle();

      final field = tester.widget<TextFormField>(
        find.byKey(const Key('host-combo-price-field')),
      );
      expect(field.controller?.text, '38.00');
    });
  });
}
