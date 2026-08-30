import 'package:flutter_app_saludable/core/utils/order_item_options_display.dart';
import 'package:flutter_app_saludable/domain/entities/order_item_option.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('groupLines ordena y formatea repeat', () {
    const options = [
      OrderItemOption(
        groupId: 3,
        groupName: 'Sabores',
        groupOrder: 0,
        optionId: 6,
        optionName: 'Frutilla',
        optionOrder: 0,
        quantity: 2,
      ),
      OrderItemOption(
        groupId: 4,
        groupName: 'Consistencia',
        groupOrder: 1,
        optionId: 9,
        optionName: 'Cremoso',
        optionOrder: 0,
        quantity: 1,
      ),
    ];
    final lines = OrderItemOptionsDisplay.groupLines(options);
    expect(lines, ['Sabores: Frutilla ×2', 'Consistencia: Cremoso']);
  });

  test('parseFromHistoryItem tolera legacy vacío', () {
    expect(
      OrderItemOptionsDisplay.parseFromHistoryItem({'productoNombre': 'X'}),
      isEmpty,
    );
    expect(
      OrderItemOptionsDisplay.parseFromHistoryItem({'opciones': []}),
      isEmpty,
    );
  });
}
