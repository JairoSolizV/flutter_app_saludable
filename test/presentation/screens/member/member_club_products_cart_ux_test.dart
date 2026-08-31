import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/core/auth/session_owner.dart';
import 'package:flutter_app_saludable/core/pagination/paged_result.dart';
import 'package:flutter_app_saludable/core/services/connectivity_service.dart';
import 'package:flutter_app_saludable/core/services/sync_service.dart';
import 'package:flutter_app_saludable/data/datasources/remote/combo_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/membresia_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/order_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/sabor_remote_data_source.dart';
import 'package:flutter_app_saludable/domain/entities/attendance.dart';
import 'package:flutter_app_saludable/domain/entities/arbol_referidos.dart';
import 'package:flutter_app_saludable/domain/entities/club_membership.dart';
import 'package:flutter_app_saludable/domain/entities/combo.dart';
import 'package:flutter_app_saludable/domain/entities/order_entity.dart';
import 'package:flutter_app_saludable/domain/entities/product.dart';
import 'package:flutter_app_saludable/domain/entities/sabor.dart';
import 'package:flutter_app_saludable/domain/entities/user.dart';
import 'package:flutter_app_saludable/domain/repositories/order_repository.dart';
import 'package:flutter_app_saludable/domain/repositories/product_repository.dart';
import 'package:flutter_app_saludable/presentation/providers/order_provider.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/core/orders/order_offline_messages.dart';
import 'package:flutter_app_saludable/presentation/providers/product_provider.dart';
import 'package:flutter_app_saludable/presentation/providers/user_provider.dart';
import 'package:flutter_app_saludable/presentation/screens/member/member_club_products_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/fake_user_repository.dart';

class _FakeMembresiaDs implements MembresiaRemoteDataSource {
  Object? getMembresiasError;

  @override
  Future<List<ClubMembership>> getMembresiasPorUsuario(int usuarioId) async {
    if (getMembresiasError != null) throw getMembresiasError!;
    return [
        ClubMembership(
          id: 10,
          usuarioId: usuarioId,
          usuarioNombre: 'Socio',
          clubId: 3,
          clubNombre: 'Club Test',
          nivelId: 1,
          nivelNombre: 'Socio',
          numeroSocio: '001',
          puntosAcumulados: 0,
          fechaRegistro: '2026-01-01',
          estado: 'ACTIVO',
        ),
      ];
  }

  @override
  Future<void> activarSocio({
    required int clubId,
    required String activationPayload,
    int? referidoPorMembresiaId,
    String? comoConocio,
    required bool esClientePreferenteODistribuidor,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> crearMembresia({
    required int usuarioId,
    required int clubId,
    int? nivelId,
    Map<String, dynamic>? extraData,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<Attendance>> getAsistencias(int membresiaId) =>
      throw UnimplementedError();

  @override
  Future<AsistenciaResponse> registrarAsistencia({
    required int membresiaId,
    required int clubId,
    required double latitud,
    required double longitud,
    double? precisionMetros,
  }) =>
      throw UnimplementedError();

  @override
  Future<Attendance> registrarAsistenciaManual({
    required int membresiaId,
    String? fecha,
    String? nota,
  }) =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> getEstadoCombo(int membresiaId) =>
      throw UnimplementedError();

  @override
  Future<List<ClubMembership>> buscarMiembrosGlobal({String? query}) =>
      throw UnimplementedError();

  @override
  Future<PagedResult<ClubMembership>> buscarMiembrosGlobalPage({
    String? query,
    int page = 0,
    int size = 20,
  }) =>
      throw UnimplementedError();

  @override
  Future<ArbolReferidos> getArbolReferidos(int membresiaId) =>
      throw UnimplementedError();
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

class _FakeProductRepo implements ProductRepository {
  _FakeProductRepo(this.products);
  final List<Product> products;

  @override
  Future<List<Product>> getAvailableProductsByClub(int clubId) async =>
      products;

  @override
  Future<List<Product>> getProducts(
          {required int hubId, required int clubId}) async =>
      products;

  @override
  Future<Product?> getProductById(String id) async {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Future<void> createProduct(Product product, int clubId) async {}

  @override
  Future<void> updateProduct(Product product) async {}

  @override
  Future<void> deleteProduct(String id) async {}

  @override
  Future<void> toggleProductAvailability(int clubId, String productId) async {}
}

class _CapturingOrderRepo implements OrderRepository {
  OrderEntity? lastOrder;
  Object? throwOnCreate;

  @override
  Future<void> createOrder(OrderEntity order) async {
    if (throwOnCreate != null) throw throwOnCreate!;
    lastOrder = order;
  }

  @override
  Future<List<OrderEntity>> getOrdersByUser(String userId) async => [];

  @override
  Future<List<OrderEntity>> getUnsyncedOrdersForUser(String userId) async => [];

  @override
  Future<List<OrderEntity>> getLocalUnsentOrdersForUser(String userId) async =>
      [];

  @override
  Future<int> countOrphanUnsyncedOrders() async => 0;

  @override
  Future<void> markAsSynced(String orderId) async {}

  @override
  Future<void> markOrdersAsSynced(List<String> orderIds) async {}

  @override
  Future<void> markSyncFailed(
    String orderId, {
    String? errorCode,
    String? errorMessage,
  }) async {}

  @override
  Future<void> updateOrderStatus(String orderId, String status) async {}

  @override
  Future<void> deleteOrder(String orderId) async {}

  @override
  Future<void> deleteOrders(List<String> orderIds) async {}
}

class _FakeRemoteOrders implements OrderRemoteDataSource {
  @override
  Future<void> sendOrder(OrderEntity order, {required List<OrderItem> items, required List<OrderCombo> combos}) async {}

  @override
  Future<void> createCounterSale({
    required int clubId,
    required String tipoPago,
    String? socioCodigo,
    String? tipoConsumo,
    String? observaciones,
    required List<Map<String, dynamic>> items,
    List<Map<String, dynamic>> combos = const [],
  }) async {}

  @override
  Future<List<Map<String, dynamic>>> getOrdersByClub(int clubId) async => [];

  @override
  Future<List<Map<String, dynamic>>> getOrdersBySocio(int membresiaId) async =>
      [];

  @override
  Future<PagedResult<Map<String, dynamic>>> getOrdersByClubPage(int clubId,
          {int page = 0,
          int size = 20,
          String? estado,
          String? desde,
          String? hasta}) =>
      throw UnimplementedError();

  @override
  Future<PagedResult<Map<String, dynamic>>> getOrdersBySocioPage(int membresiaId,
          {int page = 0,
          int size = 20,
          String? estado,
          String? desde,
          String? hasta}) =>
      throw UnimplementedError();

  @override
  Future<void> updateOrderStatus(int pedidoId, String newStatus,
          {int? estimatedTime}) =>
      throw UnimplementedError();

  @override
  Future<List<Map<String, dynamic>>> getAllOrders() async => [];
}

Product _simpleProduct() {
  return Product(
    id: '7',
    name: 'Batido de leche',
    description: 'Desc',
    price: 20,
    effectivePrice: 20,
    active: true,
    available: true,
  );
}

Future<void> _pumpProductsScreen(
  WidgetTester tester, {
  required _CapturingOrderRepo orderRepo,
  List<Product> products = const [],
  bool hasConnection = true,
}) async {
  final userRepo = FakeUserRepository()
    ..current = User(
      id: '1',
      name: 'Socio',
      email: 's@test.com',
      role: 'SOCIO',
    );

  final userProvider = UserProvider(userRepo);
  userProvider.setUser(userRepo.current!);

  final productProvider = ProductProvider(_FakeProductRepo(products));
  await productProvider.loadAvailableProducts(3);

  final orderProvider = OrderProvider(
    orderRepo,
    ConnectivityService.forTest(checkConnection: () async => hasConnection),
    SyncService(
      orderRepo,
      ConnectivityService.forTest(checkConnection: () async => hasConnection),
      _FakeRemoteOrders(),
      SessionOwner()..setUserId('1'),
    ),
  );

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const MemberClubProductsScreen(
          clubId: 3,
          clubNombre: 'Club Test',
        ),
      ),
      GoRoute(
        path: '/member-orders',
        builder: (_, __) => const Scaffold(body: Text('Historial pedidos')),
      ),
    ],
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: userProvider),
        ChangeNotifierProvider.value(value: productProvider),
        ChangeNotifierProvider.value(value: orderProvider),
        Provider<MembresiaRemoteDataSource>.value(value: _FakeMembresiaDs()),
        Provider<ComboRemoteDataSource>.value(value: _FakeComboDs()),
        Provider<SaborRemoteDataSource>.value(value: _FakeSaborDs()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _addSimpleProductViaDetail(WidgetTester tester) async {
  await tester.tap(find.byIcon(LucideIcons.plus).first);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('add-to-order')));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('carrito vacío no muestra barra Ver carrito', (tester) async {
    await _pumpProductsScreen(
      tester,
      orderRepo: _CapturingOrderRepo(),
      products: [_simpleProduct()],
    );
    expect(find.byKey(const Key('member-cart-bar')), findsNothing);
  });

  testWidgets('con producto en carrito muestra barra y abre sheet', (tester) async {
    await _pumpProductsScreen(
      tester,
      orderRepo: _CapturingOrderRepo(),
      products: [_simpleProduct()],
    );
    await _addSimpleProductViaDetail(tester);

    expect(find.byKey(const Key('member-cart-bar')), findsOneWidget);
    expect(find.text('Ver carrito'), findsOneWidget);
    final bar = find.byKey(const Key('member-cart-bar'));
    expect(find.descendant(of: bar, matching: find.textContaining('1 producto')), findsOneWidget);
    expect(find.descendant(of: bar, matching: find.textContaining('Bs 20,00')), findsOneWidget);

    await tester.tap(find.byKey(const Key('member-cart-bar')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('member-cart-sheet')), findsOneWidget);
    expect(find.text('Tu pedido'), findsOneWidget);
    expect(find.textContaining('Crear pedido'), findsOneWidget);
  });

  testWidgets('crear pedido conserva opciones vacías en payload', (tester) async {
    final repo = _CapturingOrderRepo();
    await _pumpProductsScreen(
      tester,
      orderRepo: repo,
      products: [_simpleProduct()],
      hasConnection: true,
    );
    await _addSimpleProductViaDetail(tester);
    await tester.tap(find.byKey(const Key('member-cart-bar')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('member-cart-general-note')),
      'Entrega rápida',
    );
    await tester.tap(find.text('Para recoger'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('member-create-order-button')));
    await tester.pumpAndSettle();

    expect(repo.lastOrder, isNotNull);
    expect(repo.lastOrder!.tipoConsumo, 'PARA_RECOGER');
    expect(repo.lastOrder!.observaciones, 'Entrega rápida');
    expect(repo.lastOrder!.items.single.options, isEmpty);
    expect(repo.lastOrder!.items.single.productId, '7');
    expect(find.text('Historial pedidos'), findsOneWidget);
    expect(find.byKey(const Key('member-cart-bar')), findsNothing);
    expect(find.text(OrderOfflineMessages.savedPending), findsNothing);
  });

  testWidgets('error al crear conserva carrito y sheet', (tester) async {
    final repo = _CapturingOrderRepo()..throwOnCreate = Exception('Fallo red');
    await _pumpProductsScreen(
      tester,
      orderRepo: repo,
      products: [_simpleProduct()],
      hasConnection: true,
    );
    await _addSimpleProductViaDetail(tester);
    await tester.tap(find.byKey(const Key('member-cart-bar')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('member-create-order-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('member-cart-sheet')), findsOneWidget);
    expect(find.byKey(const Key('member-cart-bar')), findsOneWidget);
    expect(find.text('Historial pedidos'), findsNothing);
  });

  testWidgets('sin conexión no crea pedido ni navega y conserva carrito',
      (tester) async {
    final repo = _CapturingOrderRepo();
    await _pumpProductsScreen(
      tester,
      orderRepo: repo,
      products: [_simpleProduct()],
      hasConnection: false,
    );
    await _addSimpleProductViaDetail(tester);
    await tester.tap(find.byKey(const Key('member-cart-bar')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('member-create-order-button')));
    await tester.pumpAndSettle();

    expect(repo.lastOrder, isNull);
    expect(
      find.text(OrderOfflineMessages.orderRequiresConnection),
      findsOneWidget,
    );
    expect(find.text('Historial pedidos'), findsNothing);
    expect(find.byKey(const Key('member-cart-sheet')), findsOneWidget);
    expect(find.byKey(const Key('member-cart-bar')), findsOneWidget);
  });

  testWidgets('fallo membresía por red no muestra sin membresía activa',
      (tester) async {
    final membresiaDs = _FakeMembresiaDs()
      ..getMembresiasError = NetworkException('NetworkError de conexión');

    final userRepo = FakeUserRepository()
      ..current = User(
        id: '1',
        name: 'Socio',
        email: 's@test.com',
        role: 'SOCIO',
      );
    final userProvider = UserProvider(userRepo);
    userProvider.setUser(userRepo.current!);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: userProvider),
          ChangeNotifierProvider(
            create: (_) => ProductProvider(_FakeProductRepo([_simpleProduct()])),
          ),
          Provider<MembresiaRemoteDataSource>.value(value: membresiaDs),
          Provider<ComboRemoteDataSource>.value(value: _FakeComboDs()),
          Provider<SaborRemoteDataSource>.value(value: _FakeSaborDs()),
        ],
        child: const MaterialApp(
          home: MemberClubProductsScreen(
            clubId: 3,
            clubNombre: 'Club Test',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(OrderOfflineMessages.clubDataRequiresConnection),
      findsOneWidget,
    );
    expect(find.textContaining('membresia activa'), findsNothing);
  });
}
