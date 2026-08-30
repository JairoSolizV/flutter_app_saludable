import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';
import 'package:flutter_app_saludable/core/utils/bolivian_price.dart';
import 'package:flutter_app_saludable/domain/entities/product.dart';
import 'package:flutter_app_saludable/domain/entities/product_option_selection.dart';
import 'package:flutter_app_saludable/presentation/widgets/product_option_groups_picker.dart';

class CounterSaleProductAddResult {
  final Product product;
  final List<ProductOptionSelection> selections;
  final int quantity;

  const CounterSaleProductAddResult({
    required this.product,
    required this.selections,
    required this.quantity,
  });
}

Future<CounterSaleProductAddResult?> showHostCounterProductConfigure({
  required BuildContext context,
  required Product product,
}) {
  return showModalBottomSheet<CounterSaleProductAddResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => HostCounterProductConfigureSheet(product: product),
  );
}

class HostCounterProductConfigureSheet extends StatefulWidget {
  final Product product;

  const HostCounterProductConfigureSheet({super.key, required this.product});

  @override
  State<HostCounterProductConfigureSheet> createState() =>
      _HostCounterProductConfigureSheetState();
}

class _HostCounterProductConfigureSheetState
    extends State<HostCounterProductConfigureSheet> {
  late final ProductConfigurationDraft _draft;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _draft = ProductConfigurationDraft(widget.product);
  }

  bool get _canAdd => _draft.isValid && _quantity >= 1;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          key: const Key('host-counter-product-configurator'),
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          BolivianPrice.label(product.effectivePrice),
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(LucideIcons.x),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                shrinkWrap: true,
                children: [
                  ProductOptionGroupsPicker(
                    draft: _draft,
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Cantidad',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      QtyRoundButton(
                        icon: LucideIcons.minus,
                        onPressed: _quantity > 1
                            ? () => setState(() => _quantity--)
                            : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          '$_quantity',
                          key: const Key('host-counter-config-qty'),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      QtyRoundButton(
                        icon: LucideIcons.plus,
                        onPressed: () => setState(() => _quantity++),
                      ),
                    ],
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
                  height: 48,
                  child: ElevatedButton(
                    key: const Key('host-counter-config-add'),
                    onPressed: _canAdd
                        ? () => Navigator.pop(
                              context,
                              CounterSaleProductAddResult(
                                product: product,
                                selections: _draft.toSelections(),
                                quantity: _quantity,
                              ),
                            )
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[300],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Agregar',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
