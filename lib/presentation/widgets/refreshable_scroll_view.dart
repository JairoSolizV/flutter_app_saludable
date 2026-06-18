import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';

/// Envuelve contenido NO scrolleable (estados vacío, error o contenido corto)
/// para que admita "deslizar para actualizar" (pull-to-refresh).
///
/// El [child] se centra y se fuerza a ocupar al menos toda la altura visible,
/// de modo que el gesto de arrastre funcione aunque el contenido sea pequeño.
class RefreshableScrollView extends StatelessWidget {
  const RefreshableScrollView({
    super.key,
    required this.onRefresh,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(24),
  });

  /// Acción de recarga. Debe devolver un [Future] que completa cuando termina.
  final Future<void> Function() onRefresh;

  /// Contenido a mostrar (p. ej. el `Column` del estado vacío o de error).
  final Widget child;

  /// Color del indicador. Por defecto [AppTheme.primaryColor].
  final Color? color;

  /// Padding alrededor del contenido centrado.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: color ?? AppTheme.primaryColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: padding,
                child: Center(child: child),
              ),
            ),
          );
        },
      ),
    );
  }
}
