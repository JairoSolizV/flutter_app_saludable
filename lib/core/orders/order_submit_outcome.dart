/// Resultado de crear un pedido: guardado local vs confirmado en backend.
enum OrderSubmitOutcome {
  /// Insert SQLite OK; sigue en cola de sync (`sync_status = PENDING`).
  localPending,

  /// Sync completó y el pedido ya no está pendiente localmente.
  remoteSynced,

  /// Rechazo permanente del backend; visible en Mis Pedidos, sin auto-sync.
  localFailed,
}
