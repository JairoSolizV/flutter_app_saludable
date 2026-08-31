/// Estado de sincronización local (independiente de [OrderEntity.status] comercial).
enum OrderSyncStatus {
  pending('PENDING'),
  failedPermanent('FAILED_PERMANENT'),
  synced('SYNCED');

  const OrderSyncStatus(this.storageValue);

  final String storageValue;

  static OrderSyncStatus fromStorage(Object? raw, {required bool isSynced}) {
    if (raw == null || raw.toString().trim().isEmpty) {
      return isSynced ? synced : pending;
    }
    final normalized = raw.toString().trim().toUpperCase();
    for (final value in OrderSyncStatus.values) {
      if (value.storageValue == normalized) return value;
    }
    return isSynced ? synced : pending;
  }

  bool get isPending => this == pending;

  bool get isFailedPermanent => this == failedPermanent;

  bool get isSynced => this == synced;
}
