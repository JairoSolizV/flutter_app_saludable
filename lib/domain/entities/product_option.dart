/// Opción de un grupo. Remote-only: no se persiste en SQLite.
class ProductOption {
  final int? id;
  final String name;
  final int orden;
  final bool active;

  ProductOption({
    this.id,
    required this.name,
    this.orden = 0,
    this.active = true,
  });

  factory ProductOption.fromMap(Map<String, dynamic> map) {
    return ProductOption(
      id: _optionalInt(map['id']),
      name: map['nombre']?.toString() ?? map['name']?.toString() ?? '',
      orden: _optionalInt(map['orden']) ?? 0,
      active: map['activo'] == true ||
          map['active'] == true ||
          map['activo'] == 1 ||
          map['active'] == 1 ||
          (map['activo'] == null && map['active'] == null),
    );
  }

  Map<String, dynamic> toApiMap() {
    return {
      if (id != null) 'id': id,
      'nombre': name,
      'orden': orden,
      'activo': active,
    };
  }

  static int? _optionalInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}

/// Grupo de opciones de un producto (p. ej. Sabores). Remote-only.
class ProductOptionGroup {
  final int? id;
  final String name;
  final int orden;
  final int minSelections;
  final int? maxSelections;
  final bool allowRepeat;
  final List<ProductOption> options;

  ProductOptionGroup({
    this.id,
    required this.name,
    this.orden = 0,
    this.minSelections = 0,
    this.maxSelections,
    this.allowRepeat = false,
    List<ProductOption>? options,
  }) : options = options ?? [];

  factory ProductOptionGroup.fromMap(Map<String, dynamic> map) {
    final rawOptions = map['opciones'] ?? map['options'];
    final options = <ProductOption>[];
    if (rawOptions is List) {
      for (final item in rawOptions) {
        if (item is Map) {
          options.add(ProductOption.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }
    return ProductOptionGroup(
      id: ProductOption._optionalInt(map['id']),
      name: map['nombre']?.toString() ?? map['name']?.toString() ?? '',
      orden: ProductOption._optionalInt(map['orden']) ?? 0,
      minSelections: ProductOption._optionalInt(map['minSelecciones']) ??
          ProductOption._optionalInt(map['minSelections']) ??
          0,
      maxSelections: ProductOption._optionalInt(map['maxSelecciones']) ??
          ProductOption._optionalInt(map['maxSelections']),
      allowRepeat: map['permiteRepetir'] == true ||
          map['allowRepeat'] == true ||
          map['permiteRepetir'] == 1,
      options: options,
    );
  }

  /// Incluye `maxSelecciones: null` cuando no hay tope.
  Map<String, dynamic> toApiMap() {
    return {
      if (id != null) 'id': id,
      'nombre': name,
      'orden': orden,
      'minSelecciones': minSelections,
      'maxSelecciones': maxSelections,
      'permiteRepetir': allowRepeat,
      'opciones': options.map((o) => o.toApiMap()).toList(),
    };
  }

  /// `null` si el payload no trae grupos (compatibilidad).
  static List<ProductOptionGroup>? listFromJson(dynamic raw) {
    if (raw == null) return null;
    if (raw is! List) return null;
    return raw
        .whereType<Map>()
        .map((e) => ProductOptionGroup.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  String get selectionRuleLabel {
    final max = maxSelections;
    if (max == null) {
      if (minSelections <= 0) return 'Selección opcional, sin límite';
      return 'Selecciona al menos $minSelections';
    }
    if (minSelections == max) {
      return 'Selecciona exactamente $minSelections';
    }
    return 'Selecciona de $minSelections a $max';
  }

  /// Textos de regla para el socio (PROD-OPTIONS-001c-FL).
  String get socioChoiceLabel {
    final max = maxSelections;
    if (max == null) {
      if (minSelections <= 0) return 'Opcional';
      return 'Elige al menos $minSelections';
    }
    if (minSelections == 1 && max == 1) return 'Elige 1';
    if (minSelections <= 0 && max == 1) return 'Elige hasta 1';
    if (minSelections == max) return 'Elige $minSelections';
    if (minSelections <= 0) return 'Elige hasta $max';
    return 'Elige entre $minSelections y $max';
  }

  bool get showRepeatHint => allowRepeat && maxSelections != 1;

  List<ProductOption> get selectableOptions {
    final list = options.where((o) => o.active).toList()
      ..sort((a, b) {
        final byOrden = a.orden.compareTo(b.orden);
        if (byOrden != 0) return byOrden;
        return (a.id ?? 0).compareTo(b.id ?? 0);
      });
    return list;
  }
}

class ProductOptionGroupIssue {
  const ProductOptionGroupIssue({
    required this.groupIndex,
    required this.message,
    this.optionIndex,
    this.field = 'group',
  });

  final int groupIndex;
  final int? optionIndex;
  final String field;
  final String message;
}

/// Validación de UI alineada con las reglas del backend (el 400 sigue siendo autoridad).
class ProductOptionGroupValidator {
  ProductOptionGroupValidator._();

  static List<ProductOptionGroupIssue> validate(
      List<ProductOptionGroup> groups) {
    final errors = <ProductOptionGroupIssue>[];
    final seenGroupNames = <String>{};

    for (var i = 0; i < groups.length; i++) {
      final group = groups[i];
      final nombre = group.name.trim();
      if (nombre.isEmpty) {
        errors.add(ProductOptionGroupIssue(
          groupIndex: i,
          field: 'name',
          message: 'El nombre del grupo no puede estar vacío',
        ));
      } else {
        final key = nombre.toLowerCase();
        if (!seenGroupNames.add(key)) {
          errors.add(ProductOptionGroupIssue(
            groupIndex: i,
            field: 'name',
            message: "Ya existe un grupo con el nombre '$nombre'",
          ));
        }
      }

      if (group.minSelections < 1) {
        errors.add(ProductOptionGroupIssue(
          groupIndex: i,
          field: 'min',
          message: 'El mínimo debe ser al menos 1',
        ));
      }

      final max = group.maxSelections;
      if (max != null && max < group.minSelections) {
        errors.add(ProductOptionGroupIssue(
          groupIndex: i,
          field: 'max',
          message: 'El máximo no puede ser menor que el mínimo',
        ));
      }

      if (group.options.isEmpty) {
        errors.add(ProductOptionGroupIssue(
          groupIndex: i,
          field: 'options',
          message: 'El grupo debe tener al menos una opción',
        ));
      }

      final seenOptionNames = <String>{};
      for (var j = 0; j < group.options.length; j++) {
        final optionName = group.options[j].name.trim();
        if (optionName.isEmpty) {
          errors.add(ProductOptionGroupIssue(
            groupIndex: i,
            optionIndex: j,
            field: 'optionName',
            message: 'El nombre de la opción no puede estar vacío',
          ));
        } else if (!seenOptionNames.add(optionName.toLowerCase())) {
          errors.add(ProductOptionGroupIssue(
            groupIndex: i,
            optionIndex: j,
            field: 'optionName',
            message: "La opción '$optionName' está duplicada en el grupo",
          ));
        }
      }

      if (!group.allowRepeat && group.options.isNotEmpty) {
        final defined = group.options.length;
        if (max != null && max > defined) {
          errors.add(ProductOptionGroupIssue(
            groupIndex: i,
            field: 'max',
            message:
                'Sin repetir, el máximo no puede superar la cantidad de opciones',
          ));
        }
        if (group.minSelections > defined) {
          errors.add(ProductOptionGroupIssue(
            groupIndex: i,
            field: 'min',
            message:
                'Sin repetir, el mínimo no puede superar la cantidad de opciones',
          ));
        }
      }
    }
    return errors;
  }
}
