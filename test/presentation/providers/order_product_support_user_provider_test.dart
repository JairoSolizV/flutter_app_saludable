import 'package:flutter_app_saludable/core/auth/session_owner.dart';
import 'package:flutter_app_saludable/core/database/database_helper.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/core/pagination/paged_result.dart';
import 'package:flutter_app_saludable/core/services/connectivity_service.dart';
import 'package:flutter_app_saludable/core/services/sync_service.dart';
import 'package:flutter_app_saludable/data/datasources/remote/order_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/support_remote_data_source.dart';
import 'package:flutter_app_saludable/data/repositories/local_user_repository.dart';
import 'package:flutter_app_saludable/domain/entities/order_entity.dart';
import 'package:flutter_app_saludable/domain/entities/product.dart';
import 'package:flutter_app_saludable/domain/entities/support_ticket.dart';
import 'package:flutter_app_saludable/domain/entities/user.dart';
import 'package:flutter_app_saludable/domain/repositories/order_repository.dart';
import 'package:flutter_app_saludable/domain/repositories/product_repository.dart';
import 'package:flutter_app_saludable/presentation/providers/order_provider.dart';
import 'package:flutter_app_saludable/presentation/providers/product_provider.dart';
import 'package:flutter_app_saludable/presentation/providers/support_provider.dart';
import 'package:flutter_app_saludable/presentation/providers/user_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/auth/fake_user_repository.dart';
import '../../helpers/isolated_test_database.dart';

/// -------------------- Fakes: OrderRepository / OrderRemoteDataSource --------------------

class _FakeOrderRepository implements OrderRepository {
  final List<OrderEntity> stored = [];
  Object? loadError;

  @override
  Future<void> createOrder(OrderEntity order) async {
    stored.add(order);
  }

  @override
  Future<List<OrderEntity>> getOrdersByUser(String userId) async {
    if (loadError != null) throw loadError!;
    return stored.where((o) => o.userId == userId).toList();
  }

  @override
  Future<List<OrderEntity>> getUnsyncedOrdersForUser(String userId) async =>
      stored.where((o) => o.userId == userId && !o.isSynced).toList();

  @override
  Future<int> countOrphanUnsyncedOrders() async => 0;

  @override
  Future<void> markAsSynced(String orderId) async {
    final idx = stored.indexWhere((o) => o.id == orderId);
    if (idx == -1) return;
    final old = stored[idx];
    stored[idx] = OrderEntity(
      id: old.id,
      userId: old.userId,
      clubId: old.clubId,
      membresiaId: old.membresiaId,
      tipoConsumo: old.tipoConsumo,
      observaciones: old.observaciones,
      status: old.status,
      createdAt: old.createdAt,
      isSynced: true,
      tiempoEstimadoMinutos: old.tiempoEstimadoMinutos,
      items: old.items,
    );
  }

  @override
  Future<void> markOrdersAsSynced(List<String> orderIds) async {
    for (final id in orderIds) {
      await markAsSynced(id);
    }
  }

  @override
  Future<void> updateOrderStatus(String orderId, String status) async {
    final idx = stored.indexWhere((o) => o.id == orderId);
    if (idx == -1) return;
    final old = stored[idx];
    stored[idx] = OrderEntity(
      id: old.id,
      userId: old.userId,
      clubId: old.clubId,
      membresiaId: old.membresiaId,
      tipoConsumo: old.tipoConsumo,
      observaciones: old.observaciones,
      status: status,
      createdAt: old.createdAt,
      isSynced: old.isSynced,
      tiempoEstimadoMinutos: old.tiempoEstimadoMinutos,
      items: old.items,
    );
  }

  @override
  Future<void> deleteOrder(String orderId) async {
    stored.removeWhere((o) => o.id == orderId);
  }

  @override
  Future<void> deleteOrders(List<String> orderIds) async {
    stored.removeWhere((o) => orderIds.contains(o.id));
  }
}

class _FakeOrderRemoteDataSource implements OrderRemoteDataSource {
  final List<String> sentOrderIds = [];
  bool shouldFail = false;

  @override
  Future<void> sendOrder(OrderEntity order, List<OrderItem> items) async {
    if (shouldFail) throw Exception('fallo de red simulado');
    sentOrderIds.add(order.id);
  }

  @override
  Future<void> createCounterSale({
    required int clubId,
    String? socioCodigo,
    String? tipoConsumo,
    String? observaciones,
    required List<Map<String, dynamic>> items,
  }) async =>
      throw UnimplementedError();

  @override
  Future<List<Map<String, dynamic>>> getOrdersByClub(int clubId) async => [];

  @override
  Future<List<Map<String, dynamic>>> getOrdersBySocio(int membresiaId) async =>
      [];

  @override
  Future<PagedResult<Map<String, dynamic>>> getOrdersByClubPage(
    int clubId, {
    int page = 0,
    int size = 20,
    String? estado,
    String? desde,
    String? hasta,
  }) async =>
      PagedResult<Map<String, dynamic>>.empty(page: page, size: size);

  @override
  Future<PagedResult<Map<String, dynamic>>> getOrdersBySocioPage(
    int membresiaId, {
    int page = 0,
    int size = 20,
    String? estado,
    String? desde,
    String? hasta,
  }) async =>
      PagedResult<Map<String, dynamic>>.empty(page: page, size: size);

  @override
  Future<void> updateOrderStatus(int pedidoId, String newStatus,
          {int? estimatedTime}) async =>
      throw UnimplementedError();

  @override
  Future<List<Map<String, dynamic>>> getAllOrders() async => [];
}

/// -------------------- Fake: ProductRepository --------------------

class _FakeProductRepository implements ProductRepository {
  List<Product> products = [];
  List<Product> availableProducts = [];
  Object? loadError;
  bool toggleShouldFail = false;
  int toggleCalls = 0;
  List<Product>? productsAfterReload;

  @override
  Future<List<Product>> getProducts({
    required int hubId,
    required int clubId,
  }) async {
    if (loadError != null) throw loadError!;
    return productsAfterReload ?? products;
  }

  @override
  Future<List<Product>> getAvailableProductsByClub(int clubId) async {
    if (loadError != null) throw loadError!;
    return availableProducts;
  }

  @override
  Future<Product?> getProductById(String id) async =>
      throw UnimplementedError();

  @override
  Future<void> createProduct(Product product, int clubId) async =>
      throw UnimplementedError();

  @override
  Future<void> updateProduct(Product product) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteProduct(String id) async => throw UnimplementedError();

  @override
  Future<void> toggleProductAvailability(int clubId, String productId) async {
    toggleCalls++;
    if (toggleShouldFail) {
      throw ServerException('No se pudo cambiar disponibilidad');
    }
  }
}

/// -------------------- Fake: SupportRemoteDataSource --------------------

class _FakeSupportRemoteDataSource implements SupportRemoteDataSource {
  List<SupportTicket> ticketsByUser = [];
  int createTicketCalls = 0;
  Object? createError;
  Object? getTicketsError;
  String? lastAsunto;

  @override
  Future<void> createTicket({
    required String tipoSolicitud,
    required String asunto,
    required String mensaje,
  }) async {
    createTicketCalls++;
    lastAsunto = asunto;
    if (createError != null) throw createError!;
  }

  @override
  Future<List<SupportTicket>> getTicketsByUser(int userId) async {
    if (getTicketsError != null) throw getTicketsError!;
    return ticketsByUser;
  }
}

SupportTicket _ticket({
  required int id,
  required int userId,
  DateTime? fecha,
}) {
  return SupportTicket(
    id: id,
    userId: userId,
    tipoSolicitud: 'Consulta',
    asunto: 'Asunto $id',
    mensaje: 'Mensaje $id',
    estado: 'ABIERTO',
    fechaCreacion: fecha ?? DateTime(2024, 1, id),
  );
}

OrderEntity _order({
  required String id,
  required String userId,
  bool synced = false,
}) {
  return OrderEntity(
    id: id,
    userId: userId,
    clubId: 1,
    membresiaId: 1,
    status: 'pending',
    createdAt: DateTime(2024, 1, 1),
    isSynced: synced,
    items: [OrderItem(orderId: id, productId: 'p1', quantity: 1)],
  );
}

void main() {
  group('OrderProvider', () {
    late _FakeOrderRepository repo;
    late _FakeOrderRemoteDataSource remote;
    late SessionOwner sessionOwner;
    late bool online;
    late ConnectivityService connectivity;
    late SyncService syncService;
    late OrderProvider provider;

    setUp(() {
      repo = _FakeOrderRepository();
      remote = _FakeOrderRemoteDataSource();
      sessionOwner = SessionOwner();
      online = true;
      connectivity =
          ConnectivityService.forTest(checkConnection: () async => online);
      syncService = SyncService(repo, connectivity, remote, sessionOwner);
      provider = OrderProvider(repo, connectivity, syncService);
    });

    tearDown(() {
      syncService.dispose();
      connectivity.dispose();
    });

    test('loadOrders ok carga pedidos del usuario', async_(() async {
      repo.stored.add(_order(id: 'o1', userId: 'u1'));
      repo.stored.add(_order(id: 'o2', userId: 'otro'));

      await provider.loadOrders('u1');

      expect(provider.orders.map((o) => o.id), ['o1']);
      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
    }));

    test('loadOrders error setea mensaje de error', async_(() async {
      repo.loadError = ServerException('Error de carga');

      await provider.loadOrders('u1');

      expect(provider.orders, isEmpty);
      expect(provider.error, isNotNull);
      expect(provider.isLoading, isFalse);
    }));

    test('createOrder online guarda localmente y sincroniza', async_(() async {
      online = true;
      sessionOwner.setUserId('u1');
      final order = _order(id: 'o1', userId: 'u1');

      await provider.createOrder(order);

      expect(repo.stored.any((o) => o.id == 'o1'), isTrue);
      expect(remote.sentOrderIds, contains('o1'));
      expect(provider.orders.any((o) => o.id == 'o1'), isTrue);
    }));

    test('createOrder offline no intenta sincronizar', async_(() async {
      online = false;
      sessionOwner.setUserId('u1');
      final order = _order(id: 'o2', userId: 'u1');

      await provider.createOrder(order);

      expect(repo.stored.any((o) => o.id == 'o2'), isTrue);
      expect(remote.sentOrderIds, isEmpty);
    }));

    test('clearSessionState limpia pedidos, loading y error', async_(() async {
      repo.stored.add(_order(id: 'o1', userId: 'u1'));
      await provider.loadOrders('u1');
      expect(provider.orders, isNotEmpty);

      await provider.clearSessionState();

      expect(provider.orders, isEmpty);
      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
    }));
  });

  group('ProductProvider', () {
    late _FakeProductRepository repo;
    late ProductProvider provider;

    setUp(() {
      repo = _FakeProductRepository();
      provider = ProductProvider(repo);
    });

    test('loadProducts ok llena la lista de productos', async_(() async {
      repo.products = [
        Product(id: '1', name: 'Batido', description: ''),
        Product(id: '2', name: 'Te', description: ''),
      ];

      await provider.loadProducts(hubId: 1, clubId: 1);

      expect(provider.products, hasLength(2));
      expect(provider.error, isNull);
      expect(provider.isLoading, isFalse);
    }));

    test('loadProducts error setea mensaje de error', async_(() async {
      repo.loadError = ServerException('boom');

      await provider.loadProducts(hubId: 1, clubId: 1);

      expect(provider.products, isEmpty);
      expect(provider.error, isNotNull);
    }));

    test('loadAvailableProducts filtra solo activos y disponibles',
        async_(() async {
      repo.availableProducts = [
        Product(
            id: '1', name: 'A', description: '', active: true, available: true),
        Product(
            id: '2',
            name: 'B',
            description: '',
            active: true,
            available: false),
        Product(
            id: '3',
            name: 'C',
            description: '',
            active: false,
            available: true),
      ];

      await provider.loadAvailableProducts(1);

      expect(provider.products.map((p) => p.id), ['1']);
    }));

    test('toggleAvailability aplica optimista y recarga en éxito',
        async_(() async {
      repo.products = [
        Product(
            id: '1',
            name: 'A',
            description: '',
            active: true,
            available: false),
      ];
      await provider.loadProducts(hubId: 1, clubId: 1);

      repo.productsAfterReload = [
        Product(
            id: '1', name: 'A', description: '', active: true, available: true),
      ];

      await provider.toggleAvailability(1, '1', 1);

      expect(repo.toggleCalls, 1);
      expect(provider.products.single.available, isTrue);
    }));

    test('toggleAvailability hace rollback si el repositorio falla',
        async_(() async {
      final original = Product(
        id: '1',
        name: 'A',
        description: '',
        active: true,
        available: false,
      );
      repo.products = [original];
      await provider.loadProducts(hubId: 1, clubId: 1);
      repo.toggleShouldFail = true;

      await expectLater(
        () => provider.toggleAvailability(1, '1', 1),
        throwsA(isA<ServerException>()),
      );

      expect(provider.products.single.available, isFalse);
      expect(provider.error, isNotNull);
    }));

    test('clearSessionState limpia productos y error', async_(() async {
      repo.products = [Product(id: '1', name: 'A', description: '')];
      await provider.loadProducts(hubId: 1, clubId: 1);

      await provider.clearSessionState();

      expect(provider.products, isEmpty);
      expect(provider.error, isNull);
      expect(provider.isLoading, isFalse);
    }));
  });

  group('SupportProvider', () {
    late _FakeSupportRemoteDataSource remote;
    late LocalUserRepository localUsers;
    late SupportProvider provider;
    late DatabaseHelper dbHelper;

    setUpAll(() async {
      dbHelper = await openIsolatedTestDatabase();
    });

    tearDownAll(() async {
      await closeIsolatedTestDatabase();
    });

    setUp(() async {
      remote = _FakeSupportRemoteDataSource();
      localUsers = LocalUserRepository(dbHelper);
      // Asegura aislamiento entre tests: limpia perfiles previos.
      final db = await dbHelper.database;
      await db.delete('users');
      provider = SupportProvider(remote, localUsers);
    });

    tearDown(() async {
      final db = await dbHelper.database;
      await db.delete('users');
    });

    test('fetchMyTickets sin usuario local setea error y no llama al remoto',
        async_(() async {
      await provider.fetchMyTickets();

      expect(provider.error, isNotNull);
      expect(provider.tickets, isEmpty);
    }));

    test('fetchMyTickets con usuario local carga y ordena tickets',
        async_(() async {
      await localUsers.saveUser(
        User(id: '9', name: 'Ana', email: 'ana@test.com', role: 'member'),
      );
      remote.ticketsByUser = [
        _ticket(id: 1, userId: 9, fecha: DateTime(2024, 1, 1)),
        _ticket(id: 2, userId: 9, fecha: DateTime(2024, 3, 1)),
      ];

      await provider.fetchMyTickets();

      expect(provider.error, isNull);
      expect(provider.tickets.map((t) => t.id), [2, 1]); // más reciente primero
    }));

    test('createTicket exitoso refresca la lista de tickets', async_(() async {
      await localUsers.saveUser(
        User(id: '9', name: 'Ana', email: 'ana@test.com', role: 'member'),
      );
      remote.ticketsByUser = [_ticket(id: 5, userId: 9)];

      final ok = await provider.createTicket('Queja', 'Asunto', 'Mensaje');

      expect(ok, isTrue);
      expect(remote.createTicketCalls, 1);
      expect(remote.lastAsunto, 'Asunto');
      expect(provider.tickets, hasLength(1));
      expect(provider.isLoading, isFalse);
    }));

    test('createTicket con error del backend retorna false y setea error',
        async_(() async {
      remote.createError = ServerException('No se pudo crear el ticket');

      final ok = await provider.createTicket('Queja', 'Asunto', 'Mensaje');

      expect(ok, isFalse);
      expect(provider.error, isNotNull);
      expect(provider.isLoading, isFalse);
    }));
  });

  group('UserProvider', () {
    late FakeUserRepository repo;
    late UserProvider provider;

    setUp(() {
      repo = FakeUserRepository();
      provider = UserProvider(repo);
    });

    test('loadUser carga el usuario desde el repositorio', async_(() async {
      repo.current =
          User(id: '1', name: 'Ana', email: 'a@b.com', role: 'member');

      await provider.loadUser('1');

      expect(provider.currentUser?.name, 'Ana');
      expect(provider.isLoading, isFalse);
    }));

    test('setUser actualiza el usuario actual directamente', () {
      final user = User(id: '2', name: 'Beto', email: 'b@b.com', role: 'host');
      provider.setUser(user);
      expect(provider.currentUser, user);
    });

    test('updateUserProfile actualiza campos y persiste', async_(() async {
      provider.setUser(
          User(id: '1', name: 'Ana', email: 'a@b.com', role: 'member'));

      await provider.updateUserProfile(name: 'Ana María', phone: '71234567');

      expect(provider.currentUser?.name, 'Ana María');
      expect(provider.currentUser?.phone, '71234567');
      expect(repo.current?.name, 'Ana María');
    }));

    test('updateUserProfile sin usuario actual no hace nada', async_(() async {
      await provider.updateUserProfile(name: 'X');
      expect(provider.currentUser, isNull);
    }));

    test('logout limpia el usuario actual', () {
      provider.setUser(
          User(id: '1', name: 'Ana', email: 'a@b.com', role: 'member'));
      provider.logout();
      expect(provider.currentUser, isNull);
    });

    test('clearSessionState limpia usuario y loading', async_(() async {
      provider.setUser(
          User(id: '1', name: 'Ana', email: 'a@b.com', role: 'member'));

      await provider.clearSessionState();

      expect(provider.currentUser, isNull);
      expect(provider.isLoading, isFalse);
    }));
  });
}

/// Helper para pasar closures async directamente como segundo argumento
/// de [test] sin repetir el tipo en cada caso.
dynamic async_(Future<void> Function() body) => body;
