import 'package:flutter/widgets.dart';

/// Cierra el teclado soltando el foco del campo de texto activo.
///
/// UI-001: el login con Google abre una activity nativa. Si al volver a primer
/// plano sigue habiendo un `TextField` enfocado, Android reabre el teclado y
/// éste queda encima de la pantalla a la que navegamos. Soltar el foco antes de
/// lanzar el flujo nativo —y otra vez al volver, antes de cambiar de ruta— lo
/// evita.
///
/// No recibe `BuildContext` a propósito: actúa sobre el foco global, así que es
/// seguro llamarlo después de un `await` aunque el widget ya esté desmontado.
void dismissKeyboard() {
  FocusManager.instance.primaryFocus?.unfocus();
}
