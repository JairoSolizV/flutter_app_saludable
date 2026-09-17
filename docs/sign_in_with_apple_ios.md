# Sign in with Apple (iOS) — Expande

## Contrato Flutter ↔ backend

### Login: `POST /api/auth/apple` (público)

| Campo | Tipo | Obligatorio | Notas |
|-------|------|-------------|--------|
| `identityToken` | string | sí | JWT emitido por Apple. Validar firma/iss/aud/exp/nonce en servidor. |
| `authorizationCode` | string | no | Recomendado (revoke). Flutter lo omite si Apple no lo entrega. |
| `nonce` | string | sí | Nonce **crudo**. Flutter envía a Apple el SHA-256 hex; el JWT trae ese hash. |
| `nombre` | string | no | Solo primera autorización; omitir si vacío/null. |
| `apellido` | string | no | Solo primera autorización; omitir si vacío/null. |

No enviar email como campo de confianza: el servidor lo toma del token verificado (incluye relay privado `privaterelay.appleid.com`).

### Response 200

Misma forma que `/auth/google` (`AuthenticationResponse`):

`token`, `userId`, `email`, `nombre`, `apellido`, `rolNombre`, `codigoSorteo`, `requiresVerification`.

### Errores esperados (mapeados en Flutter)

- `400` / códigos tipo `APPLE_TOKEN_INVALID`, `APPLE_NONCE_MISMATCH`, etc. → mensaje público.
- `409` + `ACCOUNT_LINK_REQUIRED` → mensaje fijo en app:
  *«Ya existe una cuenta con este correo. Inicia sesión con tu método actual y vincula Apple desde tu perfil.»*
  **No se crea sesión local** (ni JWT ni usuario SQLite).
- `409` + `APPLE_ALREADY_LINKED` → conflicto de vinculación.
- Red / timeout → `ErrorMapper` estándar.

La sesión local (JWT + SQLite) **solo** se guarda tras 200 y parseo exitoso.

### Vincular: `POST /api/auth/apple/link` (autenticado)

Disponible en Perfil/Cuenta (iOS) como **«Vincular Apple»**.

| Campo | Tipo | Obligatorio |
|-------|------|-------------|
| `identityToken` | string | sí |
| `authorizationCode` | string | no | Se omite si vacío. |
| `nonce` | string | sí |

El cliente Dio adjunta `Authorization: Bearer <JWT actual>`. No reemplaza la sesión local; solo asocia el `apple_sub` a la cuenta autenticada.

## Nonce

1. Flutter: `rawNonce = generateNonce()`, `hashed = sha256(rawNonce)`.
2. Apple recibe `hashed` en `getAppleIDCredential(nonce: hashed)`.
3. Backend recibe `rawNonce`, calcula SHA-256 y lo compara con el claim `nonce` del JWT.

## Logout vs eliminación

- **Cerrar sesión:** limpia JWT/perfil local y Google `signOut`. **No** revoca Apple.
- **Eliminar cuenta (pendiente):** el backend debe usar el refresh token / authorization code guardado para llamar al endpoint de revoke de Apple, luego borrar datos. Flutter solo limpia local tras confirmación del servidor.

## Activación en Apple Developer (manual)

Bundle ID: `com.nutritionclubs.app`  
Team oficial: Tito Zuniga (`DEVELOPMENT_TEAM = 9V53FJ4Y2H` en `project.pbxproj`). No sustituir por team personal.

1. [Identifiers → App IDs](https://developer.apple.com/account/resources/identifiers/list/bundleId): abrir `com.nutritionclubs.app` → habilitar **Sign In with Apple** → Save.
2. [Keys](https://developer.apple.com/account/resources/authkeys/list): crear clave con Sign in with Apple, Primary App ID = el App ID anterior. Descargar `.p8` **una vez**, anotar Key ID. Entregar al backend (secret manager); **no** subir al repo.
3. Regenerar / descargar **Provisioning Profiles** (Development + Distribution / App Store) para que incluyan el capability. En Xcode: Signing & Capabilities → confirmar capability **Sign in with Apple** y perfiles actualizados.
4. (Opcional, solo web/Android Apple): Service ID — **no requerido** para iOS nativo.
5. Private Email Relay: configurar dominio/SPF si se enviará correo a usuarios con relay ([guía Apple](https://developer.apple.com/help/account/configure-app-capabilities/configure-private-email-relay-service/)).

## Entitlements en el repo

`ios/Runner/Runner.entitlements` incluye:

```xml
com.apple.developer.applesignin = Default
```

Referenciado por `CODE_SIGN_ENTITLEMENTS` en Debug/Release/Profile. No modifica bundle ID ni team.

## Referencias

- [Authenticating users with Sign in with Apple](https://developer.apple.com/documentation/signinwithapple/authenticating-users-with-sign-in-with-apple)
- [Offering account deletion](https://developer.apple.com/support/offering-account-deletion-in-your-app/) (revocación al borrar cuenta)
- [sign_in_with_apple 7.x](https://pub.dev/packages/sign_in_with_apple)
- App Review Guideline **4.8** Login Services
