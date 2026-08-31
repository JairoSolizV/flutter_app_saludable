import 'package:flutter/material.dart';

/// Etiquetas de presentación para estados de pedido (valor interno sin cambiar).
class OrderStatusDisplay {
  OrderStatusDisplay._();

  /// Label para vistas del socio. [status] sigue siendo el código backend.
  static String memberLabel(String status) {
    switch (status.toUpperCase()) {
      case 'LOCAL_PENDING':
        return 'Pendiente de envío';
      case 'LOCAL_FAILED':
        return 'No se pudo enviar';
      case 'RECIBIDO':
      case 'PENDING':
        return 'Pendiente';
      case 'PREPARANDO':
      case 'PREPARING':
        return 'Preparando';
      case 'LISTO':
      case 'READY':
        return 'Listo';
      case 'ENTREGADO':
      case 'COMPLETED':
        return 'Entregado';
      case 'CANCELADO':
      case 'CANCELLED':
        return 'Cancelado';
      default:
        return status;
    }
  }

  static Color memberBadgeColor(String status) {
    switch (status.toUpperCase()) {
      case 'LOCAL_PENDING':
        return Colors.amber;
      case 'LOCAL_FAILED':
        return Colors.red;
      case 'RECIBIDO':
      case 'PENDING':
        return Colors.orange;
      case 'PREPARANDO':
      case 'PREPARING':
        return Colors.blue;
      case 'LISTO':
      case 'READY':
        return Colors.green;
      case 'ENTREGADO':
      case 'COMPLETED':
        return Colors.grey;
      case 'CANCELADO':
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
