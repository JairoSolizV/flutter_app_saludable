import '../entities/order_entity.dart';

abstract class OrderRepository {
  Future<List<OrderEntity>> getOrdersByUser(String userId);
  Future<void> createOrder(OrderEntity order);
  Future<void> updateOrderStatus(String orderId, String status);

  /// Pedidos pendientes **solo** del propietario autenticado.
  ///
  /// Nunca devolver pedidos de otro usuario ni huérfanos (user_id null/vacío).
  Future<List<OrderEntity>> getUnsyncedOrdersForUser(String userId);

  /// Cantidad de pendientes sin propietario válido (cuarentena; no sincronizar).
  Future<int> countOrphanUnsyncedOrders();

  Future<void> markAsSynced(String orderId);

  /// Marca varias órdenes como sincronizadas en una transacción (solo tras éxito).
  Future<void> markOrdersAsSynced(List<String> orderIds);

  Future<void> deleteOrder(String orderId);

  /// Elimina órdenes e items en batch (placeholders + chunks).
  Future<void> deleteOrders(List<String> orderIds);
}
