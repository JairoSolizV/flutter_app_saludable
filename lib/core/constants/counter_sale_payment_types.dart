/// Valores exactos aceptados por backend V21 en POST /pedidos/mostrador.
/// PedidoServiceImpl.TIPOS_PAGO_VALIDOS
class CounterSalePaymentTypes {
  CounterSalePaymentTypes._();

  static const String efectivo = 'EFECTIVO';
  static const String transferencia = 'TRANSFERENCIA';
  static const String qr = 'QR';
  static const String tarjeta = 'TARJETA';
  static const String otro = 'OTRO';

  static const List<String> backendValues = [
    efectivo,
    transferencia,
    qr,
    tarjeta,
    otro,
  ];

  static String label(String backendValue) {
    switch (backendValue) {
      case efectivo:
        return 'Efectivo';
      case transferencia:
        return 'Transferencia';
      case qr:
        return 'QR';
      case tarjeta:
        return 'Tarjeta';
      case otro:
        return 'Otro';
      default:
        return backendValue;
    }
  }
}
