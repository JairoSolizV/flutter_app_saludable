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
import 'package:flutter_app_saludable/presentation/screens/host/products/host_product_list_screen.dart';
import 'package:flutter_app_saludable/presentation/screens/host/products/host_product_proposal_screen.dart';
import 'package:flutter_app_saludable/presentation/screens/host/products/host_product_review_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/auth/fake_user_repository.dart';

Product _local({
  required String id,
  required String name,
  required String estado,
  String comentario = 'falta info',
}) {
  return Product(
    id: id,
    name: name,
    description: 'Desc $name',
    ingredientes: 'leche, hielo',
    puntosValor: 10,
    tipo: 'LOCAL',
    estadoAprobacion: estado,
    comentarioRevision: comentario,
    revisadoPorNombre: 'Admin Hub',
    revisadoAt: DateTime(2026, 8, 29, 18, 30),
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

  @override
  Future<List<Sabor>> getSaboresDeProductoEnClub(
          int clubId, int productoId) async =>
      [];
}

class _FakeProductRemote implements ProductRemoteDataSource {
  Product? lastUpdated;
  int updateCalls = 0;
  int reenviarCalls = 0;
  Object? reenviarError;

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
  }) async {}

  @override
  Future<void> updateProduct(Product product) async {
    updateCalls++;
    lastUpdated = product;
  }

  @override
  Future<Product> reenviarProducto(String productId) async {
    reenviarCalls++;
    if (reenviarError != null) throw reenviarError!;
    return Product(
      id: productId,
      name: 'Frappe',
      description: 'Desc',
      tipo: 'LOCAL',
      estadoAprobacion: 'PENDIENTE',
      comentarioRevision: 'falta info',
      ingredientes: 'leche, hielo',
      puntosValor: 10,
    );
  }

  @override
  Future<void> deleteProduct(String id) async {}

  @override
  Future<void> toggleProductAvailability(int clubId, String productId) async {}
}

Widget _listApp({
  required List<Product> products,
  required _FakeProductRemote remote,
  _FakeProductRepo? repo,
}) {
  final productRepo = repo ?? _FakeProductRepo();
  productRepo.products = products;
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
      Provider<SaborRemoteDataSource>.value(value: _FakeSaborDs()),
      Provider<ProductRemoteDataSource>.value(value: remote),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HostProductListScreen tap', () {
    testWidgets('RECHAZADO no abre sabores y abre detalle', (tester) async {
      await tester.pumpWidget(_listApp(
        products: [_local(id: '6', name: 'Frappe', estado: 'RECHAZADO')],
        remote: _FakeProductRemote(),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Propios'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Frappe'));
      await tester.pumpAndSettle();

      expect(find.text('Propuesta de producto'), findsOneWidget);
      expect(find.text('Sabores'), findsNothing);
      expect(find.text('Motivo del rechazo'), findsOneWidget);
    });

    testWidgets('PENDIENTE no abre sabores y muestra En revisión',
        (tester) async {
      await tester.pumpWidget(_listApp(
        products: [_local(id: '7', name: 'Te Verde', estado: 'PENDIENTE')],
        remote: _FakeProductRemote(),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Propios'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Te Verde'));
      await tester.pumpAndSettle();

      expect(find.text('En revisión'), findsWidgets);
      expect(find.text('Sabores'), findsNothing);
      expect(find.text('Editar propuesta'), findsNothing);
      expect(find.text('Reenviar a revisión'), findsNothing);
    });

    testWidgets('APROBADO mantiene pantalla de sabores', (tester) async {
      await tester.pumpWidget(_listApp(
        products: [_local(id: '8', name: 'Batido Aprobado', estado: 'APROBADO')],
        remote: _FakeProductRemote(),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Propios'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Batido Aprobado'));
      await tester.pumpAndSettle();

      expect(find.text('Sabores'), findsOneWidget);
      expect(find.text('Propuesta de producto'), findsNothing);
    });
  });

  group('HostProductReviewScreen detalle', () {
    testWidgets('RECHAZADO muestra comentario, Editar y Reenviar',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HostProductReviewScreen(
            clubId: 3,
            product: _local(id: '6', name: 'Frappe', estado: 'RECHAZADO'),
          ),
        ),
      );

      expect(find.text('Motivo del rechazo'), findsOneWidget);
      expect(find.text('falta info'), findsOneWidget);
      expect(find.textContaining('Revisado por: Admin Hub'), findsOneWidget);
      expect(find.text('Editar propuesta'), findsOneWidget);
      expect(find.text('Reenviar a revisión'), findsOneWidget);
    });

    testWidgets('PENDIENTE muestra En revisión y oculta acciones',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HostProductReviewScreen(
            clubId: 3,
            product: _local(id: '7', name: 'Te Verde', estado: 'PENDIENTE'),
          ),
        ),
      );

      expect(find.text('En revisión'), findsWidgets);
      expect(
        find.text('Tu propuesta está siendo revisada por el administrador.'),
        findsOneWidget,
      );
      expect(find.text('Editar propuesta'), findsNothing);
      expect(find.text('Reenviar a revisión'), findsNothing);
    });
  });

  group('HostProductProposalScreen edición', () {
    testWidgets('precarga datos, hace PUT y no llama reenviar', (tester) async {
      final remote = _FakeProductRemote();
      final rejected = _local(id: '6', name: 'Frappe', estado: 'RECHAZADO');

      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ProductRemoteDataSource>.value(value: remote),
            Provider<ClubRemoteDataSource>.value(value: _FakeClubDs()),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<Product>(
                          builder: (_) =>
                              HostProductProposalScreen(product: rejected),
                        ),
                      );
                    },
                    child: const Text('abrir edicion'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('abrir edicion'));
      await tester.pumpAndSettle();

      expect(find.text('Editar propuesta'), findsOneWidget);
      expect(find.text('Frappe'), findsOneWidget);
      expect(find.text('leche, hielo'), findsOneWidget);
      expect(find.text('Guardar cambios'), findsOneWidget);

      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Guardar cambios'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar cambios'));
      await tester.pumpAndSettle();

      expect(remote.updateCalls, 1);
      expect(remote.reenviarCalls, 0);
      expect(remote.lastUpdated?.estadoAprobacion, 'RECHAZADO');
      expect(remote.lastUpdated?.ingredientes, 'leche, hielo');
      expect(remote.lastUpdated?.puntosValor, 10);
      expect(find.text('Cambios guardados'), findsOneWidget);
    });
  });

  group('Reenviar propuesta', () {
    testWidgets('cancelar no hace request', (tester) async {
      final remote = _FakeProductRemote();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ProductRemoteDataSource>.value(value: remote),
          ],
          child: MaterialApp(
            home: HostProductReviewScreen(
              clubId: 3,
              product: _local(id: '6', name: 'Frappe', estado: 'RECHAZADO'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Reenviar a revisión'));
      await tester.pumpAndSettle();
      expect(find.text('¿Reenviar producto?'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(remote.reenviarCalls, 0);
    });

    testWidgets('confirmar hace PATCH y pasa a PENDIENTE', (tester) async {
      final remote = _FakeProductRemote();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ProductRemoteDataSource>.value(value: remote),
          ],
          child: MaterialApp(
            home: HostProductReviewScreen(
              clubId: 3,
              product: _local(id: '6', name: 'Frappe', estado: 'RECHAZADO'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Reenviar a revisión'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Reenviar'));
      await tester.pumpAndSettle();

      expect(remote.reenviarCalls, 1);
      expect(find.text('Producto reenviado a revisión'), findsOneWidget);
      expect(find.text('En revisión'), findsWidgets);
      expect(find.text('Editar propuesta'), findsNothing);
      expect(find.text('Reenviar a revisión'), findsNothing);
    });

    testWidgets('error muestra mensaje del backend', (tester) async {
      final remote = _FakeProductRemote()
        ..reenviarError = ValidationException(
          'Solo se puede reenviar un producto RECHAZADO',
        );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ProductRemoteDataSource>.value(value: remote),
          ],
          child: MaterialApp(
            home: HostProductReviewScreen(
              clubId: 3,
              product: _local(id: '6', name: 'Frappe', estado: 'RECHAZADO'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Reenviar a revisión'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Reenviar'));
      await tester.pumpAndSettle();

      expect(
        find.text('Solo se puede reenviar un producto RECHAZADO'),
        findsOneWidget,
      );
      expect(find.text('Reenviar a revisión'), findsOneWidget);
    });
  });
}
