/// Mapeo de estados de pedido para la vista del anfitrión.
class HostOrderStatusMapping {
  HostOrderStatusMapping._();

  static String mapBackendStatusToUI(String backendStatus) {
    switch (backendStatus.toUpperCase()) {
      case 'RECIBIDO':
      case 'PENDING':
        return 'pending';
      case 'PREPARANDO':
      case 'PREPARING':
        return 'preparing';
      case 'LISTO':
      case 'READY':
        return 'ready';
      case 'ENTREGADO':
      case 'COMPLETED':
        return 'completed';
      case 'CANCELADO':
      case 'CANCELLED':
        return 'cancelled';
      default:
        return 'pending';
    }
  }

  static String mapUIToBackendStatus(String uiStatus) {
    switch (uiStatus) {
      case 'pending':
        return 'RECIBIDO';
      case 'preparing':
        return 'PREPARANDO';
      case 'ready':
        return 'LISTO';
      case 'completed':
        return 'ENTREGADO';
      case 'cancelled':
        return 'CANCELADO';
      case 'all':
        return '';
      default:
        return 'RECIBIDO';
    }
  }

  static bool canHostCancel(String uiStatus) {
    return uiStatus == 'pending' ||
        uiStatus == 'preparing' ||
        uiStatus == 'ready';
  }
}
