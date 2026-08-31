import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/data/datasources/remote/club_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/product_remote_data_source.dart';
import 'package:flutter_app_saludable/domain/entities/product.dart';
import 'package:flutter_app_saludable/presentation/screens/host/products/host_edit_product_screen.dart';
import 'package:flutter_app_saludable/presentation/screens/host/products/host_product_proposal_screen.dart';
import 'package:flutter_app_saludable/presentation/widgets/product_image.dart';
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
        lat: -17.7,
        lng: -63.1,
        estado: 'ACTIVO',
      );
}

class _TrackingProductRemote implements ProductRemoteDataSource {
  int createCalls = 0;
  int updateCalls = 0;
  String? lastCreateImagenUrl;
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
  Future<String> uploadProductImage(File imageFile) async =>
      throw StateError('upload no debe usarse');

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
  }) async {
    createCalls++;
    lastCreateImagenUrl = imagenUrl;
  }

  @override
  Future<Product> updateProduct(Product product) async {
    updateCalls++;
    lastUpdated = product;
    return product;
  }

  @override
  Future<Product?> updateClubSalePrice({
    required int clubId,
    required String productId,
    required double? precioVenta,
  }) async =>
      null;

  @override
  Future<Product> reenviarProducto(String productId) async =>
      Product(id: productId, name: '', description: '');

  @override
  Future<void> deleteProduct(String id) async {}

  @override
  Future<void> toggleProductAvailability(int clubId, String productId) async {}
}

Widget _proposalApp(
  ProductRemoteDataSource remote, {
  Product? product,
}) {
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
    find.widgetWithIcon(TextFormField, LucideIcons.coffee),
    'Batido Proteico',
  );
  await tester.enterText(
    find.widgetWithIcon(TextFormField, LucideIcons.list),
    'proteína, hielo',
  );
  await tester.enterText(
    find.widgetWithIcon(TextFormField, LucideIcons.star),
    '10',
  );
  await tester.enterText(find.byKey(const Key('precio-venta-field')), '28.50');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpLarge(WidgetTester tester, Widget app) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app);
    await tester.pump();
  }

  Future<void> submitCreate(WidgetTester tester) async {
    await _fillRequired(tester);
    await tester.tap(find.text('Enviar a Revisión'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('HostProductProposalScreen imagen', () {
    testWidgets('no muestra campo manual de URL', (tester) async {
      await pumpLarge(tester, _proposalApp(_TrackingProductRemote()));

      expect(find.text('O pega la URL de la imagen'), findsNothing);
      expect(find.text('Elegir de galería'), findsNothing);
      expect(find.text('https://...'), findsNothing);
    });

    testWidgets('crear producto muestra Sin imagen y no exige foto', (tester) async {
      await pumpLarge(tester, _proposalApp(_TrackingProductRemote()));

      expect(find.text('Sin imagen'), findsOneWidget);
      await submitCreate(tester);
      expect(find.text('Propuesta enviada'), findsOneWidget);
    });

    testWidgets('create no envía URL fake ni placeholder', (tester) async {
      final remote = _TrackingProductRemote();
      await pumpLarge(tester, _proposalApp(remote));
      await submitCreate(tester);

      expect(remote.createCalls, 1);
      expect(remote.lastCreateImagenUrl, isNull);
    });

    testWidgets('edit con imagen existente la conserva al guardar otro campo',
        (tester) async {
      final remote = _TrackingProductRemote();
      final product = Product(
        id: '42',
        name: 'Batido',
        description: 'Desc',
        ingredientes: 'leche',
        puntosValor: 10,
        price: 28.5,
        effectivePrice: 28.5,
        imageUrl: 'https://cdn.example.com/batido.png',
        tipo: 'LOCAL',
        estadoAprobacion: 'RECHAZADO',
      );

      await pumpLarge(tester, _proposalApp(remote, product: product));
      expect(find.byType(ProductImage), findsOneWidget);
      expect(find.text('Sin imagen'), findsNothing);

      await tester.enterText(
        find.widgetWithIcon(TextFormField, LucideIcons.coffee),
        'Batido Renovado',
      );
      await tester.tap(find.text('Guardar cambios'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(remote.updateCalls, 1);
      expect(remote.lastUpdated?.imageUrl, 'https://cdn.example.com/batido.png');
      expect(remote.lastUpdated?.name, 'Batido Renovado');
    });

    testWidgets('edit sin imagen muestra Sin imagen y puede guardar', (tester) async {
      final remote = _TrackingProductRemote();
      final product = Product(
        id: '43',
        name: 'Batido',
        description: 'Desc',
        ingredientes: 'leche',
        puntosValor: 10,
        price: 28.5,
        effectivePrice: 28.5,
        tipo: 'LOCAL',
        estadoAprobacion: 'RECHAZADO',
      );

      await pumpLarge(tester, _proposalApp(remote, product: product));
      expect(find.text('Sin imagen'), findsOneWidget);

      await tester.enterText(
        find.widgetWithIcon(TextFormField, LucideIcons.coffee),
        'Batido Sin Foto',
      );
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      expect(remote.lastUpdated?.imageUrl, '');
      expect(remote.lastUpdated?.name, 'Batido Sin Foto');
    });
  });

  group('ProductImage display', () {
    testWidgets('producto con imagen usa ProductImage', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProductImage(imageUrl: 'https://cdn.example.com/p.png'),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(ProductImage), findsOneWidget);
    });

    testWidgets('producto sin imagen usa placeholder', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProductImage(imageUrl: null),
          ),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.inventory_2_outlined), findsNothing);
      expect(find.byIcon(LucideIcons.cupSoda), findsOneWidget);
    });
  });

  group('HostEditProductScreen legacy', () {
    testWidgets('no muestra campo URL de imagen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HostEditProductScreen(
            clubId: 3,
            product: Product(
              id: '9',
              name: 'Legacy',
              description: 'D',
              price: 10,
              imageUrl: 'https://cdn.example.com/legacy.png',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('URL'), findsNothing);
      expect(find.textContaining('imagen'), findsNothing);
    });
  });
}
