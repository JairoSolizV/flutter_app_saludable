import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_app_saludable/core/auth/session_expiration_handler.dart';
import 'package:flutter_app_saludable/core/auth/session_owner.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/core/errors/error_mapper.dart';
import 'package:flutter_app_saludable/core/utils/app_logger.dart';
import '../../domain/entities/order_entity.dart';
import '../../domain/repositories/order_repository.dart';
import 'connectivity_service.dart';
import '../../data/datasources/remote/order_remote_data_source.dart';

class SyncService {
  final OrderRepository _orderRepository;
  final ConnectivityService _connectivityService;
  final OrderRemoteDataSource _orderRemoteDataSource;
  final SessionOwner _sessionOwner;
  final SessionExpirationHandler? _sessionExpirationHandler;

  StreamSubscription<bool>? _connectivitySub;
  bool _syncInProgress = false;
  bool _disposed = false;

  SyncService(
    this._orderRepository,
    this._connectivityService,
    this._orderRemoteDataSource,
    this._sessionOwner, {
    SessionExpirationHandler? sessionExpirationHandler,
  }) : _sessionExpirationHandler = sessionExpirationHandler {
    _connectivitySub =
        _connectivityService.connectionStream.listen((hasConnection) {
      if (hasConnection) {
        _syncPendingOrders();
      }
    });
  }

  Future<void> _syncPendingOrders() async {
    if (_disposed || _syncInProgress) return;
    if (_sessionExpirationHandler?.isInvalidating == true) {
      logDebug('[DEBUG SYNC] Sesión invalidándose; sync omitido');
      return;
    }

    final userId = _sessionOwner.userId;
    if (userId == null) {
      logDebug('[DEBUG SYNC] Sin sesión autenticada; sync omitido');
      return;
    }

    _syncInProgress = true;
    try {
      logDebug(
        '[DEBUG SYNC] Connection check. Sync pedidos del propietario activo…',
      );

      final pendingOrders =
          await _orderRepository.getUnsyncedOrdersForUser(userId);

      if (pendingOrders.isEmpty) {
        logDebug('[DEBUG SYNC] No pending orders for current user.');
        return;
      }

      logDebug(
        '[DEBUG SYNC] Found ${pendingOrders.length} pending orders for user.',
      );

      for (var order in pendingOrders) {
        if (_disposed) break;
        if (_sessionExpirationHandler?.isInvalidating == true) {
          logDebug('[DEBUG SYNC] Expiración durante sync; deteniendo envíos');
          break;
        }
        if (_sessionOwner.userId != userId) {
          logDebug('[DEBUG SYNC] Cambio de sesión durante sync; deteniendo');
          break;
        }
        if (order.userId.trim() != userId) {
          logDebug(
              '[DEBUG SYNC] Pedido ajeno omitido (defensa en profundidad)');
          continue;
        }
        await _syncOrder(order);
      }
    } finally {
      _syncInProgress = false;
    }
  }

  Future<void> _syncOrder(OrderEntity order) async {
    try {
      logDebug('[DEBUG SYNC] Syncing order ${order.id}...');
      await _orderRemoteDataSource.sendOrder(
        order,
        items: order.items,
        combos: order.combos,
      );
      await _orderRepository.markAsSynced(order.id);
      logDebug('[DEBUG SYNC] Order ${order.id} synced successfully.');
    } catch (e) {
      if (e is SessionExpiredException ||
          (e is AppException && e.handledGlobally)) {
        logDebug('[DEBUG SYNC] Sesión expirada; no marcar pedido como sync');
        return;
      }

      final publicMsg = ErrorMapper.publicMessage(e);
      if (kDebugMode) {
        logDebug('[DEBUG SYNC] Failed to sync order ${order.id}: $publicMsg');
      }

      // 400 (p. ej. opciones inválidas tras cambio de catálogo): mantener pending.
      if (e is ValidationException) {
        logDebug(
          '[DEBUG SYNC] Validación rechazada; pedido ${order.id} sigue pendiente',
        );
        return;
      }

      final errorMessage = publicMsg.toLowerCase();
      if (errorMessage.contains('membres') &&
          (errorMessage.contains('no está activa') ||
              errorMessage.contains('no activa'))) {
        logDebug(
          '[DEBUG SYNC] Pedido con membresía inválida, eliminando: ${order.id}',
        );
        try {
          await _orderRepository.deleteOrder(order.id);
        } catch (_) {
          logDebug('[DEBUG SYNC] Error al eliminar pedido local');
        }
      }
    }
  }

  Future<void> syncNow() async {
    if (_disposed) return;
    if (await _connectivityService.checkConnection()) {
      await _syncPendingOrders();
    }
  }

  /// Cancela la suscripción a conectividad. Idempotente.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }
}
