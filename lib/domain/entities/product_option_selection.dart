import 'product.dart';
import 'order_entity.dart';
import 'order_item_option.dart';

export 'product_option.dart';
export 'order_item_option.dart';

/// Selección estructurada de una opción. Persistible vía [OrderItemOption] (001d).
class ProductOptionSelection {
  final int groupId;
  final String groupName;
  final int groupOrder;
  final int optionId;
  final String optionName;
  final int optionOrder;
  final int quantity;

  const ProductOptionSelection({
    required this.groupId,
    required this.groupName,
    this.groupOrder = 0,
    required this.optionId,
    required this.optionName,
    this.optionOrder = 0,
    required this.quantity,
  });

  bool get hasRequiredIds => groupId > 0 && optionId > 0;

  OrderItemOption toOrderItemOption() => OrderItemOption.fromSelectionFields(
        groupId: groupId,
        groupName: groupName,
        groupOrder: groupOrder,
        optionId: optionId,
        optionName: optionName,
        optionOrder: optionOrder,
        quantity: quantity,
      );

  String get signaturePart => '$groupId:$optionId:$quantity';

  /// Identidad de línea de carrito: no depende de `product.name`.
  /// Dos configs distintas del mismo producto no colisionan.
  static String cartKey(String productId, List<ProductOptionSelection> sels) {
    final parts = [...sels]
      ..sort((a, b) {
        final byGroup = a.groupId.compareTo(b.groupId);
        if (byGroup != 0) return byGroup;
        return a.optionId.compareTo(b.optionId);
      });
    return '$productId#${parts.map((s) => s.signaturePart).join('|')}';
  }

  String get summaryLabel => quantity > 1 ? '$optionName x$quantity' : optionName;

  @override
  bool operator ==(Object other) =>
      other is ProductOptionSelection &&
      other.groupId == groupId &&
      other.optionId == optionId &&
      other.quantity == quantity &&
      other.groupName == groupName &&
      other.optionName == optionName;

  @override
  int get hashCode => Object.hash(groupId, optionId, quantity, groupName, optionName);
}

/// Resultado de MemberProductDetailScreen. Persistido en pedido local (001d).
class ProductCartAddResult {
  final Product product;
  final int quantity;
  final List<ProductOptionSelection> selections;

  const ProductCartAddResult({
    required this.product,
    required this.quantity,
    required this.selections,
  });

  List<OrderItemOption> get orderItemOptions =>
      selections.map((s) => s.toOrderItemOption()).toList();

  /// Identidad estable de línea (productId + selecciones normalizadas).
  String get lineKey => OrderItem.lineKey(
        productId: product.id,
        options: orderItemOptions,
      );

  /// Alias histórico 001c — misma semántica que [lineKey].
  String get cartKey => lineKey;

  double get unitPrice => product.effectivePrice;

  double get subtotal => unitPrice * quantity;

  String get optionsSummary =>
      selections.map((s) => s.summaryLabel).join(', ');
}

enum OptionGroupUiMode { single, multi, counter }

/// Borrador de configuración del socio. No se persiste.
class ProductConfigurationDraft {
  ProductConfigurationDraft(this.product) {
    for (final group in groups) {
      final gid = _idOfGroup(group);
      _qty[gid] = <int, int>{};
      for (final option in group.selectableOptions) {
        _qty[gid]![_idOfOption(option)] = 0;
      }
    }
  }

  final Product product;
  final Map<int, Map<int, int>> _qty = {};

  static const emptyRequiredGroupMessage =
      'No hay opciones disponibles para completar este producto.';

  List<ProductOptionGroup> get groups {
    final source = product.optionGroups;
    if (source == null || source.isEmpty) return const [];
    final list = List<ProductOptionGroup>.from(source)
      ..sort((a, b) {
        final byOrden = a.orden.compareTo(b.orden);
        if (byOrden != 0) return byOrden;
        return (a.id ?? 0).compareTo(b.id ?? 0);
      });
    return list;
  }

  static OptionGroupUiMode modeFor(ProductOptionGroup group) {
    if (group.maxSelections == 1) return OptionGroupUiMode.single;
    if (group.allowRepeat) return OptionGroupUiMode.counter;
    return OptionGroupUiMode.multi;
  }

  static int _idOfGroup(ProductOptionGroup group) => group.id ?? group.orden;

  static int _idOfOption(ProductOption option) => option.id ?? option.orden;

  int quantity(ProductOptionGroup group, ProductOption option) =>
      _qty[_idOfGroup(group)]?[_idOfOption(option)] ?? 0;

  int groupTotal(ProductOptionGroup group) {
    final map = _qty[_idOfGroup(group)];
    if (map == null) return 0;
    return map.values.fold(0, (sum, q) => sum + q);
  }

  void selectSingle(ProductOptionGroup group, ProductOption option) {
    final gid = _idOfGroup(group);
    final map = _qty[gid];
    if (map == null) return;
    for (final key in map.keys.toList()) {
      map[key] = 0;
    }
    map[_idOfOption(option)] = 1;
  }

  void setMultiSelected(
      ProductOptionGroup group, ProductOption option, bool selected) {
    final gid = _idOfGroup(group);
    final oid = _idOfOption(option);
    if (!selected) {
      _qty[gid]?[oid] = 0;
      return;
    }
    if (quantity(group, option) >= 1) return;
    if (!_canIncreaseGroupTotal(group)) return;
    _qty[gid]?[oid] = 1;
  }

  void increment(ProductOptionGroup group, ProductOption option) {
    if (!group.allowRepeat && quantity(group, option) >= 1) return;
    if (!_canIncreaseGroupTotal(group)) return;
    final gid = _idOfGroup(group);
    final oid = _idOfOption(option);
    _qty[gid]?[oid] = quantity(group, option) + 1;
  }

  void decrement(ProductOptionGroup group, ProductOption option) {
    final current = quantity(group, option);
    if (current <= 0) return;
    _qty[_idOfGroup(group)]?[_idOfOption(option)] = current - 1;
  }

  bool _canIncreaseGroupTotal(ProductOptionGroup group) {
    final max = group.maxSelections;
    if (max == null) return true;
    return groupTotal(group) < max;
  }

  bool canIncrement(ProductOptionGroup group, ProductOption option) {
    if (!group.allowRepeat && quantity(group, option) >= 1) return false;
    return _canIncreaseGroupTotal(group);
  }

  String? groupError(ProductOptionGroup group) {
    final active = group.selectableOptions;
    if (group.minSelections > 0 && active.isEmpty) {
      return emptyRequiredGroupMessage;
    }
    final total = groupTotal(group);
    if (total < group.minSelections) {
      return 'Completa ${group.name} (${group.socioChoiceLabel.toLowerCase()})';
    }
    final max = group.maxSelections;
    if (max != null && total > max) {
      return 'Superaste el máximo en ${group.name}';
    }
    if (!group.allowRepeat) {
      final map = _qty[_idOfGroup(group)];
      if (map != null && map.values.any((q) => q > 1)) {
        return 'No se puede repetir una opción en ${group.name}';
      }
    }
    return null;
  }

  bool get isValid => groups.every((g) => groupError(g) == null);

  List<ProductOptionSelection> toSelections() {
    final result = <ProductOptionSelection>[];
    for (final group in groups) {
      for (final option in group.selectableOptions) {
        final q = quantity(group, option);
        if (q <= 0) continue;
        result.add(ProductOptionSelection(
          groupId: _idOfGroup(group),
          groupName: group.name,
          groupOrder: group.orden,
          optionId: _idOfOption(option),
          optionName: option.name,
          optionOrder: option.orden,
          quantity: q,
        ));
      }
    }
    return result;
  }
}
