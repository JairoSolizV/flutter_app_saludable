import 'package:flutter_app_saludable/core/utils/order_status_display.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OrderStatusDisplay.memberLabel', () {
    test('RECIBIDO se muestra como Pendiente', () {
      expect(OrderStatusDisplay.memberLabel('RECIBIDO'), 'Pendiente');
      expect(OrderStatusDisplay.memberLabel('recibido'), 'Pendiente');
    });

    test('demás estados backend', () {
      expect(OrderStatusDisplay.memberLabel('PREPARANDO'), 'Preparando');
      expect(OrderStatusDisplay.memberLabel('LISTO'), 'Listo');
      expect(OrderStatusDisplay.memberLabel('ENTREGADO'), 'Entregado');
      expect(OrderStatusDisplay.memberLabel('CANCELADO'), 'Cancelado');
      expect(OrderStatusDisplay.memberLabel('LOCAL_PENDING'),
          'Pendiente de envío');
    });

    test('alias legacy en inglés', () {
      expect(OrderStatusDisplay.memberLabel('PENDING'), 'Pendiente');
      expect(OrderStatusDisplay.memberLabel('PREPARING'), 'Preparando');
      expect(OrderStatusDisplay.memberLabel('READY'), 'Listo');
      expect(OrderStatusDisplay.memberLabel('COMPLETED'), 'Entregado');
      expect(OrderStatusDisplay.memberLabel('CANCELLED'), 'Cancelado');
    });
  });
}
