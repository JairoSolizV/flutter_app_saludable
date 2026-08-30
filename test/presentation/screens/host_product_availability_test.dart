import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/data/datasources/remote/club_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/combo_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/product_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/sabor_remote_data_source.dart';
import 'package:flutter_app_saludable/domain/entities/combo.dart';
import 'package:flutter_app_saludable/domain/entities/product.dart';
import 'package:flutter_app_saludable/domain/entities/sabor.dart';
import 'package:flutter_app_saludable/domain/entities/user.dart';
import 'package:flutter_app_saludable/domain/repositories/product_repository.dart';
import 'package:flutter_app_saludable/presentation/providers/product_provider.dart';
import 'package:flutter_app_saludable/presentation/providers/user_provider.dart';
import 'package:flutter_app_saludable/presentation/screens/host/products/host_edit_product_screen.dart';
import 'package:flutter_app_saludable/presentation/screens/host/products/host_product_list_screen.dart';
import 'package:flutter_app_saludable/presentation/screens/host/products/host_product_proposal_screen.dart';
import 'package:flutter_app_saludable/presentation/screens/host/products/host_product_review_screen.dart';
import 'package:flutter_app_saludable/presentation/screens/host/products/host_product_sabores_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/auth/fake_user_repository.dart';

Product _local({
  required String id,
  required String name,
  required String estado,
  bool available = false,
}) {
  return Product(
    id: id,
    name: name,
    description: 'Desc $name',
    tipo: 'LOCAL',
    estadoAprobacion: estado,
    available: available,
    clubCreadorId: 3,
  );
}

class _FakeProductRepo implements ProductRepository {
  List<Product> products = [];
  int toggleCalls = 0;
  Completer<void>? toggleGate;
  Object? toggleError;

  @override
  Future<List<Product>> getProducts(
      {required int hubId, required int clubId}) async {
    return products;
  }

  @override
  Future<List<Product>> getAvailableProductsByClub(int clubId) async =>
      products;

  @override
  Future<Product?> getProductById(String id) async =>
      products.cast<Product?>().firstWhere((p) => p!.id == id, orElse: () => null);

  @override
  Future<void> createProduct(Product product, int clubId) async {}

  @override
  Future<void> updateProduct(Product product) async {}

  @override
  Future<void> deleteProduct(String id) async {}

  @override
  Future<void> toggleProductAvailability(int clubId, String productId) async {
    toggleCalls++;
    if (toggleGate != null) {
      await toggleGate!.future;
    }
    if (toggleError != null) throw toggleError!;
  }
}

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

class _FakeComboDs extends ComboRemoteDataSource {
  _FakeComboDs() : super(Dio());

  @override
  Future<List<Combo>> getCombosByClub(int clubId) async => [];
}

class _FakeSaborDs extends SaborRemoteDataSource {
  _FakeSaborDs() : super(Dio());

  int getSaboresCalls = 0;

  @override
  Future<List<Sabor>> getSaboresDeProductoEnClub(
          int clubId, int productoId) async {
    getSaboresCalls++;
    return [];
  }
}

class _FakeProductRemote implements ProductRemoteDataSource {
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
  }) async {}

  @override
  Future<Product> updateProduct(Product product) async => product;

  @override
  Future<Product> reenviarProducto(String productId) async =>
      Product(id: productId, name: '', description: '');

  @override
  Future<void> deleteProduct(String id) async {}

  @override
  Future<void> toggleProductAvailability(int clubId, String productId) async {}
}

Widget _listApp({
  required List<Product> products,
  _FakeProductRepo? repo,
  _FakeSaborDs? saborDs,
}) {
  final productRepo = repo ?? _FakeProductRepo();
  productRepo.products = products;
  final sabor = saborDs ?? _FakeSaborDs();
  final user = User(
    id: '20',
    name: 'Host',
    email: 'host@test.com',
    role: 'host',
  );
  final router = GoRouter(
    initialLocation: '/host/products',
    routes: [
      GoRoute(
        path: '/host/products',
        builder: (_, __) => const HostProductListScreen(),
        routes: [
          GoRoute(
            path: 'review',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>;
              return HostProductReviewScreen(
                clubId: extra['clubId'] as int,
                product: extra['product'] as Product,
              );
            },
          ),
          GoRoute(
            path: 'proposal',
            builder: (context, state) {
              final extra = state.extra;
              return HostProductProposalScreen(
                product: extra is Product ? extra : null,
              );
            },
          ),
        ],
      ),
    ],
  );

  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) {
          final p = UserProvider(FakeUserRepository()..current = user);
          p.setUser(user);
          return p;
        },
      ),
      ChangeNotifierProvider(create: (_) => ProductProvider(productRepo)),
      Provider<ClubRemoteDataSource>.value(value: _FakeClubDs()),
      Provider<ComboRemoteDataSource>.value(value: _FakeComboDs()),
      Provider<SaborRemoteDataSource>.value(value: sabor),
      Provider<ProductRemoteDataSource>.value(value: _FakeProductRemote()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Future<void> _openPropios(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(find.text('Propios'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HostProductListScreen disponibilidad del club', () {
    testWidgets('APROBADO usa el switch de Disponible en mi club',
        (tester) async {
      final repo = _FakeProductRepo();
      await tester.pumpWidget(_listApp(
        products: [
          _local(id: '8', name: 'Batido Aprobado', estado: 'APROBADO'),
        ],
        repo: repo,
      ));
      await _openPropios(tester);

      expect(find.byKey(const ValueKey('club-avail-8')), findsOneWidget);
      expect(find.text('Activo'), findsNothing);
      expect(find.text('Eliminar'), findsNothing);

      final sw = tester.widget<Switch>(
        find.byKey(const ValueKey('club-avail-8')),
      );
      expect(sw.onChanged, isNotNull);

      await tester.tap(find.byKey(const ValueKey('club-avail-8')));
      await tester.pumpAndSettle();

      expect(repo.toggleCalls, 1);
    });

    testWidgets('doble tap con request pendiente dispara un solo toggle',
        (tester) async {
      final repo = _FakeProductRepo()..toggleGate = Completer<void>();
      await tester.pumpWidget(_listApp(
        products: [
          _local(id: '8', name: 'Batido Aprobado', estado: 'APROBADO'),
        ],
        repo: repo,
      ));
      await _openPropios(tester);

      await tester.tap(find.byKey(const ValueKey('club-avail-8')));
      await tester.pump();

      expect(repo.toggleCalls, 1);
      expect(
        tester
            .widget<Switch>(find.byKey(const ValueKey('club-avail-8')))
            .onChanged,
        isNull,
      );

      final ctx = tester.element(find.byType(HostProductListScreen));
      await Provider.of<ProductProvider>(ctx, listen: false)
          .toggleAvailability(3, '8', 1);
      expect(repo.toggleCalls, 1);

      repo.toggleGate!.complete();
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Switch>(find.byKey(const ValueKey('club-avail-8')))
            .onChanged,
        isNotNull,
      );
      expect(repo.toggleCalls, 1);
    });

    testWidgets('error libera el switch y muestra mensaje', (tester) async {
      final repo = _FakeProductRepo()
        ..toggleError = ServerException('No se pudo cambiar disponibilidad');
      await tester.pumpWidget(_listApp(
        products: [
          _local(id: '8', name: 'Batido Aprobado', estado: 'APROBADO'),
        ],
        repo: repo,
      ));
      await _openPropios(tester);

      await tester.tap(find.byKey(const ValueKey('club-avail-8')));
      await tester.pumpAndSettle();

      expect(find.text('No se pudo cambiar disponibilidad'), findsOneWidget);
      expect(
        tester
            .widget<Switch>(find.byKey(const ValueKey('club-avail-8')))
            .onChanged,
        isNotNull,
      );
    });

    testWidgets('LOCAL PENDIENTE no permite toggle', (tester) async {
      final repo = _FakeProductRepo();
      await tester.pumpWidget(_listApp(
        products: [_local(id: '7', name: 'Te Verde', estado: 'PENDIENTE')],
        repo: repo,
      ));
      await _openPropios(tester);

      expect(
        tester
            .widget<Switch>(find.byKey(const ValueKey('club-avail-7')))
            .onChanged,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('club-avail-7')));
      await tester.pumpAndSettle();
      expect(repo.toggleCalls, 0);
    });

    testWidgets('LOCAL RECHAZADO no permite toggle', (tester) async {
      final repo = _FakeProductRepo();
      await tester.pumpWidget(_listApp(
        products: [_local(id: '6', name: 'Frappe', estado: 'RECHAZADO')],
        repo: repo,
      ));
      await _openPropios(tester);

      expect(
        tester
            .widget<Switch>(find.byKey(const ValueKey('club-avail-6')))
            .onChanged,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('club-avail-6')));
      await tester.pumpAndSettle();
      expect(repo.toggleCalls, 0);
    });

    testWidgets(
        'mientras el toggle está pendiente, tocar la fila no abre detalle ni sabores',
        (tester) async {
      final repo = _FakeProductRepo()..toggleGate = Completer<void>();
      final sabor = _FakeSaborDs();
      await tester.pumpWidget(_listApp(
        products: [
          _local(id: '6', name: 'Batido Aprobado', estado: 'APROBADO'),
        ],
        repo: repo,
        saborDs: sabor,
      ));
      await _openPropios(tester);

      await tester.tap(find.byKey(const ValueKey('club-avail-6')));
      await tester.pump();

      expect(repo.toggleCalls, 1);
      expect(find.byType(HostProductSaboresScreen), findsNothing);
      expect(find.byType(HostProductReviewScreen), findsNothing);

      await tester.tap(find.text('Batido Aprobado'));
      await tester.pump();
      await tester.longPress(find.text('Batido Aprobado'));
      await tester.pump();

      expect(find.byType(HostProductSaboresScreen), findsNothing);
      expect(find.byType(HostProductReviewScreen), findsNothing);
      expect(find.byType(HostEditProductScreen), findsNothing);
      expect(find.text('Editar Producto'), findsNothing);
      expect(find.text('Mi Menú (Stock)'), findsOneWidget);
      expect(sabor.getSaboresCalls, 0);

      repo.toggleGate!.complete();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Batido Aprobado'));
      await tester.pumpAndSettle();

      expect(find.byType(HostProductSaboresScreen), findsNothing);
      expect(find.byType(HostProductReviewScreen), findsOneWidget);
      expect(find.text('Estado: APROBADO'), findsOneWidget);
      expect(sabor.getSaboresCalls, 0);
    });

    testWidgets('long-press APROBADO no abre el editor legacy', (tester) async {
      await tester.pumpWidget(_listApp(
        products: [
          _local(id: '8', name: 'Batido Aprobado', estado: 'APROBADO'),
        ],
      ));
      await _openPropios(tester);

      await tester.longPress(find.text('Batido Aprobado'));
      await tester.pumpAndSettle();

      expect(find.text('Editar Producto'), findsNothing);
      expect(find.byType(HostEditProductScreen), findsNothing);
    });
  });

  group('HostEditProductScreen legacy', () {
    testWidgets('no muestra Eliminar ni control de product.active',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HostEditProductScreen(
            clubId: 3,
            product: Product(
              id: '8',
              name: 'Batido',
              description: 'Desc',
              active: false,
              available: true,
            ),
          ),
        ),
      );

      expect(find.text('Eliminar'), findsNothing);
      expect(find.byIcon(Icons.delete), findsNothing);
      expect(find.byType(Switch), findsNothing);
      expect(find.text('Activo'), findsNothing);
      expect(find.text('Desactivar producto'), findsNothing);
      expect(
        find.textContaining('Disponible en mi club'),
        findsOneWidget,
      );
    });
  });

  test('ninguna UI de anfitrión llama ProductProvider.deleteProduct', () {
    final hostDir = Directory('lib/presentation/screens/host');
    expect(hostDir.existsSync(), isTrue);
    for (final entity in hostDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final src = entity.readAsStringSync();
      expect(
        src.contains('.deleteProduct('),
        isFalse,
        reason: '${entity.path} no debe invocar deleteProduct',
      );
    }
  });
}
