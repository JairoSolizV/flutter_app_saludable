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
      await _repository.createOrder(order);
      // Recargar lista localmente
      await loadOrders(order.userId);
      
      // Intentar sincronizar inmediatamente si hay red
      if (await _connectivityService.checkConnection()) { 
        _syncService.syncNow(); 
      }
      
    } catch (e) {
      if (kDebugMode) print('Error creating order: $e');
      rethrow;
    }
  }
}
