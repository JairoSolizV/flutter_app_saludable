# Guía de build Android release — NutriLife Club (VULN-FL-04)

Documento operativo para firmar, ofuscar y publicar la app Flutter
`flutter_app_saludable` (`applicationId`: `com.nutrilife.club`).

**No incluye secretos reales.** El keystore de producción pertenece al proyecto
o a la empresa; Cursor y el repositorio no lo generan ni lo versionan.

---

## 1. Requisitos previos

- Flutter SDK instalado (el proyecto se valida con la versión del entorno local).
- JDK 17 compatible con el Android Gradle Plugin del repo.
- Acceso al **keystore oficial** de upload/producción (fuera de Git).
- Permiso para conservar artefactos privados (símbolos Dart + `mapping.txt` de R8).

Debug y tests **no** requieren keystore release.

---

## 2. Cómo obtener el keystore oficial

1. Solicitar el keystore (o la upload key de Play App Signing) al responsable de
   custodia de la organización / producto.
2. Almacenarlo fuera del clon Git (p. ej. gestor de secretos, HSM, o ruta
   cifrada del equipo de release).
3. Guardar una **copia de seguridad** recuperable por más de una persona
   autorizada.
4. **No** regenerar un keystore “porque se perdió la contraseña” sin seguir el
   proceso de Play Console (pérdida de update continuity).

Si aún no existe un keystore oficial, **no** uses `debug.keystore` ni inventes
uno temporal para “probar producción”. La configuración del repo ya bloquea
release sin credenciales.

---

## 3. Crear localmente `key.properties`

```bash
cd flutter_app_saludable/android
cp key.properties.example key.properties
# Editar key.properties con rutas y secretos reales (solo en máquina local)
```

Campos:

| Propiedad       | Descripción                          |
|-----------------|--------------------------------------|
| `storeFile`     | Ruta al `.jks` / `.keystore`         |
| `storePassword` | Password del almacén                 |
| `keyAlias`      | Alias de la clave                    |
| `keyPassword`   | Password de la clave                 |

- `storeFile` puede ser **absoluta** o **relativa al directorio `android/`**.
- `key.properties` está en `android/.gitignore` y **no** debe subirse.

---

## 4. Variables de entorno (CI)

Precedencia: **variables de entorno > `key.properties`**.

| Variable                     | Equivale a      |
|------------------------------|-----------------|
| `NUTRILIFE_KEYSTORE_PATH`    | `storeFile`     |
| `NUTRILIFE_KEYSTORE_PASSWORD`| `storePassword` |
| `NUTRILIFE_KEY_ALIAS`        | `keyAlias`      |
| `NUTRILIFE_KEY_PASSWORD`     | `keyPassword`   |

Configúralas en el gestor de secretos del CI. Gradle **no** debe imprimir sus
valores en logs.

---

## 5. APK release (pruebas internas)

Sin ofuscación Dart (solo R8 nativo):

```bash
cd flutter_app_saludable
flutter build apk --release
```

Con ofuscación Dart (recomendado acercarse a producción):

```bash
# DIRECTORIO_PRIVADO: fuera de Git, p. ej. ~/SecureArtifacts/nutrilife/1.0.0+1/dart-symbols
flutter build apk \
  --release \
  --obfuscate \
  --split-debug-info="$HOME/SecureArtifacts/nutrilife/1.0.0+1/dart-symbols"
```

---

## 6. AAB release (Play Store)

```bash
flutter build appbundle \
  --release \
  --obfuscate \
  --split-debug-info="$HOME/SecureArtifacts/nutrilife/1.0.0+1/dart-symbols"
```

Salida típica:

`build/app/outputs/bundle/release/app-release.aab`

---

## 7. Ofuscación Dart (`--obfuscate`)

R8 ofusca Java/Kotlin; **no** sustituye la ofuscación del código Dart.

Comando de producción:

```bash
flutter build appbundle \
  --release \
  --obfuscate \
  --split-debug-info=<DIRECTORIO_PRIVADO_DE_SIMBOLOS>
```

El directorio de símbolos:

- no debe vivir en una carpeta versionada del repo;
- se conserva **privado por cada** `versionName` + `versionCode`;
- es necesario para simbolizar stack traces Dart;
- **no** se elimina tras publicar.

Si se usa una ruta local bajo el proyecto (no recomendado), debe estar en
`.gitignore` (p. ej. `release-symbols/`).

---

## 8. Artefactos a conservar por versión

Asocia cada release a `versionName` / `versionCode` (hoy en `pubspec.yaml`:
`1.0.0+1` → name `1.0.0`, code `1`). Coordinar `versionCode` con el historial
real de Play Console antes de publicar.

| Artefacto | Ubicación típica de build | Custodia |
|-----------|---------------------------|----------|
| Símbolos Dart | `--split-debug-info=...` | Almacén privado por versión |
| Mapping R8 | `android/app/build/outputs/mapping/release/mapping.txt` (o bajo `build/` del proyecto Flutter) | Copiar a almacén privado; **no** a Git |
| AAB / APK | `build/app/outputs/...` | Almacén de release |

No versionar estos archivos en el repositorio.

---

## 9. Verificar la firma

### APK

```bash
apksigner verify --verbose --print-certs path/to/app-release.apk
```

Confirmar: firma válida, certificado **esperado** (no el de debug),
`applicationId` `com.nutrilife.club`.

### AAB

```bash
jarsigner -verify -verbose -certs path/to/app-release.aab
```

No afirmar que el certificado es correcto solo porque el build terminó: comparar
huellas con el certificado oficial custodiado.

---

## 10. Smoke test en dispositivo

Tras instalar el APK/AAB firmado con la clave **release**:

1. Arranque
2. Login
3. Persistencia segura del token (`flutter_secure_storage`)
4. Logout
5. Manejo de 401 / sesión expirada
6. Conectividad
7. Pedidos offline + sync
8. QR / cámara si aplica
9. Navegación principal

**Importante:** una app instalada con firma **debug** no se actualiza con una
release firmada distinta. Los testers pueden necesitar **desinstalar** la build
antigua; al desinstalar se pierden datos locales — hacerlo solo en dispositivos
de prueba y con cuidado.

---

## 11. Rotación solo de la upload key

Si Play App Signing está activo, Google retiene la clave de firma de la app.
Puede rotarse la **upload key** siguiendo el flujo de Play Console (certificado
PEM de la nueva upload key). No regeneres claves de forma arbitraria.

---

## 12. Prohibición de regenerar la clave de firma

No crear un keystore nuevo “para salir del paso”. Cambiar la clave de firma de
la app (cuando no hay App Signing o se pierde la key de firma) implica que los
usuarios **no** pueden actualizar la app instalada; deben desinstalar e instalar
de nuevo (pérdida de continuidad y, en la práctica, un producto distinto ante
el sistema).

---

## 13. Recuperación ante pérdida de credenciales

1. Comprobar backups oficiales del keystore y contraseñas.
2. Si solo se perdió la **upload key** y Play App Signing está activo: iniciar
   reset de upload key en Play Console.
3. Si se perdió la clave de firma de la app **sin** App Signing: contactar a
   Google Play support / proceso de la organización; puede ser irrecuperable
   para actualizaciones del mismo listing.
4. Documentar el incidente; no subir keystores al chat ni al repo.

---

## 14. Responsabilidades de custodia

- La clave de producción la custodia la **organización**, no un desarrollador
  individual de forma exclusiva.
- Acceso mínimo necesario; rotación de personas documentada.
- Backups cifrados y probados periódicamente.
- CI usa secretos del pipeline, no archivos committed.

---

## Validación anti-regresión en el repo

```bash
cd flutter_app_saludable/android
./gradlew :app:verifyReleaseSecurity
```

Sin credenciales, `assembleRelease` / `bundleRelease` / `flutter build apk|appbundle --release`
deben **fallar** con mensaje claro (VULN-FL-04), sin firmar con debug.

Con credenciales válidas, release firma solo con `signingConfigs.release`.

R8: `isMinifyEnabled` + `isShrinkResources` + `proguard-android-optimize.txt` +
`proguard-rules.pro`.
