import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';
import 'package:flutter_app_saludable/core/utils/bolivian_price.dart';
import 'package:flutter_app_saludable/domain/entities/product.dart';
import 'package:flutter_app_saludable/domain/entities/product_option_selection.dart';
import 'package:flutter_app_saludable/presentation/widgets/product_image.dart';
import 'package:flutter_app_saludable/presentation/widgets/product_option_groups_picker.dart';

/// Detalle SOCIO: información, precio efectivo, puntos, opciones y cantidad.
/// No llama /sabores. No persiste selecciones (001d).
class MemberProductDetailScreen extends StatefulWidget {
  final Product product;

  const MemberProductDetailScreen({super.key, required this.product});

  @override
  State<MemberProductDetailScreen> createState() =>
      _MemberProductDetailScreenState();
}

class _MemberProductDetailScreenState extends State<MemberProductDetailScreen> {
  late final ProductConfigurationDraft _draft;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _draft = ProductConfigurationDraft(widget.product);
  }

  Product get _product => widget.product;

  bool get _canAdd =>
      _product.hasConfiguredSalePrice && _draft.isValid && _quantity >= 1;

  double get _total => _product.effectivePrice * _quantity;

  void _addToOrder() {
    if (!_canAdd) return;
    Navigator.of(context).pop(ProductCartAddResult(
      product: _product,
      quantity: _quantity,
      selections: _draft.toSelections(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final priced = _product.hasConfiguredSalePrice;
    return Scaffold(
      key: const Key('member-product-detail'),
      appBar: AppBar(
        title: const Text('Producto'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                if (_product.imageUrl.isNotEmpty)
                  Center(
                    child: ProductImage(
                      imageUrl: _product.imageUrl,
                      width: 160,
                      height: 160,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                if (_product.imageUrl.isNotEmpty) const SizedBox(height: 16),
                Text(
                  _product.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  BolivianPrice.label(_product.effectivePrice),
                  key: const Key('detail-effective-price'),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: priced ? AppTheme.primaryColor : Colors.orange.shade800,
                  ),
                ),
                if (_product.puntosValor > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${_product.puntosValor} puntos',
                    key: const Key('detail-points'),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (!priced) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Este producto todavía no tiene un precio de venta.',
                    style: TextStyle(fontSize: 13, color: Colors.orange.shade800),
                  ),
                ],
                if (_product.description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    _product.description,
                    style: TextStyle(fontSize: 15, color: Colors.grey[800]),
                  ),
                ],
                if (_draft.groups.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'PERSONALIZA TU PRODUCTO',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ProductOptionGroupsPicker(
                    draft: _draft,
                    onChanged: () => setState(() {}),
                  ),
                ],
                const SizedBox(height: 8),
                const Text(
                  'Cantidad',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    QtyRoundButton(
                      key: const Key('product-qty-minus'),
                      icon: LucideIcons.minus,
                      onPressed: _quantity > 1
                          ? () => setState(() => _quantity--)
                          : null,
                    ),
                    SizedBox(
                      width: 44,
                      child: Text(
                        '$_quantity',
                        key: const Key('product-qty-value'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    QtyRoundButton(
                      key: const Key('product-qty-plus'),
                      icon: LucideIcons.plus,
                      onPressed: () => setState(() => _quantity++),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Total',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  priced ? BolivianPrice.formatBs(_total) : BolivianPrice.label(0),
                  key: const Key('detail-total'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  key: const Key('add-to-order'),
                  onPressed: _canAdd ? _addToOrder : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Agregar al pedido',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
