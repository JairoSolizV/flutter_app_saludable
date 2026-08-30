import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';
import 'package:flutter_app_saludable/domain/entities/product_option.dart';

class ProductOptionDraft {
  ProductOptionDraft({this.id, String name = ''})
      : name = TextEditingController(text: name);

  int? id;
  final TextEditingController name;
  String? error;

  void dispose() => name.dispose();
}

class ProductOptionGroupDraft {
  ProductOptionGroupDraft({
    this.id,
    String name = '',
    int minSelections = 0,
    int? maxSelections,
    this.allowRepeat = false,
    List<ProductOptionDraft>? options,
  })  : name = TextEditingController(text: name),
        min = TextEditingController(text: minSelections.toString()),
        max = TextEditingController(
            text: maxSelections == null ? '' : maxSelections.toString()),
        unlimitedMax = maxSelections == null,
        options = options ?? [ProductOptionDraft()];

  int? id;
  final TextEditingController name;
  final TextEditingController min;
  final TextEditingController max;
  bool unlimitedMax;
  bool allowRepeat;
  final List<ProductOptionDraft> options;
  String? error;

  void dispose() {
    name.dispose();
    min.dispose();
    max.dispose();
    for (final option in options) {
      option.dispose();
    }
  }

  ProductOptionGroup toGroup({required int orden}) {
    final parsedMin = int.tryParse(min.text.trim()) ?? 0;
    final parsedMax =
        unlimitedMax ? null : int.tryParse(max.text.trim());
    return ProductOptionGroup(
      id: id,
      name: name.text.trim(),
      orden: orden,
      minSelections: parsedMin,
      maxSelections: parsedMax,
      allowRepeat: allowRepeat,
      options: [
        for (var i = 0; i < options.length; i++)
          ProductOption(
            id: options[i].id,
            name: options[i].name.text.trim(),
            orden: i,
            active: true,
          ),
      ],
    );
  }

  static ProductOptionGroupDraft fromGroup(ProductOptionGroup group) {
    return ProductOptionGroupDraft(
      id: group.id,
      name: group.name,
      minSelections: group.minSelections,
      maxSelections: group.maxSelections,
      allowRepeat: group.allowRepeat,
      options: group.options.isEmpty
          ? [ProductOptionDraft()]
          : [
              for (final option in group.options)
                ProductOptionDraft(id: option.id, name: option.name),
            ],
    );
  }
}

class ProductOptionGroupsSection extends StatelessWidget {
  const ProductOptionGroupsSection({
    super.key,
    required this.groups,
    required this.enabled,
    required this.onChanged,
  });

  final List<ProductOptionGroupDraft> groups;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('product-option-groups-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Opciones del producto',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        const Text(
          'Opcional. Podés definir grupos como Sabores o Consistencia. '
          'No es obligatorio agregar grupos.',
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < groups.length; i++) ...[
          _GroupCard(
            index: i,
            draft: groups[i],
            enabled: enabled,
            onChanged: onChanged,
            onRemove: () {
              groups[i].dispose();
              groups.removeAt(i);
              onChanged();
            },
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const Key('add-option-group'),
            onPressed: enabled
                ? () {
                    groups.add(ProductOptionGroupDraft());
                    onChanged();
                  }
                : null,
            icon: const Icon(LucideIcons.plus),
            label: const Text('Agregar grupo'),
          ),
        ),
      ],
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.index,
    required this.draft,
    required this.enabled,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final ProductOptionGroupDraft draft;
  final bool enabled;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: Key('option-group-$index'),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: Key('option-group-$index-name'),
                    controller: draft.name,
                    enabled: enabled,
                    maxLength: 60,
                    inputFormatters: [LengthLimitingTextInputFormatter(60)],
                    decoration: InputDecoration(
                      labelText: 'Nombre del grupo',
                      hintText: 'Ej: Sabores',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      errorText: _errorFor(draft, 'name'),
                      counterText: '',
                    ),
                  ),
                ),
                IconButton(
                  key: Key('option-group-$index-remove'),
                  onPressed: enabled ? onRemove : null,
                  tooltip: 'Eliminar grupo',
                  icon: const Icon(LucideIcons.x, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: Key('option-group-$index-min'),
                    controller: draft.min,
                    enabled: enabled,
                    keyboardType: TextInputType.number,
                    maxLength: 3,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Mínimo',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      errorText: _errorFor(draft, 'min'),
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: draft.unlimitedMax
                      ? InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Máximo',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          child: const Text(
                            'Sin límite',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        )
                      : TextField(
                          key: Key('option-group-$index-max'),
                          controller: draft.max,
                          enabled: enabled,
                          keyboardType: TextInputType.number,
                          maxLength: 3,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3),
                          ],
                          decoration: InputDecoration(
                            labelText: 'Máximo',
                            border: const OutlineInputBorder(),
                            isDense: true,
                            errorText: _errorFor(draft, 'max'),
                            counterText: '',
                          ),
                        ),
                ),
              ],
            ),
            SwitchListTile.adaptive(
              key: Key('option-group-$index-unlimited'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Sin límite de máximo'),
              value: draft.unlimitedMax,
              onChanged: enabled
                  ? (value) {
                      draft.unlimitedMax = value;
                      onChanged();
                    }
                  : null,
            ),
            SwitchListTile.adaptive(
              key: Key('option-group-$index-repeat'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Permitir repetir opción'),
              subtitle: const Text(
                'Permite seleccionar la misma opción más de una vez.',
                style: TextStyle(fontSize: 12),
              ),
              value: draft.allowRepeat,
              onChanged: enabled
                  ? (value) {
                      draft.allowRepeat = value;
                      onChanged();
                    }
                  : null,
            ),
            if (draft.error != null &&
                (draft.error!.contains('opción') ||
                    draft.error!.contains('grupo')))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  draft.error!,
                  key: Key('option-group-$index-error'),
                  style: const TextStyle(color: AppTheme.error, fontSize: 12),
                ),
              ),
            const Text(
              'Opciones',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            for (var j = 0; j < draft.options.length; j++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: Key('option-group-$index-option-$j-name'),
                        controller: draft.options[j].name,
                        enabled: enabled,
                        maxLength: 100,
                        inputFormatters: [LengthLimitingTextInputFormatter(100)],
                        decoration: InputDecoration(
                          hintText: 'Ej: Frutilla',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          errorText: draft.options[j].error,
                          counterText: '',
                        ),
                      ),
                    ),
                    IconButton(
                      key: Key('option-group-$index-option-$j-remove'),
                      onPressed: enabled
                          ? () {
                              draft.options[j].dispose();
                              draft.options.removeAt(j);
                              onChanged();
                            }
                          : null,
                      tooltip: 'Eliminar opción',
                      icon: const Icon(LucideIcons.x, size: 18),
                    ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: Key('option-group-$index-add-option'),
                onPressed: enabled
                    ? () {
                        draft.options.add(ProductOptionDraft());
                        onChanged();
                      }
                    : null,
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('Agregar opción'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _errorFor(ProductOptionGroupDraft draft, String field) {
    if (draft.error == null) return null;
    if (field == 'name' && draft.error!.contains('nombre del grupo')) {
      return draft.error;
    }
    if (field == 'name' && draft.error!.contains('Ya existe un grupo')) {
      return draft.error;
    }
    if (field == 'min' && draft.error!.contains('mínimo')) {
      return draft.error;
    }
    if (field == 'max' &&
        (draft.error!.contains('máximo') || draft.error!.contains('máximo'))) {
      return draft.error;
    }
    return null;
  }
}

void applyOptionGroupIssues(
  List<ProductOptionGroupDraft> drafts,
  List<ProductOptionGroupIssue> issues,
) {
  for (final draft in drafts) {
    draft.error = null;
    for (final option in draft.options) {
      option.error = null;
    }
  }
  for (final issue in issues) {
    if (issue.groupIndex < 0 || issue.groupIndex >= drafts.length) continue;
    final draft = drafts[issue.groupIndex];
    if (issue.optionIndex != null &&
        issue.optionIndex! >= 0 &&
        issue.optionIndex! < draft.options.length) {
      draft.options[issue.optionIndex!].error = issue.message;
    } else {
      draft.error = issue.message;
    }
  }
}

bool hasUnresolvedMax(List<ProductOptionGroupDraft> drafts) {
  for (var i = 0; i < drafts.length; i++) {
    final draft = drafts[i];
    if (!draft.unlimitedMax && int.tryParse(draft.max.text.trim()) == null) {
      draft.error = 'Indicá un máximo o marcá Sin límite';
      return true;
    }
  }
  return false;
}
