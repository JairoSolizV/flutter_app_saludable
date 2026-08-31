import 'package:flutter/foundation.dart';
import 'package:flutter_app_saludable/core/auth/session_state_resetter.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/core/errors/error_mapper.dart';
import 'package:flutter_app_saludable/core/utils/app_logger.dart';
import 'package:flutter_app_saludable/core/orders/order_offline_messages.dart';
import 'package:flutter_app_saludable/core/orders/order_sync_status.dart';
import 'package:flutter_app_saludable/core/orders/order_submit_outcome.dart';
import '../../domain/entities/order_entity.dart';
import '../../domain/repositories/order_repository.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/sync_service.dart';

class OrderProvider extends ChangeNotifier implements SessionScopedState {
  final OrderRepository _repository;
  final ConnectivityService _connectivityService;
  final SyncService _syncService;

  List<OrderEntity> _orders = [];
  bool _isLoading = false;
  String? _error;

  List<OrderEntity> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;

  OrderProvider(this._repository, this._connectivityService, this._syncService);

  @override
  Future<void> clearSessionState() async {
    _orders = [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  Future<void> loadOrders(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _orders = await _repository.getOrdersByUser(userId);
    } catch (e) {
      if (shouldPresentErrorToUser(e)) {
        _error = ErrorMapper.publicMessage(e);
        if (kDebugMode) logDebug('Error loading orders: $_error');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<OrderSubmitOutcome> createOrder(OrderEntity order) async {
    try {
      debugPrint(
        '[DEBUG ORDER] Creando pedido - ID: ${order.id}, clubId: ${order.clubId}, membresiaId: ${order.membresiaId}, items: ${order.items.length}',
      );

      if (!await _connectivityService.checkConnection()) {
        throw NetworkException(OrderOfflineMessages.orderRequiresConnection);
      }

      await _repository.createOrder(order);
      debugPrint('[DEBUG ORDER] Pedido guardado localmente');

      try {
        await _syncService.syncNow();
        debugPrint('[DEBUG ORDER] Sync finalizado');
      } catch (syncError) {
        debugPrint('[DEBUG ORDER] Error sincronizando pedido: $syncError');
        if (kDebugMode) {
          logDebug('Error sincronizando pedido: $syncError');
        }
      }

      await loadOrders(order.userId);

      final userOrders = await _repository.getOrdersByUser(order.userId);
      final matches = userOrders.where((o) => o.id == order.id);
      if (matches.isEmpty) {
        return OrderSubmitOutcome.remoteSynced;
      }
      final created = matches.first;

      switch (created.syncStatus) {
        case OrderSyncStatus.pending:
          return OrderSubmitOutcome.localPending;
        case OrderSyncStatus.failedPermanent:
          return OrderSubmitOutcome.localFailed;
        case OrderSyncStatus.synced:
          return OrderSubmitOutcome.remoteSynced;
      }
    } catch (e) {
      debugPrint('[DEBUG ORDER] Error creando pedido: $e');
      if (kDebugMode) logDebug('Error creating order: $e');
      rethrow;
    }
  }
}
