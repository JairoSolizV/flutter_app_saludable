import 'package:flutter_app_saludable/core/utils/host_order_status_mapping.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HostOrderStatusMapping', () {
    test('CANCELADO backend -> cancelled UI', () {
      expect(
        HostOrderStatusMapping.mapBackendStatusToUI('CANCELADO'),
        'cancelled',
      );
    });

    test('cancelled UI -> CANCELADO backend', () {
      expect(
        HostOrderStatusMapping.mapUIToBackendStatus('cancelled'),
        'CANCELADO',
      );
    });

    test('CANCELADO no cae en pending', () {
      expect(
        HostOrderStatusMapping.mapBackendStatusToUI('CANCELADO'),
        isNot('pending'),
      );
    });

    test('canHostCancel solo en estados activos', () {
      expect(HostOrderStatusMapping.canHostCancel('pending'), isTrue);
      expect(HostOrderStatusMapping.canHostCancel('preparing'), isTrue);
      expect(HostOrderStatusMapping.canHostCancel('ready'), isTrue);
      expect(HostOrderStatusMapping.canHostCancel('completed'), isFalse);
      expect(HostOrderStatusMapping.canHostCancel('cancelled'), isFalse);
    });
  });
}
