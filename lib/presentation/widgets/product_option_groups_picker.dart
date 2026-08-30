import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';
import 'package:flutter_app_saludable/domain/entities/product_option_selection.dart';

/// Selector genérico de grupos/opciones (PROD-OPTIONS-001c).
/// Reutilizado en el bottom sheet y en [MemberProductDetailScreen].
class ProductOptionGroupsPicker extends StatelessWidget {
  const ProductOptionGroupsPicker({
    super.key,
    required this.draft,
    required this.onChanged,
  });

  final ProductConfigurationDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (draft.groups.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final group in draft.groups) ...[
          _GroupBlock(
            group: group,
            draft: draft,
            onChanged: onChanged,
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class QtyRoundButton extends StatelessWidget {
  const QtyRoundButton({
    super.key,
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        style: IconButton.styleFrom(
          backgroundColor: Colors.grey[100],
          disabledBackgroundColor: Colors.grey[50],
          foregroundColor: AppTheme.primaryColor,
          disabledForegroundColor: Colors.grey[300],
        ),
      ),
    );
  }
}

class _GroupBlock extends StatelessWidget {
  const _GroupBlock({
    required this.group,
    required this.draft,
    required this.onChanged,
  });

  final ProductOptionGroup group;
  final ProductConfigurationDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final error = draft.groupError(group);
    final mode = ProductConfigurationDraft.modeFor(group);
    final options = group.selectableOptions;
    final requiredEmpty = group.minSelections > 0 && options.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          group.name,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          group.socioChoiceLabel,
          style: const TextStyle(fontSize: 13, color: Colors.black87),
        ),
        if (group.showRepeatHint) ...[
          const SizedBox(height: 4),
          const Text(
            'Puedes elegir la misma opción más de una vez.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
        const SizedBox(height: 10),
        if (requiredEmpty)
          Text(
            ProductConfigurationDraft.emptyRequiredGroupMessage,
            style: TextStyle(color: Colors.red.shade800, fontSize: 13),
          )
        else if (options.isEmpty)
          const SizedBox.shrink()
        else
          switch (mode) {
            OptionGroupUiMode.single => _SingleList(
                group: group,
                options: options,
                draft: draft,
                onChanged: onChanged,
              ),
            OptionGroupUiMode.multi => _MultiList(
                group: group,
                options: options,
                draft: draft,
                onChanged: onChanged,
              ),
            OptionGroupUiMode.counter => _CounterList(
                group: group,
                options: options,
                draft: draft,
                onChanged: onChanged,
              ),
          },
        if (error != null && !requiredEmpty) ...[
          const SizedBox(height: 6),
          Text(
            error,
            style: TextStyle(color: Colors.red.shade800, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

class _SingleList extends StatelessWidget {
  const _SingleList({
    required this.group,
    required this.options,
    required this.draft,
    required this.onChanged,
  });

  final ProductOptionGroup group;
  final List<ProductOption> options;
  final ProductConfigurationDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    int? selectedValue;
    for (final option in options) {
      if (draft.quantity(group, option) == 1) {
        selectedValue = option.id ?? option.orden;
        break;
      }
    }

    return RadioGroup<int>(
      groupValue: selectedValue,
      onChanged: (value) {
        if (value == null) return;
        final option = options.firstWhere(
          (o) => (o.id ?? o.orden) == value,
        );
        draft.selectSingle(group, option);
        onChanged();
      },
      child: Column(
        children: [
          for (final option in options)
            RadioListTile<int>(
              key: Key('option-${option.id}'),
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              title: Text(option.name),
              value: option.id ?? option.orden,
            ),
        ],
      ),
    );
  }
}

class _MultiList extends StatelessWidget {
  const _MultiList({
    required this.group,
    required this.options,
    required this.draft,
    required this.onChanged,
  });

  final ProductOptionGroup group;
  final List<ProductOption> options;
  final ProductConfigurationDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final option in options)
          CheckboxListTile(
            key: Key('option-${option.id}'),
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(option.name),
            value: draft.quantity(group, option) > 0,
            onChanged: (checked) {
              draft.setMultiSelected(group, option, checked == true);
              onChanged();
            },
          ),
      ],
    );
  }
}

class _CounterList extends StatelessWidget {
  const _CounterList({
    required this.group,
    required this.options,
    required this.draft,
    required this.onChanged,
  });

  final ProductOptionGroup group;
  final List<ProductOption> options;
  final ProductConfigurationDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final option in options)
          Padding(
            key: Key('option-${option.id}'),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(option.name, style: const TextStyle(fontSize: 15)),
                ),
                QtyRoundButton(
                  key: Key('option-${option.id}-minus'),
                  icon: LucideIcons.minus,
                  onPressed: draft.quantity(group, option) > 0
                      ? () {
                          draft.decrement(group, option);
                          onChanged();
                        }
                      : null,
                ),
                SizedBox(
                  width: 36,
                  child: Text(
                    '${draft.quantity(group, option)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                QtyRoundButton(
                  key: Key('option-${option.id}-plus'),
                  icon: LucideIcons.plus,
                  onPressed: draft.canIncrement(group, option)
                      ? () {
                          draft.increment(group, option);
                          onChanged();
                        }
                      : null,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
