import 'package:flutter_app_saludable/core/utils/bolivian_price.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatBs usa Bs y coma decimal', () {
    expect(BolivianPrice.formatBs(28), 'Bs 28,00');
    expect(BolivianPrice.formatBs(28.5), 'Bs 28,50');
    expect(BolivianPrice.formatBs(56), 'Bs 56,00');
  });

  test('label con 0 o negativo es no configurado', () {
    expect(BolivianPrice.label(0), 'Precio no configurado');
    expect(BolivianPrice.label(-1), 'Precio no configurado');
    expect(BolivianPrice.isConfigured(0), isFalse);
    expect(BolivianPrice.label(30), 'Bs 30,00');
  });
}
