import '../entities/order_entity.dart';

abstract class OrderRepository {
  Future<List<OrderEntity>> getOrdersByUser(String userId);
  Future<void> createOrder(OrderEntity order);
  Future<void> updateOrderStatus(String orderId, String status);

  /// Cola automática de sync: solo PENDING del propietario autenticado.
  Future<List<OrderEntity>> getUnsyncedOrdersForUser(String userId);

  /// Pedidos locales no enviados al servidor (PENDING + FAILED_PERMANENT) para UI.
  Future<List<OrderEntity>> getLocalUnsentOrdersForUser(String userId);

  /// Cantidad de pendientes sin propietario válido (cuarentena; no sincronizar).
  Future<int> countOrphanUnsyncedOrders();

  Future<void> markAsSynced(String orderId);

  /// Marca varias órdenes como sincronizadas en una transacción (solo tras éxito).
  Future<void> markOrdersAsSynced(List<String> orderIds);

  /// Rechazo permanente: conserva el pedido visible, sin auto-sync.
  Future<void> markSyncFailed(
    String orderId, {
    String? errorCode,
    String? errorMessage,
  });

  Future<void> deleteOrder(String orderId);

  /// Elimina órdenes e items en batch (placeholders + chunks).
  Future<void> deleteOrders(List<String> orderIds);
}
