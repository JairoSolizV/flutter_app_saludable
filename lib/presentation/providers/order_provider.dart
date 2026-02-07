import 'package:flutter/foundation.dart';
import '../../domain/entities/order_entity.dart';
import '../../domain/repositories/order_repository.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/sync_service.dart';

class OrderProvider extends ChangeNotifier {
  final OrderRepository _repository;
  final ConnectivityService _connectivityService;
  final SyncService _syncService;
  
  List<OrderEntity> _orders = [];
  bool _isLoading = false;

  List<OrderEntity> get orders => _orders;
  bool get isLoading => _isLoading;

  OrderProvider(this._repository, this._connectivityService, this._syncService); // Constructor actualizado

  Future<void> loadOrders(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _orders = await _repository.getOrdersByUser(userId);
    } catch (e) {
      if (kDebugMode) print('Error loading orders: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createOrder(OrderEntity order) async {
    try {
      debugPrint('[DEBUG ORDER] Creando pedido - ID: ${order.id}, clubId: ${order.clubId}, membresiaId: ${order.membresiaId}, items: ${order.items.length}');
      
      // Primero guardar localmente
      await _repository.createOrder(order);
      debugPrint('[DEBUG ORDER] Pedido guardado localmente');
      
      // Intentar enviar al backend inmediatamente si hay red
      if (await _connectivityService.checkConnection()) {
        debugPrint('[DEBUG ORDER] Hay conexión, sincronizando pedido...');
        try {
          await _syncService.syncNow();
          debugPrint('[DEBUG ORDER] Pedido sincronizado exitosamente');
        } catch (syncError) {
          debugPrint('[DEBUG ORDER] Error sincronizando pedido: $syncError');
          if (kDebugMode) print('Error sincronizando pedido: $syncError');
          // No rethrow aquí, el pedido ya está guardado localmente
        }
      } else {
        debugPrint('[DEBUG ORDER] No hay conexión, el pedido se sincronizará cuando haya conexión');
      }
      
      // Recargar lista localmente
      await loadOrders(order.userId);
      
    } catch (e) {
      debugPrint('[DEBUG ORDER] Error creando pedido: $e');
      if (kDebugMode) print('Error creating order: $e');
      rethrow;
    }
  }
}
