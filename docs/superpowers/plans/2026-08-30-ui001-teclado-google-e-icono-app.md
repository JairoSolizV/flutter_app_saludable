# UI-001 (teclado tras login con Google) + icono de la app — Plan de implementación

> **Para agentes:** SUB-SKILL REQUERIDA: usar `superpowers:subagent-driven-development` (recomendado) o `superpowers:executing-plans` para ejecutar este plan tarea por tarea. Los pasos usan checkbox (`- [ ]`) para el seguimiento.

**Goal:** Cerrar el teclado al iniciar sesión con Google (UI-001) y reemplazar el icono por defecto de Flutter por el isotipo "X" de Expande en el lanzador de Android e iOS.

**Architecture:** Dos cambios independientes en el mismo repo (`flutter_app_saludable`), sin tocar el backend de Google ni `GoogleAuthService`. (1) Un helper sin `BuildContext` — `dismissKeyboard()` — que suelta el foco global; se llama en `login_screen.dart` justo antes de abrir el selector nativo de cuentas y otra vez al volver de él, antes de navegar. (2) Generación de los iconos de lanzador con `flutter_launcher_icons` a partir de dos PNG 1024×1024 derivados del icono ya aprobado de Play Store, uno recuadrado para el icono legacy/iOS y otro dimensionado para la zona segura del *adaptive icon* de Android.

**Tech Stack:** Flutter 3.41.9 / Dart 3.11.5 · `go_router` 13 · `provider` 6 · `google_sign_in` 6.2.1 · `flutter_launcher_icons` (nueva dev_dependency) · PowerShell + System.Drawing para generar los PNG fuente (sin dependencias externas en Windows).

---

## Contexto y diagnóstico

### UI-001 — por qué se queda el teclado abierto

Ruta del código: [login_screen.dart:230-268](../../../lib/presentation/screens/auth/login_screen.dart#L230).

```dart
onPressed: auth.isLoading ? null : () async {
  final success = await auth.loginWithGoogle();   // ← abre una activity nativa
  if (success && context.mounted) {
    ...
    context.go('/basic-home');                    // ← cambia de ruta
  }
},
```

Secuencia real en el dispositivo:

1. El usuario toca el campo **Correo Electrónico** → el `EditableText` toma el foco → se abre el teclado.
2. Toca **Iniciar con Google**. Tocar un `OutlinedButton` no suelta el foco del `TextFormField`: el campo sigue enfocado.
3. `GoogleSignIn.signIn()` lanza el selector nativo de cuentas (otra activity). La app pasa a segundo plano.
4. Al volver a primer plano, Android restaura el foco de la vista que lo tenía y el `InputMethodManager` vuelve a mostrar el teclado.
5. Inmediatamente después, `context.go(...)` reemplaza la ruta. El teclado ya está arriba y queda encima de la pantalla destino.

Es decir: **no es un problema de `go_router`, es el foco vivo del `TextField` cuando la app se reanuda.** Por eso el arreglo tiene que soltar el foco *antes* de lanzar el flujo nativo (paso 3), y por robustez otra vez *después* del `await` (paso 5).

Verificado en el repo:

- `lib/presentation/screens/auth/login_screen.dart` es el **único** sitio que llama a `auth.loginWithGoogle()` (`grep -rn "loginWithGoogle" lib`). No hay botón de Google en el registro.
- En todo `lib/` solo existe **una** llamada a `unfocus()`, en `register_screen.dart:320`, dentro de un `onFieldSubmitted`. No hay ningún manejo global de foco al navegar.
- `_emailCtrl` y `_passCtrl` de `LoginScreen` **no se liberan** en un `dispose()` (la clase no lo declara). Es un fallo aparte; ver "Hallazgos adyacentes".

### Icono de la app — estado actual

- `AndroidManifest.xml` ya apunta a `android:icon="@mipmap/ic_launcher"` y `android:label="Expande"`. **No hay que tocar el manifest.**
- Los cinco `android/app/src/main/res/mipmap-*/ic_launcher.png` son los **iconos por defecto de Flutter** (442 a 1443 bytes, fecha de creación del proyecto). Igual en `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **No existe** `mipmap-anydpi-v26/`: la app no tiene *adaptive icon*, obligatorio para verse bien desde Android 8. `minSdk` efectivo del proyecto = **24** (`flutter.minSdkVersion` en Flutter 3.41.9).
- No existe `android/app/src/main/res/values/colors.xml`, así que `flutter_launcher_icons` lo creará sin pisar nada (`values/` solo tiene `styles.xml`).

### Fuente gráfica elegida

| Archivo | Tamaño | Contenido |
|---|---|---|
| `../play_store_assets/icono_512.png` | 512×512 PNG | Isotipo "X" sobre blanco — **es el icono ya aprobado en Play Console** |
| `assets/images/expande_logo.jpg` | 709×444 JPG | Mismo isotipo, sin recuadrar (lo usa el splash) |
| `../LogoQuillo.jpg` | 1600×391 JPG | Lockup horizontal "X + EXPANDE" (no sirve de icono) |

Se usa **`icono_512.png`**: garantiza que el icono del lanzador y el de la ficha de Play sean el mismo dibujo.

Medidas reales sobre `icono_512.png` (calculadas con System.Drawing, umbral < 235 por canal):

- Fondo: **#FFFFFF puro** en las esquinas (una banda casi imperceptible a #FEFEFE en el borde izquierdo).
- Caja del isotipo: `x 134..378`, `y 153..373` → **245 × 221 px**, centro en `(256, 263)`.
- **Radio máximo del isotipo desde el centro de su caja: 162.9 px**, o sea `R/W = 0.318`.

De ahí salen los dos derivados 1024×1024 (el radio es lo que importa, no el ancho, porque la "X" llega a las esquinas de su caja):

| Salida | Fracción `R/W` objetivo | Escala vs. fuente | Caja del isotipo resultante | Para qué |
|---|---|---|---|---|
| `app_icon.png` | 0.40 | ×2.514 | 616 × 556 px | Icono legacy Android (mipmaps) + iOS |
| `app_icon_foreground.png` | 0.30 | ×1.886 | 462 × 417 px | Capa *foreground* del adaptive icon |

El 0.30 no es arbitrario: la zona segura de un adaptive icon es un círculo de 66 dp dentro de una capa de 108 dp, es decir **radio ≤ 0.305 × ancho**. Con la imagen tal cual (`R/W = 0.318`) la punta de la flecha superior derecha quedaría **fuera** del círculo y se cortaría en los lanzadores con máscara circular.

### Decisiones de alcance

- **No se toca `GoogleAuthService` ni `AuthProvider`.** El arreglo es puramente de UI, como pidió el reporte.
- **No se añade `dismissKeyboard()` al botón INGRESAR.** Ahí no hay activity nativa de por medio, así que no existe el bug; y si el login falla conviene que el teclado siga abierto para reescribir la contraseña.
- **No se añade un `NavigatorObserver` global** que suelte el foco en cada `didPush`/`didReplace`. Arreglaría de golpe toda la app, pero es un cambio de comportamiento en las ~50 rutas del router y no hay tests que cubran esa superficie. Queda anotado como mejora futura.
- **El fondo del adaptive icon será `#FFFFFF` y la capa foreground se deja opaca (blanca).** Recortar el blanco a transparencia produciría halos en los bordes antialiaseados; como el color de fondo es exactamente el mismo blanco, dejarla opaca se ve idéntico y sin artefactos.

---

## Estructura de archivos

**Crear:**

| Archivo | Responsabilidad |
|---|---|
| `lib/core/utils/keyboard.dart` | Único punto que cierra el teclado (`dismissKeyboard()`). Sin `BuildContext`, seguro tras un `await`. |
| `test/presentation/screens/login_screen_google_keyboard_test.dart` | Test de regresión de UI-001. |
| `tool/generate_app_icon.ps1` | Genera los dos PNG fuente 1024×1024 desde el icono de Play. Reproducible. |
| `tool/measure_icon_bbox.ps1` | Mide la caja del isotipo dentro de un PNG. Verifica escalas y zona segura. |
| `assets/icon/source_isotipo_512.png` | Copia dentro del repo del icono de Play (fuente del script). |
| `assets/icon/app_icon.png` | 1024×1024 — icono legacy + iOS (generado). |
| `assets/icon/app_icon_foreground.png` | 1024×1024 — foreground del adaptive icon (generado). |
| `test/app_icon_assets_test.dart` | Test estático que verifica que los iconos generados existen y tienen las dimensiones correctas. |

**Modificar:**

| Archivo | Cambio |
|---|---|
| `test/core/auth/fake_google_auth_service.dart` | Añadir `signIn()` con hook `onSignIn` para observar el estado durante el flujo nativo. |
| `lib/presentation/screens/auth/login_screen.dart:230-268` | Dos llamadas a `dismissKeyboard()` alrededor de `auth.loginWithGoogle()` + el import. |
| `pubspec.yaml` | `flutter_launcher_icons` en `dev_dependencies`, bloque de configuración, y `version: 1.0.0+6` → `1.0.0+7`. |

**Generados por `flutter_launcher_icons` (se commitean, no se editan a mano):**

- `android/app/src/main/res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png`
- `android/app/src/main/res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher_foreground.png`
- `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`
- `android/app/src/main/res/values/colors.xml`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png`

---

## Tarea 0: Rama de trabajo

- [ ] **Paso 1: Partir de `main` limpio y crear la rama**

Comprobado al escribir el plan: `git status --short` no devuelve nada y la rama activa es `main`.

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/flutter_app_saludable" && git checkout main && git pull && git checkout -b fix/ui-001-teclado-e-icono-app
```

Esperado: `Switched to a new branch 'fix/ui-001-teclado-e-icono-app'`.

---

## Tarea 1: Test que reproduce UI-001 (rojo)

**Files:**
- Modify: `test/core/auth/fake_google_auth_service.dart`
- Create: `test/presentation/screens/login_screen_google_keyboard_test.dart`

El truco del test: el fake de Google recibe un callback `onSignIn` que se ejecuta **mientras el "selector nativo" está en pantalla**. Ahí se lee `tester.testTextInput.isVisible`. Es la única aserción que distingue el bug: al final del flujo el teclado se cierra igual por el cambio de ruta, así que comprobar solo el estado final **no** detectaría la regresión.

El fake cede un turno del event loop (`Future.delayed(Duration.zero)`) antes de invocar el callback, imitando el salto a la activity nativa y dando al framework la oportunidad de procesar el `unfocus`.

- [ ] **Paso 1: Ampliar el fake de Google**

Reemplazar el contenido completo de `test/core/auth/fake_google_auth_service.dart` por:

```dart
import 'package:flutter_app_saludable/core/auth/google_auth_service.dart';

/// Fake inyectable en [AuthProvider] para los tests de logout Google (AUTH-022)
/// y del cierre de teclado en el login con Google (UI-001).
class FakeGoogleAuthService extends GoogleAuthService {
  FakeGoogleAuthService({
    this.throwOnSignOut = false,
    this.idToken,
    this.onSignIn,
  });

  int signOutCalls = 0;
  bool throwOnSignOut;

  /// idToken que devuelve [signIn]. `null` simula que el usuario canceló.
  final String? idToken;

  /// Se ejecuta dentro de [signIn], en el momento en que el selector nativo de
  /// cuentas estaría en pantalla. Permite observar el estado del teclado justo
  /// ahí, que es donde se manifiesta UI-001.
  final Future<void> Function()? onSignIn;

  int signInCalls = 0;

  @override
  Future<String?> signIn() async {
    signInCalls++;
    // Imita el salto a la activity nativa: cede un turno del event loop para
    // que el framework procese el unfocus antes de leer el estado.
    await Future<void>.delayed(Duration.zero);
    await onSignIn?.call();
    return idToken;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (throwOnSignOut) {
      throw StateError('Google signOut failed');
    }
  }
}
```

- [ ] **Paso 2: Comprobar que los tests existentes del fake siguen pasando**

`auth_provider_google_logout_test.dart` construye `FakeGoogleAuthService()` sin argumentos, así que los parámetros nuevos son opcionales y no rompen nada.

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/flutter_app_saludable" && flutter test test/core/auth/auth_provider_google_logout_test.dart
```

Esperado: `All tests passed!`

- [ ] **Paso 3: Escribir el test de regresión**

Crear `test/presentation/screens/login_screen_google_keyboard_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/core/auth/secure_token_store.dart';
import 'package:flutter_app_saludable/data/datasources/remote/auth_remote_data_source.dart';
import 'package:flutter_app_saludable/domain/entities/user.dart';
import 'package:flutter_app_saludable/presentation/providers/auth_provider.dart';
import 'package:flutter_app_saludable/presentation/providers/user_provider.dart';
import 'package:flutter_app_saludable/presentation/screens/auth/login_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/auth/fake_google_auth_service.dart';
import '../../core/auth/fake_user_repository.dart';
import '../../core/auth/in_memory_secure_storage_gateway.dart';

class _GoogleLoginRemote implements AuthRemoteDataSource {
  @override
  Future<User> loginWithGoogle(String idToken) async => User(
        id: '1',
        name: 'Google User',
        email: 'google@test.com',
        role: 'basic_user',
        token: 'jwt-google',
      );

  @override
  Future<User> getMe() async => User(
        id: '1',
        name: 'Google User',
        email: 'google@test.com',
        role: 'basic_user',
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pumpLoginScreen(
  WidgetTester tester,
  FakeGoogleAuthService google,
) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final storage = InMemorySecureStorageGateway();
  final tokenStore = SecureTokenStore(storage: storage);
  await tokenStore.initialize();
  final users = FakeUserRepository();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            _GoogleLoginRemote(),
            users,
            tokenStore,
            googleAuthService: google,
          ),
        ),
        ChangeNotifierProvider(create: (_) => UserProvider(users)),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/login',
          routes: [
            GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
            GoRoute(
              path: '/basic-home',
              builder: (_, __) => const Scaffold(body: Text('Basic Home')),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _googleButton() =>
    find.widgetWithText(OutlinedButton, 'Iniciar con Google');

void main() {
  group('LoginScreen UI-001 — teclado y login con Google', () {
    testWidgets('el teclado ya está cerrado cuando se abre el selector de Google',
        (tester) async {
      bool? tecladoVisibleDuranteSignIn;
      final google = FakeGoogleAuthService(
        idToken: 'google-id-token',
        onSignIn: () async {
          tecladoVisibleDuranteSignIn = tester.testTextInput.isVisible;
        },
      );

      await _pumpLoginScreen(tester, google);

      // El usuario estaba escribiendo el correo antes de tocar el botón.
      await tester.showKeyboard(find.byType(TextFormField).first);
      await tester.pump();
      expect(
        tester.testTextInput.isVisible,
        isTrue,
        reason: 'el escenario debe partir con el teclado abierto',
      );

      await tester.tap(_googleButton());
      await tester.pumpAndSettle();

      expect(google.signInCalls, 1);
      expect(
        tecladoVisibleDuranteSignIn,
        isFalse,
        reason:
            'UI-001: si el campo sigue enfocado, Android reabre el teclado al '
            'volver del selector nativo y queda sobre la pantalla destino',
      );
      expect(tester.testTextInput.isVisible, isFalse);
      expect(find.text('Basic Home'), findsOneWidget);
    });

    testWidgets('si el usuario cancela, el teclado queda cerrado y seguimos en login',
        (tester) async {
      final google = FakeGoogleAuthService(idToken: null);

      await _pumpLoginScreen(tester, google);

      await tester.showKeyboard(find.byType(TextFormField).first);
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);

      await tester.tap(_googleButton());
      await tester.pumpAndSettle();

      expect(google.signInCalls, 1);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(find.text('Basic Home'), findsNothing);
      expect(_googleButton(), findsOneWidget);
    });
  });
}
```

- [ ] **Paso 4: Ejecutar el test y comprobar que FALLA**

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/flutter_app_saludable" && flutter test test/presentation/screens/login_screen_google_keyboard_test.dart
```

Esperado: los **dos** tests fallan con `Expected: <false>  Actual: <true>` sobre `tecladoVisibleDuranteSignIn` / `tester.testTextInput.isVisible`. Es la reproducción de UI-001.

- [ ] **Paso 5: Commit del test en rojo**

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/flutter_app_saludable" && git add test/core/auth/fake_google_auth_service.dart test/presentation/screens/login_screen_google_keyboard_test.dart && git commit -m "test: reproducir UI-001 (teclado abierto durante el login con Google)"
```

---

## Tarea 2: Arreglar UI-001 (verde)

**Files:**
- Create: `lib/core/utils/keyboard.dart`
- Modify: `lib/presentation/screens/auth/login_screen.dart`
- Test: `test/presentation/screens/login_screen_google_keyboard_test.dart` (ya escrito en la Tarea 1)

- [ ] **Paso 1: Crear el helper**

Crear `lib/core/utils/keyboard.dart`:

```dart
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
```

- [ ] **Paso 2: Añadir el import en `login_screen.dart`**

En la cabecera de `lib/presentation/screens/auth/login_screen.dart`, después de `import 'package:flutter_app_saludable/core/utils/input_formatters.dart';`, añadir:

```dart
import 'package:flutter_app_saludable/core/utils/keyboard.dart';
```

- [ ] **Paso 3: Envolver la llamada a Google con `dismissKeyboard()`**

En `lib/presentation/screens/auth/login_screen.dart`, dentro del `OutlinedButton.icon` de Google, sustituir:

```dart
                              onPressed: auth.isLoading ? null : () async {
                                final success = await auth.loginWithGoogle();
                                if (success && context.mounted) {
```

por:

```dart
                              onPressed: auth.isLoading ? null : () async {
                                // UI-001: soltar el foco ANTES de abrir el
                                // selector nativo de cuentas; si un TextField
                                // sigue enfocado, Android reabre el teclado al
                                // volver a primer plano.
                                dismissKeyboard();
                                final success = await auth.loginWithGoogle();
                                // Al reanudar la app el sistema puede haber
                                // restaurado el foco: lo soltamos otra vez
                                // antes de cambiar de ruta.
                                dismissKeyboard();
                                if (success && context.mounted) {
```

El resto del `onPressed` (el `syncProfile`, el `setUser` y los tres `context.go`) queda **exactamente igual**.

- [ ] **Paso 4: Ejecutar el test y comprobar que PASA**

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/flutter_app_saludable" && flutter test test/presentation/screens/login_screen_google_keyboard_test.dart
```

Esperado: `All tests passed!` (2 tests).

- [ ] **Paso 5: Ejecutar analyze y la suite completa**

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/flutter_app_saludable" && flutter analyze && flutter test
```

Esperado: `No issues found!` y `All tests passed!`. Si `flutter analyze` ya emitía avisos antes del cambio, comparar contra `git stash` para confirmar que no se añadió ninguno nuevo.

- [ ] **Paso 6: Commit**

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/flutter_app_saludable" && git add lib/core/utils/keyboard.dart lib/presentation/screens/auth/login_screen.dart && git commit -m "fix(UI-001): cerrar el teclado al iniciar sesion con Google"
```

---

## Tarea 3: Copiar el icono de Play al repo como fuente

**Files:**
- Create: `assets/icon/source_isotipo_512.png`

El icono aprobado vive **fuera** del repo git (`C:\Users\Jairo\Documents\Flutter Quillo\play_store_assets\`). Se copia dentro para que la generación sea reproducible por cualquiera que clone el repo.

- [ ] **Paso 1: Crear la carpeta y copiar el archivo**

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/flutter_app_saludable" && mkdir -p assets/icon && cp "../play_store_assets/icono_512.png" assets/icon/source_isotipo_512.png && ls -l assets/icon
```

Esperado: `source_isotipo_512.png` de **75722 bytes**.

- [ ] **Paso 2: Confirmar que no se empaqueta en la app**

`pubspec.yaml` declara solo `assets/images/` en la sección `flutter: assets:`. `assets/icon/` **no** se declara, así que estos PNG son insumos de build y no engordan el APK. Verificar que sigue siendo así:

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/flutter_app_saludable" && grep -n -A3 "  assets:" pubspec.yaml
```

Esperado: solo la línea `    - assets/images/`.

- [ ] **Paso 3: Commit**

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/flutter_app_saludable" && git add assets/icon/source_isotipo_512.png && git commit -m "chore(icon): copiar al repo el isotipo aprobado de Play Store como fuente"
```

---

## Tarea 4: Script que genera los dos PNG fuente 1024×1024

**Files:**
- Create: `tool/generate_app_icon.ps1`
- Create (salida del script): `assets/icon/app_icon.png`, `assets/icon/app_icon_foreground.png`

- [ ] **Paso 1: Escribir el script**

Crear `tool/generate_app_icon.ps1`:

```powershell
# Genera las imagenes fuente del icono de la app a partir del isotipo aprobado
# de Play Store (assets/icon/source_isotipo_512.png).
#
#   assets/icon/app_icon.png             1024x1024, isotipo con R/W = 0.40
#                                        (icono legacy de Android + iOS)
#   assets/icon/app_icon_foreground.png  1024x1024, isotipo con R/W = 0.30,
#                                        dentro de la zona segura del adaptive
#                                        icon (circulo de 66dp sobre 108dp)
#
# Uso, desde la raiz de flutter_app_saludable:
#   powershell -ExecutionPolicy Bypass -File tool/generate_app_icon.ps1
#
# Requiere Windows (System.Drawing). Si algun dia hace falta en CI/Linux,
# reescribir con package:image de Dart.

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$repoRoot   = Split-Path -Parent $PSScriptRoot
$sourcePath = Join-Path $repoRoot 'assets\icon\source_isotipo_512.png'

if (-not (Test-Path $sourcePath)) {
    throw "No se encuentra la imagen fuente: $sourcePath"
}

# Medidas del isotipo dentro de source_isotipo_512.png (umbral < 235 por canal).
$Canvas    = 1024
$SrcX      = 134
$SrcY      = 153
$SrcW      = 245
$SrcH      = 221
$SrcRadius = 162.9   # distancia maxima del centro de la caja a un pixel del logo

$src = [System.Drawing.Bitmap]::FromFile($sourcePath)

function New-IconPng {
    param(
        [Parameter(Mandatory)][string]$OutPath,
        [Parameter(Mandatory)][double]$TargetRadiusFraction
    )

    $scale = ($TargetRadiusFraction * $Canvas) / $SrcRadius
    $dw = [int][math]::Round($SrcW * $scale)
    $dh = [int][math]::Round($SrcH * $scale)
    $dx = [int][math]::Round(($Canvas - $dw) / 2)
    $dy = [int][math]::Round(($Canvas - $dh) / 2)

    $bmp = New-Object System.Drawing.Bitmap(
        $Canvas, $Canvas,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    try {
        $g.Clear([System.Drawing.Color]::White)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

        $srcRect  = New-Object System.Drawing.Rectangle($SrcX, $SrcY, $SrcW, $SrcH)
        $destRect = New-Object System.Drawing.Rectangle($dx, $dy, $dw, $dh)
        $g.DrawImage($src, $destRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
    }
    finally {
        $g.Dispose()
    }

    $bmp.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "$OutPath  ->  isotipo ${dw}x${dh} en lienzo ${Canvas}x${Canvas}"
}

try {
    New-IconPng -OutPath (Join-Path $repoRoot 'assets\icon\app_icon.png') `
                -TargetRadiusFraction 0.40
    New-IconPng -OutPath (Join-Path $repoRoot 'assets\icon\app_icon_foreground.png') `
                -TargetRadiusFraction 0.30
}
finally {
    $src.Dispose()
}
```

- [ ] **Paso 2: Ejecutar el script**

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/flutter_app_saludable" && powershell -NoProfile -ExecutionPolicy Bypass -File tool/generate_app_icon.ps1
```

Esperado, literalmente estos dos tamaños:

```
...\assets\icon\app_icon.png  ->  isotipo 616x556 en lienzo 1024x1024
...\assets\icon\app_icon_foreground.png  ->  isotipo 462x417 en lienzo 1024x1024
```

- [ ] **Paso 3: Escribir el script de medición**

Se usa dos veces: aquí, para verificar los PNG fuente, y en la Tarea 5 para comprobar el foreground que genera `flutter_launcher_icons`.

Crear `tool/measure_icon_bbox.ps1`:

```powershell
# Mide la caja (bounding box) del isotipo dentro de una imagen de icono.
# Sirve para verificar que el logo cae dentro de la zona segura del adaptive
# icon y que las escalas del generador son las esperadas.
#
# Uso, desde la raiz de flutter_app_saludable:
#   powershell -ExecutionPolicy Bypass -File tool/measure_icon_bbox.ps1 <ruta.png> [<ruta.png> ...]

param([Parameter(Mandatory, ValueFromRemainingArguments)][string[]]$Paths)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

foreach ($path in $Paths) {
    $full = (Resolve-Path $path).Path
    $bmp  = [System.Drawing.Bitmap]::FromFile($full)
    try {
        $minX = [int]::MaxValue; $maxX = -1
        $minY = [int]::MaxValue; $maxY = -1

        for ($y = 0; $y -lt $bmp.Height; $y++) {
            for ($x = 0; $x -lt $bmp.Width; $x++) {
                $c = $bmp.GetPixel($x, $y)
                # Pixel "del logo": opaco y claramente mas oscuro que el blanco.
                if ($c.A -gt 16 -and (($c.R -lt 235) -or ($c.G -lt 235) -or ($c.B -lt 235))) {
                    if ($x -lt $minX) { $minX = $x }
                    if ($x -gt $maxX) { $maxX = $x }
                    if ($y -lt $minY) { $minY = $y }
                    if ($y -gt $maxY) { $maxY = $y }
                }
            }
        }

        if ($maxX -lt 0) {
            Write-Host "$path : lienzo $($bmp.Width)x$($bmp.Height)  SIN PIXELES DE LOGO"
            continue
        }

        $w  = $maxX - $minX + 1
        $h  = $maxY - $minY + 1
        $cx = [int](($minX + $maxX) / 2)
        $cy = [int](($minY + $maxY) / 2)
        Write-Host "$path : lienzo $($bmp.Width)x$($bmp.Height)  caja del isotipo ${w}x${h}  centro ${cx},${cy}"
    }
    finally {
        $bmp.Dispose()
    }
}
```

- [ ] **Paso 4: Verificar los dos PNG generados**

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/flutter_app_saludable" && powershell -NoProfile -ExecutionPolicy Bypass -File tool/measure_icon_bbox.ps1 assets/icon/app_icon.png assets/icon/app_icon_foreground.png
```

Esperado (tolerancia ±2 px por el antialiasing del reescalado):

```
assets/icon/app_icon.png : lienzo 1024x1024  caja del isotipo 616x556  centro 511,511
assets/icon/app_icon_foreground.png : lienzo 1024x1024  caja del isotipo 462x417  centro 511,511
```

Si el centro no sale en `511,511` (±2), el isotipo no quedó centrado: revisar los valores `$SrcX/$SrcY/$SrcW/$SrcH` de `tool/generate_app_icon.ps1`.

- [ ] **Paso 5: Mirar los dos PNG a ojo**

Abrirlos y confirmar: la "X" con la flecha verde centrada sobre blanco, sin recortes, sin bordes grises, y en `app_icon_foreground.png` claramente más pequeña que en `app_icon.png`.

- [ ] **Paso 6: Commit**

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/flutter_app_saludable" && git add tool/generate_app_icon.ps1 tool/measure_icon_bbox.ps1 assets/icon/app_icon.png assets/icon/app_icon_foreground.png && git commit -m "chore(icon): generar PNG fuente 1024x1024 del isotipo Expande"
```

---

## Tarea 5: Generar los iconos de lanzador con flutter_launcher_icons

**Files:**
- Modify: `pubspec.yaml`
- Generados: `android/app/src/main/res/mipmap-*/`, `android/app/src/main/res/values/colors.xml`, `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

- [ ] **Paso 1: Añadir la dependencia de desarrollo**

En `pubspec.yaml`, dentro de `dev_dependencies:`, después de `sqflite_common_ffi: ^2.4.0+3`, añadir:

```yaml
  # Generación de los iconos de lanzador (ver tool/generate_app_icon.ps1)
  flutter_launcher_icons: ^0.14.3
```

- [ ] **Paso 2: Añadir el bloque de configuración**

En `pubspec.yaml`, al final del archivo (después de toda la sección `flutter:`), añadir un bloque **de primer nivel**:

```yaml
# Iconos de lanzador. Las dos imágenes fuente las produce
# tool/generate_app_icon.ps1 a partir de assets/icon/source_isotipo_512.png.
# Regenerar con:  dart run flutter_launcher_icons
flutter_launcher_icons:
  android: "ic_launcher"
  ios: true
  remove_alpha_ios: true
  image_path: "assets/icon/app_icon.png"
  adaptive_icon_background: "#FFFFFF"
  adaptive_icon_foreground: "assets/icon/app_icon_foreground.png"
  # El foreground ya viene dimensionado para la zona segura (R/W = 0.30),
  # así que no queremos que la herramienta lo encoja otra vez.
  adaptive_icon_foreground_inset: 0
  min_sdk_android: 24
```

- [ ] **Paso 3: Instalar y generar**

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/flutter_app_saludable" && flutter pub get && dart run flutter_launcher_icons
```

Esperado: líneas `✓ Successfully generated launcher icons` para Android e iOS, sin errores.

- [ ] **Paso 4: Comprobar qué archivos aparecieron**

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/flutter_app_saludable" && git status --short && echo "--- anydpi ---" && cat android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml && echo "--- colors ---" && cat android/app/src/main/res/values/colors.xml```

Esperado en `git status --short`, exactamente estos archivos (modificados o nuevos):

```
 M android/app/src/main/res/mipmap-hdpi/ic_launcher.png
 M android/app/src/main/res/mipmap-mdpi/ic_launcher.png
 M android/app/src/main/res/mipmap-xhdpi/ic_launcher.png
 M android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png
 M android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png
 M ios/Runner/Assets.xcassets/AppIcon.appiconset/... (varios)
 M pubspec.yaml
 M pubspec.lock
?? android/app/src/main/res/mipmap-anydpi-v26/
?? android/app/src/main/res/values/colors.xml
?? android/app/src/main/res/mipmap-*/ic_launcher_foreground.png
```

`ic_launcher.xml` esperado:

```xml
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
```

`colors.xml` esperado: un `<color name="ic_launcher_background">#FFFFFF</color>`.

`values/` solo contenía `styles.xml`, así que `colors.xml` es nuevo y no pisa nada.

- [ ] **Paso 5: Verificar que el `adaptive_icon_foreground_inset: 0` se aplicó**

Este es el punto que más fácil se puede desviar: algunas versiones de `flutter_launcher_icons` aplican un inset por defecto del 16 % y encogerían el isotipo una segunda vez.

Ejecutar `tool/measure_icon_bbox.ps1` (creado en la Tarea 4, paso 3) sobre el foreground generado:

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/flutter_app_saludable" && powershell -NoProfile -ExecutionPolicy Bypass -File tool/measure_icon_bbox.ps1 android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png
```

Esperado: `lienzo 432x432  caja del isotipo 195x176` (±6 px). Eso corresponde a `R/W = 0.30`, dentro del círculo seguro de radio `0.305 x 432 = 132 px`.

**Si en cambio sale una caja cercana a `164x148`**, la herramienta aplicó su inset del 16 % pese a la configuración. Remedio: en `tool/generate_app_icon.ps1` cambiar la llamada del foreground de `-TargetRadiusFraction 0.30` a `-TargetRadiusFraction 0.357` (0.30 ÷ 0.84), volver a ejecutar el script y repetir `dart run flutter_launcher_icons` y esta medición.

- [ ] **Paso 6: Mirar los iconos generados a ojo**

Abrir `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png` (192×192) y `mipmap-xxxhdpi/ic_launcher_foreground.png` (432×432) y confirmar que se ve la "X" de Expande, no el logo azul de Flutter.

- [ ] **Paso 7: Commit**

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/flutter_app_saludable" && git add pubspec.yaml pubspec.lock android/app/src/main/res ios/Runner/Assets.xcassets && git commit -m "feat(icon): usar el isotipo Expande como icono de la app (adaptive icon incluido)"
```

---

## Tarea 6: Test estático que protege los iconos

**Files:**
- Create: `test/app_icon_assets_test.dart`

Sigue el patrón ya usado en `test/android_release_security_test.dart`: aserciones sobre archivos del proyecto, sin widgets. Impide que una regeneración fallida o un `flutter create` accidental devuelvan el icono por defecto sin que nadie se entere.

Las dimensiones del PNG se leen de la cabecera IHDR (ancho en el offset 16, alto en el 20), así no hace falta ninguna dependencia nueva.

- [ ] **Paso 1: Escribir el test**

Crear `test/app_icon_assets_test.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// Lee ancho y alto de la cabecera IHDR de un PNG (offsets 16 y 20).
({int width, int height}) _pngSize(File file) {
  final bytes = file.readAsBytesSync();
  expect(
    bytes.length,
    greaterThan(24),
    reason: '${file.path} es demasiado corto para ser un PNG válido',
  );
  final data = ByteData.sublistView(Uint8List.fromList(bytes));
  return (width: data.getUint32(16), height: data.getUint32(20));
}

Directory _projectRoot() {
  var dir = Directory.current;
  while (!File('${dir.path}/pubspec.yaml').existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) {
      fail('No se encontró la raíz del proyecto (pubspec.yaml)');
    }
    dir = parent;
  }
  return dir;
}

void main() {
  final root = _projectRoot().path;
  final res = '$root/android/app/src/main/res';

  test('las imágenes fuente del icono están en el repo', () {
    for (final name in const [
      'source_isotipo_512.png',
      'app_icon.png',
      'app_icon_foreground.png',
    ]) {
      expect(
        File('$root/assets/icon/$name').existsSync(),
        isTrue,
        reason:
            'falta assets/icon/$name (regenerar con tool/generate_app_icon.ps1)',
      );
    }
    expect(_pngSize(File('$root/assets/icon/app_icon.png')).width, 1024);
    expect(
      _pngSize(File('$root/assets/icon/app_icon_foreground.png')).width,
      1024,
    );
  });

  test('los mipmaps de ic_launcher tienen las dimensiones de cada densidad', () {
    const esperado = <String, int>{
      'mdpi': 48,
      'hdpi': 72,
      'xhdpi': 96,
      'xxhdpi': 144,
      'xxxhdpi': 192,
    };
    esperado.forEach((densidad, lado) {
      final file = File('$res/mipmap-$densidad/ic_launcher.png');
      expect(file.existsSync(), isTrue, reason: 'falta ${file.path}');
      final size = _pngSize(file);
      expect(size.width, lado, reason: 'ancho de mipmap-$densidad');
      expect(size.height, lado, reason: 'alto de mipmap-$densidad');
    });
  });

  test('ic_launcher ya no es el icono por defecto de Flutter', () {
    // Los iconos que trae `flutter create` pesan entre 442 y 1443 bytes.
    // El isotipo Expande, con degradados, supera holgadamente los 5 KB.
    final file = File('$res/mipmap-xxxhdpi/ic_launcher.png');
    expect(
      file.lengthSync(),
      greaterThan(5000),
      reason: 'mipmap-xxxhdpi/ic_launcher.png parece seguir siendo el icono '
          'por defecto de Flutter; regenerar con '
          '`dart run flutter_launcher_icons`',
    );
  });

  test('existe el adaptive icon con fondo y foreground', () {
    final xml = File('$res/mipmap-anydpi-v26/ic_launcher.xml');
    expect(xml.existsSync(), isTrue, reason: 'falta ${xml.path}');
    final text = xml.readAsStringSync();
    expect(text.contains('<adaptive-icon'), isTrue);
    expect(text.contains('@color/ic_launcher_background'), isTrue);
    expect(text.contains('@mipmap/ic_launcher_foreground'), isTrue);

    final colors = File('$res/values/colors.xml');
    expect(colors.existsSync(), isTrue, reason: 'falta ${colors.path}');
    expect(colors.readAsStringSync().contains('ic_launcher_background'), isTrue);

    final foreground = File('$res/mipmap-xxxhdpi/ic_launcher_foreground.png');
    expect(foreground.existsSync(), isTrue, reason: 'falta ${foreground.path}');
    expect(_pngSize(foreground).width, 432);
  });

  test('el manifest sigue apuntando a @mipmap/ic_launcher', () {
    final manifest = File('$root/android/app/src/main/AndroidManifest.xml');
    final text = manifest.readAsStringSync();
    expect(text.contains('android:icon="@mipmap/ic_launcher"'), isTrue);
    expect(text.contains('android:label="Expande"'), isTrue);
  });

  test('el icono 1024 de iOS existe y mide 1024x1024', () {
    final file = File(
      '$root/ios/Runner/Assets.xcassets/AppIcon.appiconset/'
      'Icon-App-1024x1024@1x.png',
    );
    expect(file.existsSync(), isTrue, reason: 'falta ${file.path}');
    final size = _pngSize(file);
    expect(size.width, 1024);
    expect(size.height, 1024);
  });
}
```

- [ ] **Paso 2: Ejecutar el test**

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/flutter_app_saludable" && flutter test test/app_icon_assets_test.dart
```

Esperado: `All tests passed!` (6 tests).

- [ ] **Paso 3: Comprobar que el test detecta la regresión**

Restaurar temporalmente el icono por defecto y confirmar que el test se pone rojo:

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/flutter_app_saludable" && git show HEAD~1:android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png > android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png && flutter test test/app_icon_assets_test.dart
```

Esperado: falla el test `ic_launcher ya no es el icono por defecto de Flutter` con el mensaje `parece seguir siendo el icono por defecto de Flutter`.

Restaurar:

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/flutter_app_saludable" && git checkout -- android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png && flutter test test/app_icon_assets_test.dart && git status --short
```

Esperado: `All tests passed!` otra vez y `git status --short` sin cambios pendientes en `android/`.

- [ ] **Paso 4: Commit**

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/flutter_app_saludable" && git add test/app_icon_assets_test.dart && git commit -m "test: proteger los iconos de lanzador generados"
```

---

## Tarea 7: Subir el build number y verificar en dispositivo

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Paso 1: Subir el build number**

En `pubspec.yaml`, cambiar:

```yaml
version: 1.0.0+6
```

por:

```yaml
version: 1.0.0+7
```

Play Console rechaza una subida con un `versionCode` ya usado, y este cambio toca recursos que solo se ven reinstalando.

- [ ] **Paso 2: Ejecutar la suite completa**

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/flutter_app_saludable" && flutter analyze && flutter test
```

Esperado: `No issues found!` y `All tests passed!`.

- [ ] **Paso 3: Compilar e instalar en el teléfono**

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/flutter_app_saludable" && flutter build apk --debug
```

Esperado: `✓ Built build\app\outputs\flutter-apk\app-debug.apk`.

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/flutter_app_saludable" && flutter install
```

Nota: el build **release** (`flutter build appbundle`) exige el keystore; ver `docs/ANDROID_RELEASE_BUILD.md`. Para verificar el icono basta el debug.

- [ ] **Paso 4: Verificación manual del icono**

En el teléfono:

1. Ir al cajón de apps: la entrada **Expande** muestra la "X" azul-verde, no el logo de Flutter.
2. Mantener pulsado el icono: en la animación del adaptive icon la flecha verde **no se corta** por ningún borde.
3. Ver el icono en Ajustes → Aplicaciones y en la pantalla de apps recientes.

- [ ] **Paso 5: Verificación manual de UI-001**

En el teléfono, con la app recién instalada:

1. Abrir la pantalla de **Iniciar sesión**.
2. Tocar el campo **Correo Electrónico** → el teclado sube.
3. **Sin cerrar el teclado**, tocar **Iniciar con Google**.
4. Elegir una cuenta en el selector nativo.
5. Al aterrizar en `/basic-home`, `/member-home` o `/host-dashboard`, **el teclado no debe estar visible**.
6. Repetir cancelando el selector de cuentas (botón atrás): se vuelve al login y el teclado tampoco debe quedar abierto.

**Si en el paso 5 el teclado sigue apareciendo** (algunos fabricantes reabren el IME al reanudar aunque no haya foco), aplicar este refuerzo en `lib/core/utils/keyboard.dart`:

```dart
import 'package:flutter/services.dart';
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
  // Refuerzo para fabricantes que reabren el IME al reanudar la app aunque no
  // haya ningún campo enfocado.
  SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
}
```

Después volver a ejecutar `flutter test test/presentation/screens/login_screen_google_keyboard_test.dart` (debe seguir en verde) y repetir la verificación en el teléfono.

- [ ] **Paso 6: Commit**

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/flutter_app_saludable" && git add pubspec.yaml && git commit -m "chore: subir versionCode a 1.0.0+7 (icono nuevo y fix UI-001)"
```

- [ ] **Paso 7: Publicar la rama**

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/flutter_app_saludable" && git push -u origin fix/ui-001-teclado-e-icono-app
```

---

## Verificación final

- [ ] `flutter analyze` sin issues nuevos.
- [ ] `flutter test` completo en verde, incluidos los 2 tests de UI-001 y los 6 de iconos.
- [ ] Icono "X" de Expande visible en el lanzador, sin recortes en la máscara circular.
- [ ] Teclado cerrado al llegar a la pantalla destino tras el login con Google, y también al cancelarlo.
- [ ] `git log --oneline` muestra 7 commits en la rama, ninguno mezclando el arreglo de teclado con los iconos.

---

## Hallazgos adyacentes (fuera del alcance de este plan)

Detectados al revisar el código. No se tocan aquí; cada uno merece su propia tarea.

1. **`assets/images/google_logo.png` no existe.** `login_screen.dart:256` lo carga y cae siempre al `errorBuilder`, así que el botón de Google muestra el icono genérico `Icons.g_mobiledata` de Material en vez del logo de Google. `assets/images/` solo contiene `expande_logo.jpg`. Además, las *Google Sign-In Branding Guidelines* exigen el logo oficial en ese botón.

2. **`LoginScreen` no libera sus `TextEditingController`.** `_emailCtrl` y `_passCtrl` se crean como campos de `_LoginScreenState` y la clase no declara `dispose()`. Fuga en cada visita a la pantalla.

3. **Mismo patrón de UI-001 en otras pantallas con actividad nativa.** Cualquier pantalla con campos de texto que lance un flujo que saque la app a segundo plano puede reproducir el bug:
   - `lib/presentation/screens/host/products/host_product_proposal_screen.dart` — usa `ImagePicker` (galería/cámara) dentro de un formulario.
   - `lib/presentation/screens/host/host_scan_screen.dart` y `lib/presentation/screens/member/qrcode/member_qr_scan_screen.dart` — `MobileScanner` + `permission_handler`.

   La alternativa global sería un `NavigatorObserver` en `appRouter` que llame a `dismissKeyboard()` en `didPush`/`didReplace`; cubriría las ~50 rutas de una vez, pero necesita su propia tanda de tests.

4. **La fuente gráfica limita la nitidez del icono en iOS.** El isotipo original solo existe a ~245 px de ancho (`icono_512.png`) o ~275 px (`LogoQuillo.jpg`). Para los mipmaps de Android sobra, pero el icono 1024×1024 de iOS sale de una ampliación de ~2.5×. Si algún día se publica en App Store, conviene exportar el isotipo desde el vectorial original.

---

## Nota de ejecución (2026-08-30)

El plan se ejecutó completo en la rama `fix/ui-001-teclado-e-icono-app`. Tres cosas salieron distintas de lo previsto y el texto de arriba se dejó tal cual se escribió; esto es lo que pasó de verdad:

1. **`flutter analyze` nunca estuvo limpio.** El repo arrastra **154 issues preexistentes**, incluidos 2 *errors* en `test/data/datasources/remote/combo_qr_presocio_remote_test.dart` (parámetro `precio` ahora obligatorio, del commit `4f819c6`). Ese archivo no compila, así que `flutter test` termina en **875 pasan / 1 falla**. Comprobado con `git stash`: el conteo es idéntico con y sin los cambios de este plan, así que no se añadió ningún issue nuevo. Queda como tarea aparte.

2. **`flutter_launcher_icons` v0.14.4 pone el foreground en `drawable-*/`, no en `mipmap-*/`.** El XML generado es:

   ```xml
   <adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
     <background android:drawable="@color/ic_launcher_background"/>
     <foreground>
         <inset android:drawable="@drawable/ic_launcher_foreground" android:inset="0%" />
     </foreground>
   </adaptive-icon>
   ```

   `test/app_icon_assets_test.dart` se escribió contra esta realidad (`@drawable/…` y `drawable-xxxhdpi/`), y se le añadió un séptimo test que verifica que el `android:inset` es `0%` — el `adaptive_icon_foreground_inset: 0` **sí** se respetó.

3. **La herramienta modificó `ios/Runner.xcodeproj/project.pbxproj` sin motivo**, cambiando `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS` de `YES` a `AppIcon` en las dos configuraciones. Ese ajuste de Xcode espera un booleano, así que el cambio es incorrecto: se revirtió con `git checkout --` antes de commitear.

Mediciones reales obtenidas (todas dentro de la tolerancia prevista):

| Archivo | Lienzo | Caja del isotipo | Centro |
|---|---|---|---|
| `assets/icon/app_icon.png` | 1024×1024 | 614×556 | 512,512 |
| `assets/icon/app_icon_foreground.png` | 1024×1024 | 461×417 | 511,512 |
| `res/drawable-xxxhdpi/ic_launcher_foreground.png` | 432×432 | 195×177 | 216,216 |
| `res/mipmap-xxxhdpi/ic_launcher.png` | 192×192 | 116×105 | 96,96 |

`flutter build apk --debug` compila y el APK contiene los cinco `mipmap-*/ic_launcher.png`, los cinco `drawable-*/ic_launcher_foreground.png` y `mipmap-anydpi-v26/ic_launcher.xml`.

**Pendiente:** los pasos 4 y 5 de la Tarea 7 (verificación visual del icono y del teclado en el teléfono). No había ningún dispositivo Android conectado al ejecutar el plan.
