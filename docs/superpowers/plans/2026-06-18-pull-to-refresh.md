# Pull-to-Refresh Consistente — Implementation Plan

> **For agentic workers:** Este plan se ejecuta **fase por fase**. Cada fase termina en un commit. Los pasos usan checkbox (`- [ ]`) para tracking.

**Goal:** Que todas las pantallas de la app que cargan datos del backend permitan "deslizar para actualizar" (pull-to-refresh), incluyendo los estados vacío y de error, con un comportamiento uniforme.

**Architecture:** Se introduce un widget reutilizable `RefreshableScrollView` que hace deslizable cualquier contenido no scrolleable (estados vacío/error/contenido corto). Las listas con datos se envuelven con `RefreshIndicator` y se les fuerza `AlwaysScrollableScrollPhysics`. El `onRefresh` de cada pantalla reusa su método `_load...()` existente.

**Tech Stack:** Flutter 3.41.9, Provider, go_router, Material `RefreshIndicator`. Tests con `flutter_test`.

---

## Convenciones de verificación (aplican a TODAS las fases)

- Antes de cada commit ejecutar:
  - `flutter analyze` → no debe introducir errores nuevos.
- Color del indicador siempre `AppTheme.primaryColor` (import: `package:flutter_app_saludable/core/theme/app_theme.dart`).
- `onRefresh` siempre apunta al método de recarga existente de la pantalla (devuelve `Future<void>`). Si la pantalla tiene varios cargadores, usar el combinado (p. ej. `_loadAll`, o crear un `Future.wait([...])` inline).
- No tocar: formularios crear/editar, login/registro, escáner QR / QR display, `guest_home_screen`, `basic_user_home_screen`, pantallas de perfil.

---

## Las 3 recetas de transformación

### Receta 1 — Lista con datos (`ListView` / `GridView`)

Envolver el scrollable en `RefreshIndicator` (si no lo tiene) y forzar physics:

```dart
RefreshIndicator(
  onRefresh: _load,                      // método de recarga de la pantalla
  color: AppTheme.primaryColor,
  child: ListView.builder(
    physics: const AlwaysScrollableScrollPhysics(),   // <-- AGREGAR
    // ...resto igual
  ),
)
```

> Si la lista ya está envuelta en `RefreshIndicator` (Grupo 1), **solo** agregar `physics: const AlwaysScrollableScrollPhysics()` al `ListView`/`GridView`/`ListView.separated` si aún no lo tiene.

### Receta 2 — Estado no scrolleable (vacío / error / "sin datos")

Reemplazar el `Center(...)` por `RefreshableScrollView`, que centra el contenido y lo hace deslizable:

```dart
// ANTES
return Center(
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [ /* icono, texto, botón reintentar */ ],
  ),
);

// DESPUÉS
return RefreshableScrollView(
  onRefresh: _load,
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    mainAxisSize: MainAxisSize.min,
    children: [ /* mismos hijos */ ],
  ),
);
```

> El `RefreshableScrollView` ya aplica `Center` + padding + altura mínima del viewport. Quitar el `Center` externo y dejar el `Column` con `mainAxisSize: MainAxisSize.min`.

### Receta 3 — El body ya es `SingleChildScrollView` (dashboards / detalles)

No centrar; solo envolver y forzar physics:

```dart
// ANTES
body: SingleChildScrollView(
  padding: ...,
  child: Column(...),
)

// DESPUÉS
body: RefreshIndicator(
  onRefresh: _load,
  color: AppTheme.primaryColor,
  child: SingleChildScrollView(
    physics: const AlwaysScrollableScrollPhysics(),   // <-- AGREGAR
    padding: ...,
    child: Column(...),
  ),
)
```

> **El spinner de carga inicial** (`CircularProgressIndicator` centrado mientras `_isLoading == true`) se deja **sin tocar**: no hay nada que refrescar todavía. El gesto queda disponible en los estados con datos / vacío / error.

---

## Fase 0: Rama de trabajo

- [ ] **Paso 1: Crear la rama de feature** (estamos en `main`, árbol limpio)

```bash
git checkout -b feature/pull-to-refresh
```

No hay commit en esta fase.

---

## Fase 1: Widget reutilizable `RefreshableScrollView` (TDD)

**Files:**
- Create: `lib/presentation/widgets/refreshable_scroll_view.dart`
- Test: `test/widgets/refreshable_scroll_view_test.dart`

- [ ] **Paso 1: Escribir el test que falla**

Crear `test/widgets/refreshable_scroll_view_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app_saludable/presentation/widgets/refreshable_scroll_view.dart';

void main() {
  group('RefreshableScrollView', () {
    testWidgets('renderiza el child', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RefreshableScrollView(
              onRefresh: () async {},
              child: const Text('Sin datos'),
            ),
          ),
        ),
      );
      expect(find.text('Sin datos'), findsOneWidget);
    });

    testWidgets('invoca onRefresh al deslizar hacia abajo', (tester) async {
      var called = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RefreshableScrollView(
              onRefresh: () async {
                called = true;
              },
              child: const Text('Sin datos'),
            ),
          ),
        ),
      );

      await tester.fling(find.text('Sin datos'), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      expect(called, isTrue);
    });
  });
}
```

- [ ] **Paso 2: Ejecutar el test y verificar que falla**

Run: `flutter test test/widgets/refreshable_scroll_view_test.dart`
Expected: FAIL — `Target of URI doesn't exist` / `RefreshableScrollView` no definido.

- [ ] **Paso 3: Crear el widget**

Crear `lib/presentation/widgets/refreshable_scroll_view.dart`:

```dart
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
```

- [ ] **Paso 4: Ejecutar el test y verificar que pasa**

Run: `flutter test test/widgets/refreshable_scroll_view_test.dart`
Expected: PASS (2 tests).

- [ ] **Paso 5: `flutter analyze`**

Run: `flutter analyze lib/presentation/widgets/refreshable_scroll_view.dart`
Expected: No issues.

- [ ] **Paso 6: Commit**

```bash
git add lib/presentation/widgets/refreshable_scroll_view.dart test/widgets/refreshable_scroll_view_test.dart docs/superpowers/plans/2026-06-18-pull-to-refresh.md
git commit -m "feat: agregar widget reutilizable RefreshableScrollView para pull-to-refresh"
```

---

## Fase 2: Grupo 1 — módulos principales (arreglar vacío/error)

Pantallas que YA tienen `RefreshIndicator` en la lista, pero cuyos estados vacío/error no son deslizables.

**Files (modificar):**
- `lib/presentation/screens/host/host_orders_list_screen.dart`
- `lib/presentation/screens/events/events_list_screen.dart`
- `lib/presentation/screens/member/attendance/member_attendance_screen.dart`
- `lib/presentation/screens/member/member_orders_list_screen.dart`

Para cada archivo: agregar `import '../../widgets/refreshable_scroll_view.dart';` (ajustar profundidad relativa) y aplicar las recetas.

- [ ] **Paso 1: `host_orders_list_screen.dart`**
  - Import del widget.
  - Estado error (`_error != null`, ~líneas 555-573, el `Center` con icono + "Reintentar"): Receta 2 con `onRefresh: _loadOrders`.
  - Estado vacío (`filteredOrders.isEmpty`, ~líneas 575-593): Receta 2 con `onRefresh: _loadOrders`.
  - Lista con datos (ya tiene `RefreshIndicator` en ~594): agregar `physics: const AlwaysScrollableScrollPhysics()` al `ListView.builder` (~596).

- [ ] **Paso 2: `events_list_screen.dart`**
  - Import del widget.
  - `_buildErrorView()` (~109): cambiar el `Center` raíz por `RefreshableScrollView(onRefresh: _loadEventos, child: Column(... mainAxisSize: min ...))`.
  - `_buildEmptyView()` (~152): igual, `onRefresh: _loadEventos`.
  - `_buildEventosList()` (~185): ya tiene `RefreshIndicator`; agregar `physics: const AlwaysScrollableScrollPhysics()` al `ListView.builder` (~189).

- [ ] **Paso 3: `member_attendance_screen.dart`**
  - Import del widget.
  - Estado error (~90-94): hoy retorna `Scaffold(body: Center(...))`. Mantener el `Scaffold`+`AppBar` y poner como body `RefreshableScrollView(onRefresh: _loadData, child: Text("Error: $_error"...))`.
  - `_buildEmptyState()` (~249): cambiar el `Center` por `RefreshableScrollView(onRefresh: _loadData, child: Column(... mainAxisSize: min ...))`.
  - Lista (~114, ya con `RefreshIndicator`): agregar `physics: const AlwaysScrollableScrollPhysics()` al `ListView.separated` (~117).

- [ ] **Paso 4: `member_orders_list_screen.dart`**
  - Import del widget.
  - Estado error (~182, `Center(child: Text('Error: $_error'...))`): envolverlo manteniendo deslizable → `RefreshableScrollView(onRefresh: _loadOrdersFromBackend, child: Text('Error: $_error'...))`.
  - Estado vacío (~224-235, `if (orders.isEmpty) return const Center(...)` dentro del child del `RefreshIndicator`): convertir ese `Center` en el `child` de un `RefreshableScrollView(onRefresh: _loadOrdersFromBackend, ...)`, o (alternativa) reemplazar por un `ListView` de un solo hijo. Preferir `RefreshableScrollView`.
  - Lista (~236): agregar `physics: const AlwaysScrollableScrollPhysics()` al `ListView.builder`.

- [ ] **Paso 5: Verificar y commitear**

```bash
flutter analyze lib/presentation/screens/host/host_orders_list_screen.dart lib/presentation/screens/events/events_list_screen.dart lib/presentation/screens/member/attendance/member_attendance_screen.dart lib/presentation/screens/member/member_orders_list_screen.dart
```
Expected: No issues nuevos.

```bash
git add lib/presentation/screens/host/host_orders_list_screen.dart lib/presentation/screens/events/events_list_screen.dart lib/presentation/screens/member/attendance/member_attendance_screen.dart lib/presentation/screens/member/member_orders_list_screen.dart
git commit -m "feat: pull-to-refresh en estados vacío/error de pedidos, eventos y asistencias"
```

---

## Fase 3: Grupo 1 — pantallas restantes (arreglar vacío/error)

**Files (modificar):**
- `lib/presentation/screens/host/members/host_members_list_screen.dart`
- `lib/presentation/screens/host/pre_socios/host_pre_socios_list_screen.dart`
- `lib/presentation/screens/member/member_select_club_screen.dart`
- `lib/presentation/screens/member/member_club_products_screen.dart`
- `lib/presentation/screens/host/members/host_referral_tree_screen.dart`
- `lib/presentation/screens/common/support_center_screen.dart`

- [ ] **Paso 1: `host_members_list_screen.dart`**
  - Import del widget.
  - Error (~115-148): Receta 2, `onRefresh: _loadMembers`.
  - Vacío total `_members.isEmpty` (~150): Receta 2, `onRefresh: _loadMembers`.
  - Vacío filtrado `filteredMembers.isEmpty` (~248-254, dentro del `Expanded` bajo el `RefreshIndicator`): cambiar ese `Center` por `RefreshableScrollView(onRefresh: _loadMembers, child: ...)`.
  - `ListView.builder` (~255): agregar `physics: const AlwaysScrollableScrollPhysics()`.

- [ ] **Paso 2: `host_pre_socios_list_screen.dart`**
  - Import del widget.
  - Error `_buildError()`/rama de error (~72): Receta 2, `onRefresh: _load`.
  - El vacío `_buildEmpty()` (~91) ya usa `ListView` (deslizable) — dejar igual o agregar `physics: const AlwaysScrollableScrollPhysics()` por consistencia.
  - `_buildList()` `ListView.builder` (~110): agregar `physics: const AlwaysScrollableScrollPhysics()`.

- [ ] **Paso 3: `member_select_club_screen.dart`**
  - Import del widget.
  - Error `_buildError` (~119): Receta 2, `onRefresh: _loadClubes`.
  - Vacío `_buildEmpty` (~155): Receta 2, `onRefresh: _loadClubes`.
  - `ListView.builder` (~186, ya con `RefreshIndicator` en ~184): agregar `physics: const AlwaysScrollableScrollPhysics()`.

- [ ] **Paso 4: `member_club_products_screen.dart`**
  - Import del widget.
  - Error de membresía (~476, `Scaffold(body: Center(...))`): poner body `RefreshableScrollView(onRefresh: _loadMembership, child: ...)` (usar el cargador de membresía existente; verificar nombre exacto al leer el archivo).
  - Vacío `products.isEmpty && _combos.isEmpty` (~501-502): Receta 2 con el mismo `onRefresh` que ya usa el `RefreshIndicator` de la lista (~503-509, copiar su closure `onRefresh`).
  - `ListView` (~510, ya con `RefreshIndicator`): agregar `physics: const AlwaysScrollableScrollPhysics()`.

- [ ] **Paso 5: `host_referral_tree_screen.dart`**
  - Import del widget.
  - Error (~76): Receta 2, `onRefresh: () => _cargarArbol(widget.membresiaId)`.
  - "Sin datos de red" (~103): Receta 2, mismo `onRefresh`.
  - `ListView` (~127, ya con `RefreshIndicator` en ~104): agregar `physics: const AlwaysScrollableScrollPhysics()`.

- [ ] **Paso 6: `support_center_screen.dart`**
  - Import del widget.
  - Error (~232-): Receta 2, `onRefresh: () => provider.fetchMyTickets()`.
  - Vacío `tickets.isEmpty` (~257): Receta 2, mismo `onRefresh`.
  - `ListView.separated` (~276, ya con `RefreshIndicator`): agregar `physics: const AlwaysScrollableScrollPhysics()`.

- [ ] **Paso 7: Verificar y commitear**

```bash
flutter analyze lib/presentation/screens/host/members/host_members_list_screen.dart lib/presentation/screens/host/pre_socios/host_pre_socios_list_screen.dart lib/presentation/screens/member/member_select_club_screen.dart lib/presentation/screens/member/member_club_products_screen.dart lib/presentation/screens/host/members/host_referral_tree_screen.dart lib/presentation/screens/common/support_center_screen.dart
```
Expected: No issues nuevos.

```bash
git add lib/presentation/screens/host/members/host_members_list_screen.dart lib/presentation/screens/host/pre_socios/host_pre_socios_list_screen.dart lib/presentation/screens/member/member_select_club_screen.dart lib/presentation/screens/member/member_club_products_screen.dart lib/presentation/screens/host/members/host_referral_tree_screen.dart lib/presentation/screens/common/support_center_screen.dart
git commit -m "feat: pull-to-refresh en estados vacío/error de socios, pre-socios, clubes, productos de club, referidos y soporte"
```

---

## Fase 4: Grupo 2 — pantallas de lista SIN el gesto

Pantallas que cargan datos pero no tienen `RefreshIndicator`.

**Files (modificar):**
- `lib/presentation/screens/host/products/host_product_list_screen.dart`
- `lib/presentation/screens/member/member_products_screen.dart`
- `lib/presentation/screens/member/club_selector_screen.dart`
- `lib/presentation/screens/guest/guest_flavor_catalog.dart`
- `lib/presentation/screens/host/products/host_product_sabores_screen.dart`

- [ ] **Paso 1: `member_products_screen.dart`** (caso canónico: loading/error/empty/list)
  - Import del widget.
  - Error (~78-99): Receta 2, `onRefresh: _loadProducts`.
  - Vacío `_products.isEmpty` (~102-120): Receta 2, `onRefresh: _loadProducts`.
  - `ListView.builder` (~121): Receta 1 → envolver en `RefreshIndicator(onRefresh: _loadProducts, color: AppTheme.primaryColor, child: ...)` + `physics: const AlwaysScrollableScrollPhysics()`.

- [ ] **Paso 2: `host_product_list_screen.dart`**
  - Import del widget.
  - Body usa `Consumer<ProductProvider>` (~179) y `ListView.builder` (~259) para productos + sección combos. Definir un `Future<void> _refresh()` que combine recarga de productos y combos:
    ```dart
    Future<void> _refresh() async {
      if (_hubId != null && _clubId != null) {
        await Provider.of<ProductProvider>(context, listen: false)
            .loadProducts(hubId: _hubId!, clubId: _clubId!);
      }
      await _loadCombos();
    }
    ```
  - Envolver el contenido scrolleable principal con `RefreshIndicator(onRefresh: _refresh, color: AppTheme.primaryColor, ...)`.
  - Donde el body sea un `ListView`/`SingleChildScrollView`, agregar `physics: const AlwaysScrollableScrollPhysics()`.
  - Estado vacío `products.isEmpty` (~248): si no queda bajo un scrollable deslizable, usar Receta 2 con `onRefresh: _refresh`.

- [ ] **Paso 3: `club_selector_screen.dart`**
  - Import del widget.
  - Error (~127-160, con botón "onPressed: _loadClubs"): Receta 2, `onRefresh: _loadClubs`.
  - `_buildListView()` `ListView.builder` (~246): Receta 1 → `RefreshIndicator(onRefresh: _loadClubs, ...)` + `physics`.
  - Vacío (si existe rama): Receta 2, `onRefresh: _loadClubs`.

- [ ] **Paso 4: `guest_flavor_catalog.dart`**
  - Import del widget.
  - Body `isLoading ? ... : GridView.builder` (~30-34): Receta 1 sobre el `GridView.builder` → `RefreshIndicator(onRefresh: <cargador de sabores>, ...)` + `physics: const AlwaysScrollableScrollPhysics()`. Verificar el nombre del método de carga al leer el archivo.
  - Si hay rama de error/vacío: Receta 2.

- [ ] **Paso 5: `host_product_sabores_screen.dart`**
  - Import del widget.
  - Error (~116-129, botón "onPressed: _loadSabores"): Receta 2, `onRefresh: _loadSabores`.
  - La lista de sabores: Receta 1 (`RefreshIndicator(onRefresh: _loadSabores, ...)` + `physics`). Si el body es `SingleChildScrollView`, aplicar Receta 3.

- [ ] **Paso 6: Verificar y commitear**

```bash
flutter analyze lib/presentation/screens/host/products/host_product_list_screen.dart lib/presentation/screens/member/member_products_screen.dart lib/presentation/screens/member/club_selector_screen.dart lib/presentation/screens/guest/guest_flavor_catalog.dart lib/presentation/screens/host/products/host_product_sabores_screen.dart
```
Expected: No issues nuevos.

```bash
git add lib/presentation/screens/host/products/host_product_list_screen.dart lib/presentation/screens/member/member_products_screen.dart lib/presentation/screens/member/club_selector_screen.dart lib/presentation/screens/guest/guest_flavor_catalog.dart lib/presentation/screens/host/products/host_product_sabores_screen.dart
git commit -m "feat: agregar pull-to-refresh a listas de productos, clubes y sabores"
```

---

## Fase 5: Grupo 2 — dashboards y detalles SIN el gesto

**Files (modificar):**
- `lib/presentation/screens/host/members/host_member_detail_screen.dart`
- `lib/presentation/screens/host/pre_socios/host_pre_socio_detail_screen.dart`
- `lib/presentation/screens/guest/guest_club_detail_screen.dart`
- `lib/presentation/screens/host/host_dashboard_screen.dart`
- `lib/presentation/screens/host/host_reports_screen.dart`
- `lib/presentation/screens/member/member_home_screen.dart`

- [ ] **Paso 1: `host_dashboard_screen.dart`**
  - Body `SingleChildScrollView` (~114): Receta 3, `onRefresh: _loadOrdersSummary`.

- [ ] **Paso 2: `member_home_screen.dart`**
  - Body `Consumer<UserProvider>` (~71). Envolver el contenido scrolleable interno con `RefreshIndicator(onRefresh: _loadLoyaltyData, ...)`; si el contenido es un `SingleChildScrollView`/`ListView`, agregar `physics: const AlwaysScrollableScrollPhysics()`. Si es un `Column` no scrolleable, usar Receta 3 envolviéndolo en `SingleChildScrollView` + `RefreshIndicator`.

- [ ] **Paso 3: `host_member_detail_screen.dart`**
  - Tiene `_loadAll()` (attendances, purchases, referidos, combo). Body con secciones. Envolver el scroll principal con `RefreshIndicator(onRefresh: _loadAll, ...)` (Receta 3 si es `SingleChildScrollView`). Forzar `physics`.

- [ ] **Paso 4: `host_pre_socio_detail_screen.dart`**
  - Body `SingleChildScrollView` (~84) con `_load()`: Receta 3, `onRefresh: _load`.

- [ ] **Paso 5: `guest_club_detail_screen.dart`**
  - Body `SingleChildScrollView` (~84) con `_loadDetails()`: Receta 3, `onRefresh: _loadDetails`.

- [ ] **Paso 6: `host_reports_screen.dart`**
  - Body `Stack` (~168) con `_cargarClub()` + carga de reportes. Identificar el contenido scrolleable principal dentro del `Stack` (probable `SingleChildScrollView`/`ListView`) y aplicar `RefreshIndicator(onRefresh: <recarga reportes>, ...)` + `physics`. Verificar el método de recarga al leer el archivo (combinar `_cargarClub` + carga de reportes si aplica).

- [ ] **Paso 7: Verificar y commitear**

```bash
flutter analyze lib/presentation/screens/host/members/host_member_detail_screen.dart lib/presentation/screens/host/pre_socios/host_pre_socio_detail_screen.dart lib/presentation/screens/guest/guest_club_detail_screen.dart lib/presentation/screens/host/host_dashboard_screen.dart lib/presentation/screens/host/host_reports_screen.dart lib/presentation/screens/member/member_home_screen.dart
```
Expected: No issues nuevos.

```bash
git add lib/presentation/screens/host/members/host_member_detail_screen.dart lib/presentation/screens/host/pre_socios/host_pre_socio_detail_screen.dart lib/presentation/screens/guest/guest_club_detail_screen.dart lib/presentation/screens/host/host_dashboard_screen.dart lib/presentation/screens/host/host_reports_screen.dart lib/presentation/screens/member/member_home_screen.dart
git commit -m "feat: agregar pull-to-refresh a dashboards y pantallas de detalle"
```

---

## Fase 6: Verificación final

- [ ] **Paso 1: Análisis completo del proyecto**

Run: `flutter analyze`
Expected: No issues nuevos respecto al baseline de `main`.

- [ ] **Paso 2: Tests**

Run: `flutter test`
Expected: PASS (incluye el test del widget + tests de entidades existentes).

- [ ] **Paso 3: Smoke build (opcional, lo decide el usuario)**

Run: `flutter build apk --debug` (o ejecutar la app en un dispositivo/emulador y probar el gesto en 2-3 pantallas: una lista con datos, una vacía y una con error).

- [ ] **Paso 4: Commit final (si hubo ajustes)**

```bash
git add -A
git commit -m "chore: verificación final pull-to-refresh"
```

---

## Resumen de cobertura (checklist contra el inventario)

**Grupo 1 — arreglo vacío/error (10):**
- [ ] host_orders_list_screen
- [ ] events_list_screen
- [ ] member_attendance_screen
- [ ] member_orders_list_screen
- [ ] host_members_list_screen
- [ ] host_pre_socios_list_screen
- [ ] member_select_club_screen
- [ ] member_club_products_screen
- [ ] host_referral_tree_screen
- [ ] support_center_screen

**Grupo 2 — agregar el gesto (11):**
- [ ] host_product_list_screen
- [ ] member_products_screen
- [ ] club_selector_screen
- [ ] guest_flavor_catalog
- [ ] host_product_sabores_screen
- [ ] host_member_detail_screen
- [ ] host_pre_socio_detail_screen
- [ ] guest_club_detail_screen
- [ ] host_dashboard_screen
- [ ] host_reports_screen
- [ ] member_home_screen

**Infra:**
- [ ] RefreshableScrollView + test
