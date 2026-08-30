import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';
import 'package:flutter_app_saludable/domain/entities/product.dart';
import 'package:flutter_app_saludable/domain/entities/product_option_selection.dart';
import 'package:flutter_app_saludable/presentation/widgets/product_option_groups_picker.dart';

Future<List<ProductOptionSelection>?> showProductOptionConfigurator({
  required BuildContext context,
  required Product product,
}) {
  return showModalBottomSheet<List<ProductOptionSelection>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => ProductOptionConfiguratorSheet(product: product),
  );
}

class ProductOptionConfiguratorSheet extends StatefulWidget {
  final Product product;

  const ProductOptionConfiguratorSheet({super.key, required this.product});

  @override
  State<ProductOptionConfiguratorSheet> createState() =>
      _ProductOptionConfiguratorSheetState();
}

class _ProductOptionConfiguratorSheetState
    extends State<ProductOptionConfiguratorSheet> {
  late final ProductConfigurationDraft _draft;

  @override
  void initState() {
    super.initState();
    _draft = ProductConfigurationDraft(widget.product);
  }

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
          key: const Key('product-option-configurator'),
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
                    child: Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
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
                  if (product.description.isNotEmpty) ...[
                    Text(
                      product.description,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 16),
                  ],
                  ProductOptionGroupsPicker(
                    draft: _draft,
                    onChanged: () => setState(() {}),
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
                    key: const Key('configurator-add'),
                    onPressed: _draft.isValid
                        ? () => Navigator.pop(context, _draft.toSelections())
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
