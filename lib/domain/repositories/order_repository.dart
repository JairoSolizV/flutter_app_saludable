import '../entities/order_entity.dart';

abstract class OrderRepository {
  Future<List<OrderEntity>> getOrdersByUser(String userId);
  Future<void> createOrder(OrderEntity order);
  Future<void> updateOrderStatus(String orderId, String status);
  Future<List<OrderEntity>> getUnsyncedOrders();
  Future<void> markAsSynced(String orderId);
}
