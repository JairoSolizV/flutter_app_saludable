import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:flutter_app_saludable/core/theme/app_theme.dart';
import 'package:flutter_app_saludable/core/utils/bolivian_price.dart';
import 'package:flutter_app_saludable/domain/entities/combo_cart_item.dart';

/// Una línea del carrito = producto suelto o combo configurado.
class MemberCartLineViewModel {
  final String cartKey;
  final String productId;
  final String productName;
  final String optionsSummary;
  final int quantity;
  final double unitPrice;
  final bool priced;
  final bool isCombo;
  final List<String> comboComponentLines;

  const MemberCartLineViewModel({
    required this.cartKey,
    required this.productId,
    required this.productName,
    required this.optionsSummary,
    required this.quantity,
    required this.unitPrice,
    required this.priced,
    this.isCombo = false,
    this.comboComponentLines = const [],
  });

  double get lineTotal => priced ? unitPrice * quantity : 0;
}

/// Totales del carrito SOCIO.
class MemberCartTotals {
  MemberCartTotals._();

  static int totalUnits({
    required Map<String, int> productCart,
    required Iterable<ComboCartItem> comboCart,
  }) {
    final productUnits = productCart.values.fold(0, (sum, q) => sum + q);
    final comboUnits = comboCart.fold(0, (sum, c) => sum + c.quantity);
    return productUnits + comboUnits;
  }

  static double totalAmount({
    required Map<String, int> productCart,
    required double Function(String productId) unitPriceFor,
    required bool Function(String productId) isPriced,
    required Iterable<ComboCartItem> comboCart,
  }) {
    var total = 0.0;
    for (final e in productCart.entries) {
      final pid = _productIdFromCartKey(e.key);
      if (isPriced(pid)) {
        total += unitPriceFor(pid) * e.value;
      }
    }
    for (final combo in comboCart) {
      if (combo.hasConfiguredPrice) {
        total += combo.lineTotal;
      }
    }
    return total;
  }

  static String productCountLabel(int units) =>
      units == 1 ? '1 producto' : '$units productos';

  static String _productIdFromCartKey(String key) {
    if (key.contains('#')) return key.split('#').first;
    if (key.contains('@combo:')) return key.split('@combo:').first;
    return key.split('_').first;
  }
}

/// Barra compacta "Ver carrito" sobre la bottom navigation.
class MemberCartBar extends StatelessWidget {
  final int totalUnits;
  final double totalAmount;
  final VoidCallback onTap;

  const MemberCartBar({
    super.key,
    required this.totalUnits,
    required this.totalAmount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = MemberCartTotals.productCountLabel(totalUnits);
    return Material(
      key: const Key('member-cart-bar'),
      elevation: 8,
      shadowColor: Colors.black26,
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    LucideIcons.shoppingCart,
                    size: 20,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Ver carrito',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '$label · ${BolivianPrice.formatBs(totalAmount)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Contenido del modal de checkout SOCIO.
class MemberCartCheckoutSheet extends StatelessWidget {
  final List<MemberCartLineViewModel> lines;
  final double totalAmount;
  final String tipoConsumo;
  final ValueChanged<String> onTipoConsumoChanged;
  final TextEditingController notaController;
  final void Function(String cartKey, int delta) onQuantityChanged;
  final void Function(String cartKey) onRemoveLine;
  final bool isCreatingOrder;
  final VoidCallback onCreateOrder;
  final ScrollController scrollController;

  const MemberCartCheckoutSheet({
    super.key,
    required this.lines,
    required this.totalAmount,
    required this.tipoConsumo,
    required this.onTipoConsumoChanged,
    required this.notaController,
    required this.onQuantityChanged,
    required this.onRemoveLine,
    required this.isCreatingOrder,
    required this.onCreateOrder,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const Key('member-cart-sheet'),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Tu pedido',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 22),
                  onPressed: isCreatingOrder ? null : () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _consumoChip(
                        'EN_LUGAR',
                        'En lugar',
                        LucideIcons.home,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _consumoChip(
                        'PARA_RECOGER',
                        'Para recoger',
                        LucideIcons.shoppingBag,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('member-cart-general-note'),
                  controller: notaController,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Nota general del pedido (opcional)',
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                    prefixIcon: Icon(
                      LucideIcons.fileText,
                      size: 18,
                      color: Colors.grey[400],
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[200]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[200]!),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                ...lines.map(_lineTile),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      key: const Key('member-cart-total'),
                      BolivianPrice.formatBs(totalAmount),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 88),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  key: const Key('member-create-order-button'),
                  onPressed: isCreatingOrder ? null : onCreateOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: isCreatingOrder
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Crear pedido · ${BolivianPrice.formatBs(totalAmount)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lineTile(MemberCartLineViewModel line) {
    return Padding(
      key: Key('member-cart-line-${line.cartKey}'),
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        line.isCombo ? 'Combo ${line.productName}' : line.productName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (line.priced)
                      Text(
                        BolivianPrice.formatBs(line.unitPrice),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
                if (line.comboComponentLines.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  ...line.comboComponentLines.map(
                    (l) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        l,
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                    ),
                  ),
                ] else if (line.optionsSummary.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    line.optionsSummary,
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  line.priced
                      ? '${line.quantity} × ${BolivianPrice.formatBs(line.unitPrice)}'
                      : '${line.quantity} u.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _qtyBtn(
                    LucideIcons.minus,
                    line.quantity > 0
                        ? () => onQuantityChanged(line.cartKey, -1)
                        : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '${line.quantity}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  _qtyBtn(
                    LucideIcons.plus,
                    () => onQuantityChanged(line.cartKey, 1),
                  ),
                ],
              ),
              IconButton(
                key: Key('member-cart-remove-${line.cartKey}'),
                icon: Icon(LucideIcons.trash2, size: 18, color: Colors.grey[500]),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: isCreatingOrder ? null : () => onRemoveLine(line.cartKey),
              ),
            ],
          ),
          if (line.priced) ...[
            const SizedBox(width: 8),
            Text(
              BolivianPrice.formatBs(line.lineTotal),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback? onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap == null ? Colors.grey[300] : Colors.grey[700],
        ),
      ),
    );
  }

  Widget _consumoChip(String value, String label, IconData icon) {
    final sel = tipoConsumo == value;
    return GestureDetector(
      onTap: isCreatingOrder ? null : () => onTipoConsumoChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: sel ? AppTheme.primaryColor : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: sel ? AppTheme.primaryColor : Colors.grey[200]!,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: sel ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                color: sel ? Colors.white : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
