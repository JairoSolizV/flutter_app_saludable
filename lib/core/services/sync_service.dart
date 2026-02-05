import 'package:flutter/foundation.dart';
import '../../domain/entities/order_entity.dart';
import '../../domain/repositories/order_repository.dart';
import 'connectivity_service.dart';
import '../../data/datasources/remote/order_remote_data_source.dart';

class SyncService {
  final OrderRepository _orderRepository;
  final ConnectivityService _connectivityService;
  final OrderRemoteDataSource _orderRemoteDataSource;
  
  SyncService(this._orderRepository, this._connectivityService, this._orderRemoteDataSource) {
    _connectivityService.connectionStream.listen((hasConnection) {
      if (hasConnection) {
        _syncPendingOrders();
      }
    });
  }

  Future<void> _syncPendingOrders() async {
    print('[DEBUG SYNC] Connection restored. Checking for pending orders...');
    
    final pendingOrders = await _orderRepository.getUnsyncedOrders();
    
    if (pendingOrders.isEmpty) {
      print('[DEBUG SYNC] No pending orders to sync.');
      return;
    }

    print('[DEBUG SYNC] Found ${pendingOrders.length} pending orders.');
    for (var order in pendingOrders) {
      print('[DEBUG SYNC] Pedido pendiente - ID: ${order.id}, clubId: ${order.clubId}, membresiaId: ${order.membresiaId}, items: ${order.items.length}');
    }

    for (var order in pendingOrders) {
      await _syncOrder(order);
    }
  }

  Future<void> _syncOrder(OrderEntity order) async {
    try {
      print('[DEBUG SYNC] Syncing order ${order.id}...');
      print('[DEBUG SYNC] Order details - clubId: ${order.clubId}, membresiaId: ${order.membresiaId}, items: ${order.items.length}');
      
      await _orderRemoteDataSource.sendOrder(order, order.items);

      await _orderRepository.markAsSynced(order.id);
      print('[DEBUG SYNC] Order ${order.id} synced successfully.');
      
    } catch (e, stackTrace) {
      print('[DEBUG SYNC] Failed to sync order ${order.id}: $e');
      print('[DEBUG SYNC] Stack trace: $stackTrace');
      if (kDebugMode) print('SyncService: Failed to sync order ${order.id}: $e');
    }
  }

  // Método público para forzar sync inmediato (ej: al crear pedido si hay red)
  Future<void> syncNow() async {
     if (await _connectivityService.checkConnection()) {
       await _syncPendingOrders();
     }
  }
}
