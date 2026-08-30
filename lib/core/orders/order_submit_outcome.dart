/// Resultado de crear un pedido: guardado local vs confirmado en backend.
enum OrderSubmitOutcome {
  /// Insert SQLite OK; sigue en cola de sync (`is_synced = 0`).
  localPending,

  /// Sync completó y el pedido ya no está pendiente localmente.
  remoteSynced,
}
