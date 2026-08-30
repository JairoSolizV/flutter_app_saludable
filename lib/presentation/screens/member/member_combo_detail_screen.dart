import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';
import 'package:flutter_app_saludable/core/utils/bolivian_price.dart';
import 'package:flutter_app_saludable/domain/entities/combo.dart';
import 'package:flutter_app_saludable/domain/entities/combo_cart_item.dart';
import 'package:flutter_app_saludable/domain/entities/product.dart';
import 'package:flutter_app_saludable/domain/entities/product_option_selection.dart';
import 'package:flutter_app_saludable/presentation/widgets/product_option_groups_picker.dart';

/// Detalle/configuración de combo SOCIO antes de agregar al carrito.
class MemberComboDetailScreen extends StatefulWidget {
  final Combo combo;
  final Map<String, Product> productsById;

  const MemberComboDetailScreen({
    super.key,
    required this.combo,
    required this.productsById,
  });

  @override
  State<MemberComboDetailScreen> createState() =>
      _MemberComboDetailScreenState();
}

class _ComponentDraft {
  final ComboItem item;
  final Product? product;
  ProductConfigurationDraft? draft;

  _ComponentDraft({required this.item, required this.product}) {
    if (product != null) {
      draft = ProductConfigurationDraft(product!);
    }
  }

  bool get isValid {
    if (product == null) return false;
    if (!product!.hasConfigurableOptionGroups) return true;
    return draft?.isValid ?? false;
  }

  List<ProductOptionSelection> get selections =>
      draft?.toSelections() ?? const [];
}

class _MemberComboDetailScreenState extends State<MemberComboDetailScreen> {
  late final List<_ComponentDraft> _components;
  int _quantity = 1;

  Combo get _combo => widget.combo;

  bool get _canPurchase => _combo.hasConfiguredPrice;

  bool get _canAdd =>
      _canPurchase &&
      _components.every((c) => c.isValid) &&
      _quantity >= 1;

  double get _lineTotal => _combo.price * _quantity;

  @override
  void initState() {
    super.initState();
    _components = _combo.items
        .map(
          (item) => _ComponentDraft(
            item: item,
            product: widget.productsById[item.productoId.toString()],
          ),
        )
        .toList();
  }

  void _addToCart() {
    if (!_canAdd) return;
    final cartItem = ComboCartItem(
      comboId: _combo.id!,
      comboName: _combo.nombre,
      price: _combo.price,
      points: _combo.puntosValor,
      quantity: _quantity,
      components: _components
          .map(
            (c) => ComboCartComponent(
              productId: c.item.productoId,
              productName: c.product?.name ?? c.item.productoNombre,
              selections: c.selections,
            ),
          )
          .toList(),
    );
    Navigator.of(context).pop(cartItem);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('member-combo-detail'),
      appBar: AppBar(
        title: const Text('Combo'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Text(
                  _combo.nombre,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  BolivianPrice.label(_combo.price),
                  key: const Key('combo-detail-price'),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _canPurchase
                        ? AppTheme.primaryColor
                        : Colors.orange.shade800,
                  ),
                ),
                if (!_canPurchase)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Precio no configurado',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ),
                if (_combo.puntosValor > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${_combo.puntosValor} puntos',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (_combo.descripcion != null &&
                    _combo.descripcion!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    _combo.descripcion!,
                    style: TextStyle(fontSize: 15, color: Colors.grey[800]),
                  ),
                ],
                const SizedBox(height: 24),
                const Text(
                  'INCLUYE',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 12),
                ..._components.map(_componentSection),
                const SizedBox(height: 16),
                const Text(
                  'Cantidad del combo',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _qtyBtn(
                      LucideIcons.minus,
                      _quantity > 1 ? () => setState(() => _quantity--) : null,
                    ),
                    SizedBox(
                      width: 44,
                      child: Text(
                        '$_quantity',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _qtyBtn(
                      LucideIcons.plus,
                      () => setState(() => _quantity++),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
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
                      key: const Key('combo-detail-total'),
                      BolivianPrice.formatBs(_lineTotal),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
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
                  key: const Key('combo-add-to-cart'),
                  onPressed: _canAdd ? _addToCart : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Agregar al carrito',
                    style: TextStyle(
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

  Widget _componentSection(_ComponentDraft component) {
    final product = component.product;
    final title = product?.name ?? component.item.productoNombre;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (product == null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Producto no disponible en el menú',
                style: TextStyle(fontSize: 13, color: Colors.orange.shade800),
              ),
            )
          else if (component.draft != null &&
              component.draft!.groups.isNotEmpty) ...[
            const SizedBox(height: 8),
            ProductOptionGroupsPicker(
              draft: component.draft!,
              onChanged: () => setState(() {}),
            ),
          ] else ...[
            const SizedBox(height: 4),
            Text(
              'Sin opciones configurables',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
          const Divider(height: 28),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback? onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 18,
          color: onTap == null ? Colors.grey[300] : Colors.grey[700],
        ),
      ),
    );
  }
}
