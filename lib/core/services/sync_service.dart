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
    debugPrint('[DEBUG SYNC] Connection restored. Checking for pending orders...');
    
    final pendingOrders = await _orderRepository.getUnsyncedOrders();
    
    if (pendingOrders.isEmpty) {
      debugPrint('[DEBUG SYNC] No pending orders to sync.');
      return;
    }

    debugPrint('[DEBUG SYNC] Found ${pendingOrders.length} pending orders.');
    for (var order in pendingOrders) {
      debugPrint('[DEBUG SYNC] Pedido pendiente - ID: ${order.id}, clubId: ${order.clubId}, membresiaId: ${order.membresiaId}, items: ${order.items.length}');
    }

    for (var order in pendingOrders) {
      await _syncOrder(order);
    }
  }

  Future<void> _syncOrder(OrderEntity order) async {
    try {
      debugPrint('[DEBUG SYNC] Syncing order ${order.id}...');
      debugPrint('[DEBUG SYNC] Order details - clubId: ${order.clubId}, membresiaId: ${order.membresiaId}, items: ${order.items.length}');
      
      await _orderRemoteDataSource.sendOrder(order, order.items);

      await _orderRepository.markAsSynced(order.id);
      debugPrint('[DEBUG SYNC] Order ${order.id} synced successfully.');
      
    } catch (e, stackTrace) {
      debugPrint('[DEBUG SYNC] Failed to sync order ${order.id}: $e');
      debugPrint('[DEBUG SYNC] Stack trace: $stackTrace');
      if (kDebugMode) print('SyncService: Failed to sync order ${order.id}: $e');
      
      // Si el error es por validación del backend (membresía inactiva, etc.),
      // eliminar el pedido local ya que nunca se podrá sincronizar
      final errorMessage = e.toString().toLowerCase();
      if (errorMessage.contains('no está activa') || 
          errorMessage.contains('no está activo') ||
          errorMessage.contains('no está disponible') ||
          errorMessage.contains('no está configurado')) {
        debugPrint('[DEBUG SYNC] Pedido con error de validación, eliminando de local: ${order.id}');
        try {
          await _orderRepository.deleteOrder(order.id);
          debugPrint('[DEBUG SYNC] Pedido ${order.id} eliminado de local storage');
        } catch (deleteError) {
          debugPrint('[DEBUG SYNC] Error al eliminar pedido: $deleteError');
        }
      }
    }
  }

  // Método público para forzar sync inmediato (ej: al crear pedido si hay red)
  Future<void> syncNow() async {
     if (await _connectivityService.checkConnection()) {
       await _syncPendingOrders();
     }
  }
}
