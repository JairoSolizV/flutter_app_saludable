# Verificación de Correo por OTP — Plan de Implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Que el código OTP llegue realmente al correo del usuario, y que nadie pueda entrar a la app sin haberlo ingresado.

**Architecture:** Dos frentes. (1) El envío SMTP sale por `smtp.gmail.com:587`, puerto que Render bloquea en el plan Free — se migra a un relay transaccional (Brevo) por el puerto 2525, que no está bloqueado, y se separa el remitente del usuario SMTP. (2) El flujo actual crea el usuario y emite el JWT en `/register`, antes de verificar nada — se mueve la emisión del token a `/verify-email`, se hace que el filtro JWT rechace usuarios no activos, y la app Flutter pasa a persistir la sesión sólo después de verificar.

**Tech Stack:** Spring Boot 3 (Java 17), Spring Security + JJWT, Spring Mail (JavaMailSender), Flyway + PostgreSQL, JUnit 5 + Mockito, Flutter + Dio + Provider, Render (hosting), Brevo (relay SMTP).

---

## Contexto: diagnóstico ya confirmado

No hace falta re-investigar. Esto ya está probado con evidencia:

| # | Síntoma | Causa raíz confirmada | Evidencia |
|---|---|---|---|
| 1 | El OTP nunca llega | Render bloquea el tráfico saliente a los puertos SMTP 25/465/587 en servicios web del plan Free (desde 26-sep-2025). El default de `MAIL_PORT` es 587. | `MailConnectException: Couldn't connect to host, port: smtp.gmail.com, 587; SocketTimeoutException: Connect timed out` |
| 2 | El error se ocultó meses | `AuthServiceImpl.register` envuelve el envío en `try/catch(Exception)` y devuelve 200 igual | `AuthServiceImpl.java:88-92` |
| 3 | El usuario se crea igual | `usuarioRepository.save()` commitea antes de intentar el mail; `register()` no es `@Transactional` | `AuthServiceImpl.java:84` |
| 4 | Se entra sin verificar | `/register` devuelve un JWT usable, y `JwtAuthenticationFilter` nunca consulta `isEnabled()` | `AuthServiceImpl.java:95`, `JwtAuthenticationFilter.java:52` |
| 5 | Sobrevive al cierre de la app | Flutter persiste la sesión en `register()`; el flag `_requiresVerification` es sólo memoria y el router no tiene guard | `auth_provider.dart:218` |
| 6 | Latente: BD nueva no arranca | No existe migración Flyway de `verification_codes`; la tabla sólo existe en prod por herencia de `ddl-auto=update` | `db/migration/` no la contiene |

**Nota importante sobre el orden:** las fases están ordenadas para que cada despliegue sea seguro por separado. En particular, `/verify-email` empieza a **devolver** el token (Fase 2) antes de que Flutter lo **use** (Fase 3), y recién después `/register` deja de emitirlo (Fase 4). Invertir ese orden rompe el registro en producción.

## Repositorios

Este plan toca dos repos hermanos bajo `C:\Users\Jairo\Documents\Flutter Quillo\`:

- `Pasantias_Backend/` — Spring Boot
- `flutter_app_saludable/` — Flutter

Cada task indica en cuál se trabaja y cada commit se hace en el repo correspondiente.

## Estructura de archivos

**Backend — crear:**

| Archivo | Responsabilidad |
|---|---|
| `src/main/resources/db/migration/V15__verification_codes.sql` | DDL de la tabla de OTP, hoy inexistente en migraciones |
| `src/main/java/.../dtos/auth/VerifyEmailResponse.java` | Respuesta de `/verify-email`, ahora con JWT |
| `src/test/java/.../services/EmailServiceImplTest.java` | Test del remitente y del armado del correo |
| `src/test/java/.../config/MailConfigGuardTest.java` | Guard: que nadie vuelva a poner el puerto 587 como default |
| `src/test/java/.../security/JwtAuthenticationFilterTest.java` | Test de que un usuario no activo no autentica |
| `src/test/java/.../services/VerificationServiceImplTest.java` | Test de `verifyCode` devolviendo el usuario activado |
| `src/test/java/.../services/AuthServiceRegisterTest.java` | Test de que `register` no emite token ni oculta fallos |
| `src/main/java/.../exceptions/EmailDeliveryException.java` | Fallo de entrega de correo, mapeado a 503 |
| `src/main/java/.../scheduled/PendingRegistrationCleanup.java` | Purga de registros pendientes vencidos |

**Backend — modificar:**

| Archivo | Cambio |
|---|---|
| `src/main/resources/application.properties:58-66` | Host/puerto a Brevo:2525, nueva propiedad `app.mail.from` |
| `src/main/java/.../serviceimpls/EmailServiceImpl.java:19-21` | El `From` sale de `app.mail.from`, no del usuario SMTP |
| `src/main/java/.../services/VerificationService.java` | `verifyCode` devuelve `Optional<Usuario>` |
| `src/main/java/.../serviceimpls/VerificationServiceImpl.java` | Idem implementación |
| `src/main/java/.../controllers/auth/AuthController.java` | `/verify-email` emite el JWT |
| `src/main/java/.../serviceimpls/AuthServiceImpl.java:84-99` | `register` sin token y sin tragarse el fallo de envío |
| `src/main/java/.../exceptions/GlobalExceptionHandler.java` | Handler de `EmailDeliveryException` → 503 |
| `src/main/java/.../security/JwtAuthenticationFilter.java` | Chequeo de `isEnabled()` |
| `src/main/java/.../HerbalifeClubesApplication.java` | `@EnableScheduling` |
| `src/main/java/.../repositories/UsuarioRepository.java` | Query de purga |

**Flutter — modificar:**

| Archivo | Cambio |
|---|---|
| `lib/data/datasources/remote/auth_remote_data_source.dart` | `verifyEmail` devuelve `User?` en vez de `bool` |
| `lib/presentation/providers/auth_provider.dart` | `register` no persiste sesión; `verifyEmail` sí |
| `lib/presentation/screens/auth/email_verification_screen.dart` | Setear el `UserProvider` al verificar |
| `test/core/auth/auth_provider_session_test.dart` | Ajustar el fake al nuevo contrato |

---

# FASE 0 — La migración que falta

Independiente del resto. Se puede hacer y mergear sola.

### Task 1: Migración Flyway de `verification_codes`

**Contexto:** La tabla existe en la BD de producción porque Hibernate la creó cuando `ddl-auto` estaba en `update`. Desde que se pasó a `validate`, cualquier base nueva hace que el backend **no arranque**. El DDL debe ser idéntico al que ya usa el bootstrap de tests (`src/test/resources/db/bootstrap/pre_flyway_patch.sql:58-65`) para que prod y test coincidan.

**Files:**
- Create: `Pasantias_Backend/src/main/resources/db/migration/V15__verification_codes.sql`
- Modify: `Pasantias_Backend/src/test/java/com/example/herbalife_clubes/flyway/MigrationScriptsGuardTest.java`

- [ ] **Step 1: Escribir el test que falla**

Agregar este método dentro de la clase `MigrationScriptsGuardTest`, después de `v14AddsNullableBooleanOnMembresiasWithoutDefaultFalse`:

```java
    @Test
    void v15CreatesVerificationCodesIdempotently() throws Exception {
        Path v15 = MIGRATIONS.resolve("V15__verification_codes.sql");
        assertTrue(Files.exists(v15), "Falta la migración de verification_codes");
        String sql = Files.readString(v15, StandardCharsets.UTF_8).toLowerCase(Locale.ROOT);
        assertTrue(sql.contains("create table if not exists verification_codes"),
                "Debe ser idempotente: la tabla ya existe en producción");
        assertTrue(sql.contains("usuario_id integer not null references usuarios(id)"));
        assertTrue(sql.contains("code varchar(6) not null"));
        assertTrue(sql.contains("expires_at timestamp not null"));
        assertTrue(sql.contains("used boolean not null default false"));
        assertFalse(sql.contains("drop table"));
        assertFalse(sql.contains("insert into"));
    }
```

- [ ] **Step 2: Correr el test y verificar que falla**

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/Pasantias_Backend" && ./mvnw test -Dtest=MigrationScriptsGuardTest
```

Esperado: FAIL en `v15CreatesVerificationCodesIdempotently` con `Falta la migración de verification_codes`.

- [ ] **Step 3: Crear la migración**

Contenido completo de `src/main/resources/db/migration/V15__verification_codes.sql`:

```sql
-- V15: tabla de códigos OTP de verificación de correo.
--
-- Esta tabla ya existe en las bases creadas antes de adoptar Flyway (la generó
-- Hibernate cuando ddl-auto=update). Se escribe idempotente a propósito: en esas
-- bases el CREATE es un no-op y Flyway sólo registra la versión; en bases nuevas
-- la crea. El DDL es idéntico al de src/test/resources/db/bootstrap/pre_flyway_patch.sql
-- para que producción y tests validen contra el mismo esquema.

CREATE TABLE IF NOT EXISTS verification_codes (
    id BIGSERIAL PRIMARY KEY,
    usuario_id INTEGER NOT NULL REFERENCES usuarios(id),
    code VARCHAR(6) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    used BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP
);

-- Sirve a invalidateAllByUsuario y a countRecentCodes.
CREATE INDEX IF NOT EXISTS idx_verification_codes_usuario_used
    ON verification_codes (usuario_id, used);

-- Sirve a findValidCode.
CREATE INDEX IF NOT EXISTS idx_verification_codes_code_expires
    ON verification_codes (code, expires_at);
```

- [ ] **Step 4: Correr el test y verificar que pasa**

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/Pasantias_Backend" && ./mvnw test -Dtest=MigrationScriptsGuardTest
```

Esperado: PASS, 6 tests.

- [ ] **Step 5: Commit**

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/Pasantias_Backend" && git add src/main/resources/db/migration/V15__verification_codes.sql src/test/java/com/example/herbalife_clubes/flyway/MigrationScriptsGuardTest.java && git commit -m "feat(db): agregar migracion V15 de verification_codes"
```

---

# FASE 1 — Que el correo salga

Esto es lo que desbloquea hoy. Al terminar la fase, el OTP llega.

### Task 2: Separar el remitente del usuario SMTP

**Contexto:** Hoy `EmailServiceImpl` usa `spring.mail.username` como dirección `From`. Con Gmail eso funcionaba de casualidad (usuario SMTP == dirección de correo). Con Brevo el usuario SMTP es algo tipo `9a1b2c001@smtp-brevo.com`, que **no** es un remitente verificado: Brevo rechazaría el envío. Hay que separar las dos cosas antes de cambiar de proveedor.

**Files:**
- Modify: `Pasantias_Backend/src/main/java/com/example/herbalife_clubes/serviceimpls/EmailServiceImpl.java:19-21`
- Modify: `Pasantias_Backend/src/main/resources/application.properties`
- Test: `Pasantias_Backend/src/test/java/com/example/herbalife_clubes/services/EmailServiceImplTest.java`

- [ ] **Step 1: Escribir el test que falla**

Crear `src/test/java/com/example/herbalife_clubes/services/EmailServiceImplTest.java`:

```java
package com.example.herbalife_clubes.services;

import com.example.herbalife_clubes.serviceimpls.EmailServiceImpl;
import jakarta.mail.internet.MimeMessage;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mail.MailSendException;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.JavaMailSenderImpl;
import org.springframework.test.util.ReflectionTestUtils;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class EmailServiceImplTest {

    private static final String FROM = "noreply@misterquillo.com";
    private static final String SMTP_USER = "9a1b2c001@smtp-brevo.com";

    @Mock
    private JavaMailSender mailSender;

    @InjectMocks
    private EmailServiceImpl emailService;

    @BeforeEach
    void setUp() {
        // El remitente debe venir de app.mail.from, NO del usuario SMTP.
        ReflectionTestUtils.setField(emailService, "fromEmail", FROM);
        ReflectionTestUtils.setField(emailService, "appName", "Nutrition Clubs");
    }

    @Test
    void usaAppMailFromComoRemitenteYNoElUsuarioSmtp() throws Exception {
        when(mailSender.createMimeMessage())
                .thenReturn(new JavaMailSenderImpl().createMimeMessage());

        emailService.sendVerificationCode("destino@example.com", "Jairo", "123456");

        ArgumentCaptor<MimeMessage> captor = ArgumentCaptor.forClass(MimeMessage.class);
        verify(mailSender).send(captor.capture());
        MimeMessage enviado = captor.getValue();

        assertEquals(FROM, enviado.getFrom()[0].toString(),
                "El From debe ser el remitente verificado, no el login SMTP");
        assertNotEquals(SMTP_USER, enviado.getFrom()[0].toString());
        assertEquals("destino@example.com", enviado.getAllRecipients()[0].toString());
        assertTrue(enviado.getSubject().contains("Código de Verificación"));
    }

    @Test
    void incluyeElCodigoEnElCuerpoDelCorreo() throws Exception {
        when(mailSender.createMimeMessage())
                .thenReturn(new JavaMailSenderImpl().createMimeMessage());

        emailService.sendVerificationCode("destino@example.com", "Jairo", "482913");

        ArgumentCaptor<MimeMessage> captor = ArgumentCaptor.forClass(MimeMessage.class);
        verify(mailSender).send(captor.capture());

        // El HTML pinta un dígito por caja; se verifica que estén todos y en orden.
        String html = leerCuerpo(captor.getValue());
        int anterior = -1;
        for (char c : "482913".toCharArray()) {
            int pos = html.indexOf(">" + c + "</span>", anterior + 1);
            assertTrue(pos > anterior, "Falta el dígito " + c + " en el cuerpo del correo");
            anterior = pos;
        }
    }

    @Test
    void propagaElFalloDeEnvioEnVezDeTragarselo() {
        when(mailSender.createMimeMessage())
                .thenReturn(new JavaMailSenderImpl().createMimeMessage());
        doThrow(new MailSendException("Connect timed out"))
                .when(mailSender).send(any(MimeMessage.class));

        RuntimeException ex = assertThrows(RuntimeException.class,
                () -> emailService.sendVerificationCode("destino@example.com", "Jairo", "123456"));
        assertTrue(ex.getMessage().toLowerCase().contains("timed out")
                        || ex.getMessage().toLowerCase().contains("correo"),
                "El fallo de envío no puede quedar silenciado");
    }

    private String leerCuerpo(MimeMessage mensaje) throws Exception {
        Object contenido = mensaje.getContent();
        return contenido.toString();
    }
}
```

- [ ] **Step 2: Correr el test y verificar que falla**

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/Pasantias_Backend" && ./mvnw test -Dtest=EmailServiceImplTest
```

Esperado: FAIL. `usaAppMailFromComoRemitenteYNoElUsuarioSmtp` falla al setear el campo — hoy el campo se llama `fromEmail` pero está atado a `spring.mail.username`; el test pasa a rojo recién cuando la propiedad cambie. Si el test pasara en verde acá, revisar que `ReflectionTestUtils` esté apuntando al campo correcto.

- [ ] **Step 3: Cambiar el origen del remitente**

En `src/main/java/com/example/herbalife_clubes/serviceimpls/EmailServiceImpl.java`, reemplazar:

```java
    @Value("${spring.mail.username:noreply@nutrilifeclub.com}")
    private String fromEmail;

    @Value("${app.name:Nutrilife Club}")
    private String appName;
```

por:

```java
    /**
     * Dirección remitente. Debe ser un correo verificado en el proveedor SMTP.
     * NO puede derivarse de spring.mail.username: con un relay como Brevo el
     * usuario SMTP (xxxxx@smtp-brevo.com) no es un remitente válido y el envío
     * se rechaza.
     */
    @Value("${app.mail.from}")
    private String fromEmail;

    @Value("${app.name:Nutrilife Club}")
    private String appName;
```

- [ ] **Step 4: Definir la propiedad**

En `src/main/resources/application.properties`, dentro del bloque "Configuración de Verificación por Email" (después de `app.name=...`), agregar:

```properties
# Remitente de los correos salientes. Debe estar verificado en el proveedor SMTP.
# Si no se define MAIL_FROM, cae al usuario SMTP (sirve para Gmail en local,
# NO sirve con un relay como Brevo).
app.mail.from=${MAIL_FROM:${spring.mail.username}}
```

- [ ] **Step 5: Correr el test y verificar que pasa**

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/Pasantias_Backend" && ./mvnw test -Dtest=EmailServiceImplTest
```

Esperado: PASS, 3 tests.

> Si `propagaElFalloDeEnvioEnVezDeTragarselo` falla, es porque `EmailServiceImpl` sólo atrapa `MessagingException` y `MailSendException` no lo es — o sea, ya propaga. En ese caso el test pasa sin cambios; el `catch (MessagingException)` existente queda como código muerto y se limpia en la Task 10.

- [ ] **Step 6: Commit**

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/Pasantias_Backend" && git add src/main/java/com/example/herbalife_clubes/serviceimpls/EmailServiceImpl.java src/main/resources/application.properties src/test/java/com/example/herbalife_clubes/services/EmailServiceImplTest.java && git commit -m "fix(mail): separar remitente verificado del usuario SMTP"
```

---

### Task 3: Mover los defaults a un puerto que Render no bloquee

**Contexto:** `MAIL_HOST` y `MAIL_PORT` no están cargadas en Render, así que caen a los defaults `smtp.gmail.com` y `587`. Render bloquea 25/465/587 en el plan Free. El 2525 es el puerto alternativo estándar de los relays transaccionales y no está en la lista de bloqueo. Se cambian los defaults para que un deploy nuevo no dependa de que alguien recuerde cargar las variables.

**Files:**
- Modify: `Pasantias_Backend/src/main/resources/application.properties:58-59`
- Test: `Pasantias_Backend/src/test/java/com/example/herbalife_clubes/config/MailConfigGuardTest.java`

- [ ] **Step 1: Escribir el test que falla**

Crear `src/test/java/com/example/herbalife_clubes/config/MailConfigGuardTest.java`:

```java
package com.example.herbalife_clubes.config;

import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Guard de configuración de correo.
 *
 * Render bloquea el tráfico saliente a los puertos SMTP 25, 465 y 587 en los
 * servicios web del plan Free. Volver a poner cualquiera de esos como default
 * deja el envío de OTP muerto en producción con un timeout silencioso, que es
 * exactamente el bug que este test previene que vuelva.
 */
class MailConfigGuardTest {

    private static final Path PROPS = Path.of("src/main/resources/application.properties");

    @Test
    void noUsaPuertosSmtpBloqueadosPorRender() throws Exception {
        String props = Files.readString(PROPS, StandardCharsets.UTF_8);
        assertTrue(props.contains("spring.mail.port=${MAIL_PORT:2525}"),
                "El puerto por defecto debe ser 2525");
        assertFalse(props.contains("MAIL_PORT:587}"), "Puerto 587 bloqueado por Render");
        assertFalse(props.contains("MAIL_PORT:465}"), "Puerto 465 bloqueado por Render");
        assertFalse(props.contains("MAIL_PORT:25}"), "Puerto 25 bloqueado en todos los planes");
    }

    @Test
    void noApuntaAGmailPorDefecto() throws Exception {
        String props = Files.readString(PROPS, StandardCharsets.UTF_8);
        assertFalse(props.contains("MAIL_HOST:smtp.gmail.com}"),
                "Gmail no ofrece puerto 2525; usar un relay transaccional");
    }

    @Test
    void defineRemitenteIndependienteDelUsuarioSmtp() throws Exception {
        String props = Files.readString(PROPS, StandardCharsets.UTF_8);
        assertTrue(props.contains("app.mail.from="),
                "Falta app.mail.from: el From no puede depender de spring.mail.username");
    }

    @Test
    void mantieneTimeoutsAcotados() throws Exception {
        String props = Files.readString(PROPS, StandardCharsets.UTF_8);
        assertTrue(props.contains("mail.smtp.connectiontimeout="),
                "Sin timeout de conexión, un puerto bloqueado cuelga el request de registro");
        assertTrue(props.contains("mail.smtp.timeout="));
        assertTrue(props.contains("mail.smtp.writetimeout="));
    }
}
```

- [ ] **Step 2: Correr el test y verificar que falla**

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/Pasantias_Backend" && ./mvnw test -Dtest=MailConfigGuardTest
```

Esperado: FAIL en `noUsaPuertosSmtpBloqueadosPorRender` y `noApuntaAGmailPorDefecto`.

- [ ] **Step 3: Cambiar los defaults**

En `src/main/resources/application.properties`, reemplazar el bloque de correo. De:

```properties
# Configurar estas variables de entorno en producción (Render):
#   MAIL_HOST, MAIL_PORT, MAIL_USERNAME, MAIL_PASSWORD
spring.mail.host=${MAIL_HOST:smtp.gmail.com}
spring.mail.port=${MAIL_PORT:587}
```

a:

```properties
# Configurar estas variables de entorno en producción (Render):
#   MAIL_HOST, MAIL_PORT, MAIL_USERNAME, MAIL_PASSWORD, MAIL_FROM
#
# IMPORTANTE — puertos: Render bloquea el tráfico saliente a los puertos SMTP
# 25, 465 y 587 en los servicios web del plan Free. El 25 está bloqueado además
# en todos los planes. Por eso el default es 2525, el puerto alternativo que
# ofrecen los relays transaccionales (Brevo, SendGrid, Mailgun, SMTP2GO).
# Gmail NO ofrece 2525: no se puede usar Gmail como relay desde Render Free.
spring.mail.host=${MAIL_HOST:smtp-relay.brevo.com}
spring.mail.port=${MAIL_PORT:2525}
```

- [ ] **Step 4: Correr los tests y verificar que pasan**

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/Pasantias_Backend" && ./mvnw test -Dtest=MailConfigGuardTest+EmailServiceImplTest
```

Esperado: PASS, 7 tests.

- [ ] **Step 5: Commit**

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/Pasantias_Backend" && git add src/main/resources/application.properties src/test/java/com/example/herbalife_clubes/config/MailConfigGuardTest.java && git commit -m "fix(mail): usar puerto 2525, no bloqueado por Render Free"
```

---

### Task 4: Configurar Brevo y Render (sin código)

**Contexto:** Esta task no toca el repo. Es la que efectivamente hace que el correo salga.

- [ ] **Step 1: Crear la cuenta de Brevo y verificar el remitente**

1. Registrarse en Brevo (plan gratuito: 300 correos/día).
2. **Senders, Domains & Dedicated IPs → Senders → Add a sender.**
3. Cargar el correo remitente. Si se usa el dominio propio (`misterquillo.com`), verificar el dominio completo mejora la entregabilidad; si no, alcanza con verificar una dirección suelta.
4. Confirmar el mail que llega a esa casilla. **Sin este paso Brevo rechaza todos los envíos.**

- [ ] **Step 2: Obtener las credenciales SMTP**

En Brevo: **SMTP & API → SMTP**. Anotar:
- *Login*: con forma `9a1b2c001@smtp-brevo.com` (no es el correo de la cuenta)
- *SMTP key*: la clave larga generada. Se muestra una sola vez.

- [ ] **Step 3: Cargar las variables en Render**

En Render → el servicio `clubs-api` → **Environment**:

| Variable | Valor |
|---|---|
| `MAIL_HOST` | `smtp-relay.brevo.com` |
| `MAIL_PORT` | `2525` |
| `MAIL_USERNAME` | el *Login* del paso 2 |
| `MAIL_PASSWORD` | la *SMTP key* del paso 2 |
| `MAIL_FROM` | el remitente verificado en el paso 1 |
| `APP_NAME` | `Nutrition Clubs` |

> `APP_NAME` es aparte: hoy `app.name=Nutrilife Club` quedó del branding viejo y sale impreso en el asunto y el encabezado del correo.
>
> Si `MAIL_USERNAME`/`MAIL_PASSWORD` tenían credenciales de Gmail (correo + App Password de la verificación en 2 pasos), **hay que reemplazarlas**: no sirven contra Brevo.

- [ ] **Step 4: Desplegar y verificar contra el entorno real**

Hacer deploy de la rama con las Tasks 1-3. Después, desde la app: registrarse con un correo real, y en la pantalla del OTP tocar **"Reenviar código"**. Ese endpoint no oculta el error, así que:

| Resultado | Significado | Acción |
|---|---|---|
| Llega el correo | Listo | Seguir a la Fase 2 |
| `535 Authentication failed` | Credenciales mal copiadas o no son de Brevo | Rehacer Step 2 |
| `Sender not valid` / `unrecognized sender` | `MAIL_FROM` no está verificado en Brevo | Rehacer Step 1 |
| `Connect timed out` otra vez | Render también cerró el 2525 | Migrar a la API HTTP de Brevo por puerto 443 (mismo remitente y cuenta; sólo cambia `EmailServiceImpl`) |

También se puede probar sin la app:

```bash
curl -i -X POST https://clubs-api.onrender.com/api/auth/resend-code -H "Content-Type: application/json" -d "{\"email\":\"tucorreo@gmail.com\"}"
```

- [ ] **Step 5: Confirmar en la BD**

`generateAndSendCode` es `@Transactional` y el envío ocurre dentro de la transacción: si el mail falla, el INSERT del código se revierte. Entonces la presencia de filas es prueba de que el envío salió.

```sql
SELECT id, usuario_id, code, expires_at, used, created_at
FROM verification_codes ORDER BY id DESC LIMIT 5;
```

Esperado: al menos una fila reciente con `used = false`.

---

# FASE 2 — `/verify-email` emite el token

Cambio **aditivo**: la respuesta gana campos nuevos. La app vieja los ignora y sigue funcionando. Se puede desplegar solo.

### Task 5: `verifyCode` devuelve el usuario activado

**Files:**
- Modify: `Pasantias_Backend/src/main/java/com/example/herbalife_clubes/services/VerificationService.java`
- Modify: `Pasantias_Backend/src/main/java/com/example/herbalife_clubes/serviceimpls/VerificationServiceImpl.java:65-86`
- Test: `Pasantias_Backend/src/test/java/com/example/herbalife_clubes/services/VerificationServiceImplTest.java`

- [ ] **Step 1: Escribir el test que falla**

Crear `src/test/java/com/example/herbalife_clubes/services/VerificationServiceImplTest.java`:

```java
package com.example.herbalife_clubes.services;

import com.example.herbalife_clubes.entities.Usuario;
import com.example.herbalife_clubes.entities.VerificationCode;
import com.example.herbalife_clubes.repositories.UsuarioRepository;
import com.example.herbalife_clubes.repositories.VerificationCodeRepository;
import com.example.herbalife_clubes.serviceimpls.VerificationServiceImpl;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDateTime;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class VerificationServiceImplTest {

    private static final String EMAIL = "jairo@example.com";
    private static final String CODE = "482913";

    @Mock
    private VerificationCodeRepository verificationCodeRepository;
    @Mock
    private UsuarioRepository usuarioRepository;
    @Mock
    private EmailService emailService;

    @InjectMocks
    private VerificationServiceImpl verificationService;

    @Test
    void codigoValidoDevuelveElUsuarioYaActivado() {
        Usuario usuario = new Usuario();
        usuario.setId(42);
        usuario.setEmail(EMAIL);
        usuario.setEstado("PENDIENTE_VERIFICACION");

        VerificationCode vc = VerificationCode.builder()
                .id(1L)
                .usuario(usuario)
                .code(CODE)
                .expiresAt(LocalDateTime.now().plusMinutes(10))
                .used(false)
                .build();

        when(verificationCodeRepository.findValidCode(eq(EMAIL), eq(CODE), any()))
                .thenReturn(Optional.of(vc));
        when(usuarioRepository.save(any(Usuario.class))).thenAnswer(i -> i.getArgument(0));

        Optional<Usuario> resultado = verificationService.verifyCode(EMAIL, CODE);

        assertTrue(resultado.isPresent(), "Debe devolver el usuario para poder emitir el JWT");
        assertEquals(42, resultado.get().getId());
        assertEquals("ACTIVO", resultado.get().getEstado());
        assertTrue(vc.isUsed(), "El código debe quedar marcado como usado");
    }

    @Test
    void codigoInvalidoDevuelveVacioYNoActivaNada() {
        when(verificationCodeRepository.findValidCode(eq(EMAIL), eq("000000"), any()))
                .thenReturn(Optional.empty());

        Optional<Usuario> resultado = verificationService.verifyCode(EMAIL, "000000");

        assertTrue(resultado.isEmpty());
        verify(usuarioRepository, never()).save(any(Usuario.class));
    }
}
```

- [ ] **Step 2: Correr el test y verificar que falla**

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/Pasantias_Backend" && ./mvnw test -Dtest=VerificationServiceImplTest
```

Esperado: error de compilación — `verifyCode` devuelve `boolean`, no `Optional<Usuario>`.

- [ ] **Step 3: Cambiar la firma en la interfaz**

En `src/main/java/com/example/herbalife_clubes/services/VerificationService.java`, reemplazar el método `verifyCode` y agregar el import:

```java
import com.example.herbalife_clubes.entities.Usuario;

import java.util.Optional;
```

```java
    /**
     * Verifica un código OTP para un email dado.
     * Si es válido, marca el código como usado y activa al usuario.
     *
     * @param email el correo del usuario
     * @param code  el código OTP ingresado
     * @return el usuario ya activado, o vacío si el código es inválido o expiró
     */
    Optional<Usuario> verifyCode(String email, String code);
```

- [ ] **Step 4: Cambiar la implementación**

En `src/main/java/com/example/herbalife_clubes/serviceimpls/VerificationServiceImpl.java`, agregar `import java.util.Optional;` y reemplazar el método completo:

```java
    @Override
    @Transactional
    public Optional<Usuario> verifyCode(String email, String code) {
        var verificationCode = verificationCodeRepository
                .findValidCode(email, code, LocalDateTime.now())
                .orElse(null);

        if (verificationCode == null) {
            log.warn("Código de verificación inválido o expirado para: {}", email);
            return Optional.empty();
        }

        // Marcar código como usado
        verificationCode.setUsed(true);
        verificationCodeRepository.save(verificationCode);

        // Activar el usuario
        Usuario usuario = verificationCode.getUsuario();
        usuario.setEstado("ACTIVO");
        usuario = usuarioRepository.save(usuario);

        log.info("Correo verificado exitosamente para: {}", email);
        return Optional.of(usuario);
    }
```

- [ ] **Step 5: Correr el test y verificar que pasa**

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/Pasantias_Backend" && ./mvnw test -Dtest=VerificationServiceImplTest
```

Esperado: PASS, 2 tests. `AuthController` todavía no compila — se arregla en la Task 6.

- [ ] **Step 6: Commit** (junto con la Task 6, porque el proyecto no compila entre medio)

---

### Task 6: `/verify-email` devuelve el JWT

**Files:**
- Create: `Pasantias_Backend/src/main/java/com/example/herbalife_clubes/dtos/auth/VerifyEmailResponse.java`
- Modify: `Pasantias_Backend/src/main/java/com/example/herbalife_clubes/controllers/auth/AuthController.java:74-96`

- [ ] **Step 1: Crear el DTO de respuesta**

Crear `src/main/java/com/example/herbalife_clubes/dtos/auth/VerifyEmailResponse.java`:

```java
package com.example.herbalife_clubes.dtos.auth;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Respuesta de POST /api/auth/verify-email.
 *
 * Cuando la verificación es exitosa incluye el JWT: éste es el único momento
 * del flujo de registro por correo en el que se emite un token. /register ya no
 * devuelve ninguno.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
public class VerifyEmailResponse {
    private boolean verified;
    private String message;
    private String token;
    private Integer userId;
    private String email;
    private String nombre;
    private String apellido;
    private String rolNombre;
}
```

- [ ] **Step 2: Inyectar `JwtService` en el controlador**

En `src/main/java/com/example/herbalife_clubes/controllers/auth/AuthController.java`, agregar los imports:

```java
import com.example.herbalife_clubes.dtos.auth.VerifyEmailResponse;
import com.example.herbalife_clubes.security.JwtService;
```

y el campo, junto a los otros:

```java
    private final JwtService jwtService;
```

- [ ] **Step 3: Reescribir el endpoint**

Reemplazar el método `verifyEmail` completo por:

```java
    /**
     * Verificar correo electrónico con código OTP.
     *
     * Es el punto donde se emite el JWT del flujo de registro por correo:
     * /register ya no devuelve token, así que sin pasar por acá no hay sesión.
     *
     * @param request contiene email y código de 6 dígitos
     * @return la sesión ya autenticada, o 400 si el código no es válido
     */
    @PostMapping("/verify-email")
    public ResponseEntity<VerifyEmailResponse> verifyEmail(@Valid @RequestBody VerifyEmailRequest request) {
        var usuario = verificationService.verifyCode(request.getEmail(), request.getCode());

        if (usuario.isEmpty()) {
            return ResponseEntity.badRequest().body(VerifyEmailResponse.builder()
                    .verified(false)
                    .message("Código inválido o expirado. Verifica e intenta de nuevo.")
                    .build());
        }

        Usuario verificado = usuario.get();
        return ResponseEntity.ok(VerifyEmailResponse.builder()
                .verified(true)
                .message("Correo verificado exitosamente")
                .token(jwtService.generateToken(verificado))
                .userId(verificado.getId())
                .email(verificado.getEmail())
                .nombre(verificado.getNombre())
                .apellido(verificado.getApellido())
                .rolNombre(verificado.getRol() != null ? verificado.getRol().getNombre() : null)
                .build());
    }
```

> Se quitó el `try/catch(Exception)` que devolvía 500 con el mensaje crudo de la excepción: filtraba detalles internos y ya no hace falta, porque `verifyCode` no lanza en el camino de código inválido.

- [ ] **Step 4: Compilar y correr toda la suite**

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/Pasantias_Backend" && ./mvnw test
```

Esperado: BUILD SUCCESS, sin tests rojos.

- [ ] **Step 5: Commit**

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/Pasantias_Backend" && git add src/main/java/com/example/herbalife_clubes/dtos/auth/VerifyEmailResponse.java src/main/java/com/example/herbalife_clubes/controllers/auth/AuthController.java src/main/java/com/example/herbalife_clubes/services/VerificationService.java src/main/java/com/example/herbalife_clubes/serviceimpls/VerificationServiceImpl.java src/test/java/com/example/herbalife_clubes/services/VerificationServiceImplTest.java && git commit -m "feat(auth): emitir el JWT en verify-email en vez de en register"
```

- [ ] **Step 6: Desplegar**

Deploy a Render. La app en producción sigue funcionando igual: ignora los campos nuevos. Verificar con un registro real que el OTP sigue verificando bien antes de seguir.

---

# FASE 3 — Flutter: sesión sólo tras verificar

Requiere que la Fase 2 esté **desplegada**.

### Task 7: `verifyEmail` devuelve el usuario autenticado

**Files:**
- Modify: `flutter_app_saludable/lib/data/datasources/remote/auth_remote_data_source.dart:16` (interfaz) y `:238-252` (implementación)
- Test: `flutter_app_saludable/test/data/datasources/remote/auth_remote_data_source_test.dart`

- [ ] **Step 1: Escribir el test que falla**

Agregar un grupo nuevo dentro del `main()` de `test/data/datasources/remote/auth_remote_data_source_test.dart`, al mismo nivel que `group('login', ...)`. Usa el `adapter` y el `ds` que ya crea el `setUp` del archivo, y el wrapper `async_` que usan todos los tests de ahí:

```dart
  group('verifyEmail', () {
    test('devuelve el User con el token emitido al verificar', async_(() async {
      adapter.stub('POST', '/auth/verify-email', data: {
        'verified': true,
        'message': 'Correo verificado exitosamente',
        'token': 'jwt.emitido.al.verificar',
        'userId': 42,
        'email': 'jairo@example.com',
        'nombre': 'Jairo',
        'apellido': 'Soliz',
        'rolNombre': 'USUARIO_BASICO',
      });

      final user = await ds.verifyEmail('jairo@example.com', '482913');

      expect(user, isNotNull);
      expect(user!.token, 'jwt.emitido.al.verificar');
      expect(user.email, 'jairo@example.com');
      expect(user.role, 'basic_user');
    }));

    test('código inválido (400) se mapea a AppException', async_(() async {
      adapter.stub('POST', '/auth/verify-email', statusCode: 400, data: {
        'verified': false,
        'message': 'Código inválido o expirado. Verifica e intenta de nuevo.',
      });

      await expectLater(
        () => ds.verifyEmail('jairo@example.com', '000000'),
        throwsA(isA<AppException>()),
      );
    }));
  });
```

> El rol `USUARIO_BASICO` mapea a `'basic_user'` vía `rolId == 4` / `rolNombre` en `_parseAuthResponse`. Si el backend devolviera sólo `rolNombre`, verificar que ese camino esté cubierto en el parser antes de dar el test por bueno.

- [ ] **Step 2: Correr el test y verificar que falla**

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/flutter_app_saludable" && flutter test test/data/datasources/remote/auth_remote_data_source_test.dart
```

Esperado: error de compilación — `verifyEmail` devuelve `Future<bool>`, no tiene `.token`.

- [ ] **Step 3: Cambiar la interfaz**

En `lib/data/datasources/remote/auth_remote_data_source.dart`, en `abstract class AuthRemoteDataSource`, reemplazar:

```dart
  Future<bool> verifyEmail(String email, String code);
```

por:

```dart
  /// Verifica el OTP. Devuelve el [User] **con token** — es el único punto del
  /// registro por correo donde el backend emite sesión. Lanza si el código es
  /// inválido o si la respuesta no trae token.
  Future<User?> verifyEmail(String email, String code);
```

- [ ] **Step 4: Cambiar la implementación**

Reemplazar el método `verifyEmail` de `AuthRemoteDataSourceImpl` por:

```dart
  @override
  Future<User?> verifyEmail(String email, String code) async {
    try {
      final response = await _client.post('/auth/verify-email', data: {
        'email': email,
        'code': code,
      });
      if (response.statusCode == 200 && response.data['verified'] == true) {
        return _parseAuthResponse(response);
      }
      return null;
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e, fallback: 'Error al verificar el código');
    }
  }
```

- [ ] **Step 5: Correr el test y verificar que pasa**

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/flutter_app_saludable" && flutter test test/data/datasources/remote/auth_remote_data_source_test.dart
```

Esperado: PASS. Otros archivos de test todavía no compilan (el fake de `auth_provider_session_test.dart`) — se arregla en la Task 8.

- [ ] **Step 6: Commit** (junto con la Task 8)

---

### Task 8: El provider persiste la sesión sólo al verificar

**Files:**
- Modify: `flutter_app_saludable/lib/presentation/providers/auth_provider.dart:194-230` y `:241-260`
- Modify: `flutter_app_saludable/test/core/auth/auth_provider_session_test.dart` (el fake)

- [ ] **Step 1: Escribir el test que falla**

Agregar al final del `group('AuthProvider sesión', ...)` de `test/core/auth/auth_provider_session_test.dart`:

```dart
    test('register NO persiste sesión: queda pendiente de verificación', () async {
      remote.registerResult = User(
        id: '42',
        name: 'Test User',
        email: 'test@example.com',
        role: 'basic_user',
        // El backend ya no emite token en /register.
      );

      final ok = await auth.register(
          'Test', 'User', 'test@example.com', 'secret123', '+59170000000');

      expect(ok, isTrue);
      expect(auth.requiresVerification, isTrue);
      expect(auth.currentUser, isNull, reason: 'no debe haber sesión activa');
      expect(await tokenStore.read(), isNull, reason: 'no debe guardarse JWT');
    });

    test('verifyEmail persiste la sesión con el token emitido al verificar',
        () async {
      remote.verifyResult = User(
        id: '42',
        name: 'Test User',
        email: 'test@example.com',
        role: 'basic_user',
        token: fakeJwt,
      );

      final ok = await auth.verifyEmail('test@example.com', '482913');

      expect(ok, isTrue);
      expect(auth.requiresVerification, isFalse);
      expect(auth.currentUser?.id, '42');
      expect(await tokenStore.read(), fakeJwt);
    });

    test('verifyEmail con código inválido no crea sesión', () async {
      remote.verifyResult = null;

      final ok = await auth.verifyEmail('test@example.com', '000000');

      expect(ok, isFalse);
      expect(auth.currentUser, isNull);
      expect(await tokenStore.read(), isNull);
    });
```

Y actualizar el fake en el mismo archivo. Reemplazar:

```dart
  @override
  Future<bool> verifyEmail(String email, String code) async => true;
```

por:

```dart
  User? verifyResult;

  @override
  Future<User?> verifyEmail(String email, String code) async => verifyResult;
```

- [ ] **Step 2: Correr el test y verificar que falla**

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/flutter_app_saludable" && flutter test test/core/auth/auth_provider_session_test.dart
```

Esperado: FAIL — `register` sigue persistiendo la sesión, así que `auth.currentUser` no es `null`.

- [ ] **Step 3: Sacar la persistencia de `register`**

En `lib/presentation/providers/auth_provider.dart`, reemplazar el cuerpo del `try` de `register`:

```dart
      final user = await _remoteDataSource.register(
        nombre,
        apellido,
        email,
        password,
        telefono,
        rolId: rolId,
      );
      logDebug('[DEBUG AUTH_PROVIDER] Usuario registrado id=${user.id}');

      await _persistAuthenticatedSession(user);

      _requiresVerification = true;
      _isLoading = false;
      notifyListeners();
      return true;
```

por:

```dart
      final user = await _remoteDataSource.register(
        nombre,
        apellido,
        email,
        password,
        telefono,
        rolId: rolId,
      );
      logDebug('[DEBUG AUTH_PROVIDER] Usuario registrado id=${user.id}');

      // NO se persiste sesión acá: el backend ya no emite token en /register.
      // La sesión nace en verifyEmail(). Si se persistiera acá, cerrar la app
      // saltaría la verificación por completo.
      _requiresVerification = true;
      _isLoading = false;
      notifyListeners();
      return true;
```

- [ ] **Step 4: Persistir en `verifyEmail`**

Reemplazar el cuerpo del `try` de `verifyEmail` en el mismo archivo:

```dart
      final verified = await _remoteDataSource.verifyEmail(email, code);

      if (verified) {
        _requiresVerification = false;
        logDebug('[DEBUG AUTH_PROVIDER] Correo verificado exitosamente');
      } else {
        _errorMessage = 'Código inválido o expirado. Intenta de nuevo.';
      }

      _isLoading = false;
      notifyListeners();
      return verified;
```

por:

```dart
      final user = await _remoteDataSource.verifyEmail(email, code);

      if (user == null) {
        _errorMessage = 'Código inválido o expirado. Intenta de nuevo.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Recién acá nace la sesión: el JWT lo emite /verify-email.
      await _persistAuthenticatedSession(user);
      _requiresVerification = false;
      logDebug('[DEBUG AUTH_PROVIDER] Correo verificado exitosamente');

      _isLoading = false;
      notifyListeners();
      return true;
```

- [ ] **Step 5: Correr los tests y verificar que pasan**

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/flutter_app_saludable" && flutter test
```

Esperado: toda la suite en verde. Si `auth_provider_extra_test.dart` o `session_401_and_errors_test.dart` tienen su propio fake de `AuthRemoteDataSource`, hay que aplicarles el mismo cambio de firma de `verifyEmail`.

- [ ] **Step 6: Commit**

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/flutter_app_saludable" && git add lib/data/datasources/remote/auth_remote_data_source.dart lib/presentation/providers/auth_provider.dart test/ && git commit -m "fix(auth): persistir la sesion solo tras verificar el correo"
```

---

### Task 9: La pantalla de OTP publica el usuario verificado

**Contexto:** `email_verification_screen.dart:167` navega a `/basic-home` tras verificar, pero nunca setea el `UserProvider` — eso lo hacía `register_screen.dart:346` en el camino sin verificación, que ahora ya no se toma.

**Files:**
- Modify: `flutter_app_saludable/lib/presentation/screens/auth/email_verification_screen.dart:117-168`

- [ ] **Step 1: Setear el `UserProvider` antes de navegar**

En `_verify()` (o el método que contiene la línea `final verified = await auth.verifyEmail(...)`), después de confirmar que `verified` es `true` y antes de `context.go('/basic-home')`, agregar:

```dart
        final user = auth.currentUser;
        if (user != null && context.mounted) {
          Provider.of<UserProvider>(context, listen: false).setUser(user);
        }
```

Y asegurar los imports en el archivo:

```dart
import 'package:provider/provider.dart';
import 'package:flutter_app_saludable/presentation/providers/user_provider.dart';
```

- [ ] **Step 2: Verificar que compila y la suite sigue verde**

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/flutter_app_saludable" && flutter analyze && flutter test
```

Esperado: `No issues found` y toda la suite en verde.

- [ ] **Step 3: Probar el flujo completo a mano**

Con el backend de la Fase 2 desplegado:

1. Registrarse con un correo real → debe llevar a la pantalla del OTP.
2. **Cerrar la app por completo y volver a abrirla** → debe caer en `/guest-home`, **no** en `/basic-home`. Éste es el bug original; si sigue entrando, la Task 8 no quedó bien.
3. Volver a registrarse / usar "Reenviar código", ingresar el OTP del correo → debe entrar a `/basic-home`.
4. Cerrar y reabrir → ahora sí debe entrar directo.

- [ ] **Step 4: Commit**

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/flutter_app_saludable" && git add lib/presentation/screens/auth/email_verification_screen.dart && git commit -m "fix(verify-email): publicar el usuario verificado en UserProvider"
```

---

# FASE 4 — `/register` deja de emitir token y de ocultar fallos

Requiere que la Fase 3 esté **publicada en la app**. Este cambio rompe versiones viejas de la app instaladas en teléfonos: ver el aviso al final de la task.

### Task 10: `register` sin token y con el fallo de envío visible

**Files:**
- Modify: `Pasantias_Backend/src/main/java/com/example/herbalife_clubes/serviceimpls/AuthServiceImpl.java:84-104` y `:248-268`
- Modify: `Pasantias_Backend/src/main/java/com/example/herbalife_clubes/serviceimpls/EmailServiceImpl.java:41-45`
- Test: `Pasantias_Backend/src/test/java/com/example/herbalife_clubes/services/AuthServiceRegisterTest.java`

- [ ] **Step 1: Escribir el test que falla**

Crear `src/test/java/com/example/herbalife_clubes/services/AuthServiceRegisterTest.java`:

```java
package com.example.herbalife_clubes.services;

import com.example.herbalife_clubes.dtos.auth.RegisterRequest;
import com.example.herbalife_clubes.entities.Rol;
import com.example.herbalife_clubes.entities.Usuario;
import com.example.herbalife_clubes.repositories.RolRepository;
import com.example.herbalife_clubes.repositories.UsuarioRepository;
import com.example.herbalife_clubes.security.JwtService;
import com.example.herbalife_clubes.serviceimpls.AuthServiceImpl;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class AuthServiceRegisterTest {

    @Mock private UsuarioRepository usuarioRepository;
    @Mock private RolRepository rolRepository;
    @Mock private PasswordEncoder passwordEncoder;
    @Mock private JwtService jwtService;
    @Mock private AuthenticationManager authenticationManager;
    @Mock private VerificationService verificationService;

    @InjectMocks
    private AuthServiceImpl authService;

    private RegisterRequest request() {
        RegisterRequest r = new RegisterRequest();
        r.setNombre("Jairo");
        r.setApellido("Soliz");
        r.setEmail("jairo@example.com");
        r.setPassword("secret123");
        r.setTelefono("+59170000000");
        return r;
    }

    private void stubRolYGuardado() {
        Rol rol = new Rol();
        rol.setId(4);
        rol.setNombre("USUARIO_BASICO");
        when(rolRepository.findByNombre("USUARIO_BASICO")).thenReturn(Optional.of(rol));
        when(passwordEncoder.encode(any())).thenReturn("hash");
        when(usuarioRepository.save(any(Usuario.class))).thenAnswer(i -> {
            Usuario u = i.getArgument(0);
            u.setId(42);
            return u;
        });
    }

    @Test
    void registerNoDevuelveTokenYMarcaVerificacionPendiente() {
        stubRolYGuardado();

        var respuesta = authService.register(request());

        assertNull(respuesta.getToken(),
                "El token debe emitirse en verify-email, no acá");
        assertTrue(respuesta.isRequiresVerification());
        assertEquals("jairo@example.com", respuesta.getEmail());
        verify(jwtService, never()).generateToken(any());
    }

    @Test
    void registerFallaSiNoSePudoEnviarElCodigo() {
        stubRolYGuardado();
        doThrow(new RuntimeException("Connect timed out"))
                .when(verificationService).generateAndSendCode(any(Usuario.class));

        RuntimeException ex = assertThrows(RuntimeException.class,
                () -> authService.register(request()));

        assertTrue(ex.getMessage().toLowerCase().contains("código")
                        || ex.getMessage().toLowerCase().contains("codigo")
                        || ex.getMessage().toLowerCase().contains("correo"),
                "El registro no puede reportar éxito si el OTP nunca salió");
    }

    @Test
    void registerDejaAlUsuarioPendienteDeVerificacion() {
        stubRolYGuardado();

        authService.register(request());

        var captor = org.mockito.ArgumentCaptor.forClass(Usuario.class);
        verify(usuarioRepository).save(captor.capture());
        assertEquals("PENDIENTE_VERIFICACION", captor.getValue().getEstado());
    }
}
```

- [ ] **Step 2: Correr el test y verificar que falla**

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/Pasantias_Backend" && ./mvnw test -Dtest=AuthServiceRegisterTest
```

Esperado: FAIL en `registerNoDevuelveTokenYMarcaVerificacionPendiente` (el token no es null) y en `registerFallaSiNoSePudoEnviarElCodigo` (no lanza, se lo traga).

- [ ] **Step 3: Crear la excepción**

Crear `src/main/java/com/example/herbalife_clubes/exceptions/EmailDeliveryException.java`:

```java
package com.example.herbalife_clubes.exceptions;

/**
 * El correo de verificación no pudo entregarse al proveedor SMTP.
 *
 * Es un fallo de infraestructura, no del usuario: se mapea a 503 para que el
 * cliente sepa que puede reintentar.
 */
public class EmailDeliveryException extends RuntimeException {
    public EmailDeliveryException(String message, Throwable cause) {
        super(message, cause);
    }
}
```

- [ ] **Step 4: Reescribir el final de `register`**

En `src/main/java/com/example/herbalife_clubes/serviceimpls/AuthServiceImpl.java`, agregar el import:

```java
import com.example.herbalife_clubes.exceptions.EmailDeliveryException;
```

Y reemplazar desde `usuarioRepository.save(usuario);` hasta el `return` del método `register`:

```java
        usuarioRepository.save(usuario);

        // Enviar código de verificación por correo
        try {
            verificationService.generateAndSendCode(usuario);
        } catch (Exception e) {
            log.error("Error al enviar código de verificación para {}: {}", usuario.getEmail(), e.getMessage());
            // No fallar el registro, el usuario podrá reenviar el código
        }

        String jwtToken = jwtService.generateToken(usuario);

        return AuthenticationResponse.builder()
                .token(jwtToken)
                .userId(usuario.getId())
                .email(usuario.getEmail())
                .nombre(usuario.getNombre())
                .apellido(usuario.getApellido())
                .rolNombre(usuario.getRol().getNombre())
                .requiresVerification(true)
                .build();
```

por:

```java
        usuarioRepository.save(usuario);

        // El fallo de envío NO se oculta: si el OTP no salió, el usuario queda
        // atrapado sin forma de activarse y sin saber por qué. Que el registro
        // devolviera 200 con el correo caído es lo que dejó este bug invisible
        // durante meses.
        try {
            verificationService.generateAndSendCode(usuario);
        } catch (Exception e) {
            log.error("Error al enviar código de verificación para {}: {}",
                    usuario.getEmail(), e.getMessage(), e);
            throw new EmailDeliveryException(
                    "No pudimos enviar el código de verificación a tu correo. "
                            + "Revisa la dirección o intenta de nuevo en unos minutos.", e);
        }

        // Sin token: la sesión se emite en /verify-email, no acá.
        return AuthenticationResponse.builder()
                .userId(usuario.getId())
                .email(usuario.getEmail())
                .nombre(usuario.getNombre())
                .apellido(usuario.getApellido())
                .rolNombre(usuario.getRol().getNombre())
                .requiresVerification(true)
                .build();
```

- [ ] **Step 5: Mapear la excepción a 503**

El handler global del proyecto es `src/main/java/com/example/herbalife_clubes/exceptions/GlobalExceptionHandler.java` (`@ControllerAdvice`), y devuelve `ApiResponse` en todos sus handlers. Agregar ahí, junto a `handleConflict`:

```java
    /**
     * El OTP no pudo entregarse (SMTP caído, puerto bloqueado, remitente no
     * verificado). Es infraestructura, no culpa del usuario: 503 para que el
     * cliente lo presente como reintentable.
     */
    @ExceptionHandler(EmailDeliveryException.class)
    public ResponseEntity<ApiResponse<Void>> handleEmailDelivery(EmailDeliveryException ex) {
        log.error("Fallo de entrega de correo: {}", ex.getMessage(), ex);
        return ResponseEntity
                .status(HttpStatus.SERVICE_UNAVAILABLE)
                .body(ApiResponse.fail(ex.getMessage()));
    }
```

No hacen falta imports nuevos: `ApiResponse`, `HttpStatus`, `ResponseEntity` y `ExceptionHandler` ya están importados en ese archivo, `EmailDeliveryException` vive en el mismo paquete, y `log` viene del `@Slf4j` de la clase.

- [ ] **Step 6: Aplicar el mismo tratamiento a `registerBasico`**

En el mismo archivo, en `registerBasico`, reemplazar:

```java
        try {
            verificationService.generateAndSendCode(usuario);
        } catch (Exception e) {
            log.error("Error al enviar código de verificación para {}: {}", usuario.getEmail(), e.getMessage());
        }
```

por:

```java
        try {
            verificationService.generateAndSendCode(usuario);
        } catch (Exception e) {
            log.error("Error al enviar código de verificación para {}: {}",
                    usuario.getEmail(), e.getMessage(), e);
            throw new EmailDeliveryException(
                    "No pudimos enviar el código de verificación a tu correo. "
                            + "Revisa la dirección o intenta de nuevo en unos minutos.", e);
        }
```

> `registerBasico` no lo consume la app Flutter hoy (`/auth/register-basico` sólo figura en `public_api_paths.dart` como ruta pública), pero comparte el mismo defecto y se corrige por consistencia. Su token sí se deja: se emite junto con el QR de activación y cambiarlo excede el alcance de este plan.

- [ ] **Step 7: Limpiar el catch muerto de `EmailServiceImpl`**

En `EmailServiceImpl.java`, el `catch (MessagingException e)` no atrapa los fallos de envío reales — `mailSender.send()` lanza `MailException`, que es unchecked y no hereda de `MessagingException`. Reemplazar el bloque catch:

```java
        } catch (MessagingException e) {
            log.error("Error al enviar correo de verificación a {}: {}", to, e.getMessage());
            throw new RuntimeException("Error al enviar el correo de verificación. Intente nuevamente.", e);
        }
```

por:

```java
        } catch (MessagingException | org.springframework.mail.MailException e) {
            // MessagingException: fallo al armar el mensaje (dirección inválida, etc.)
            // MailException: fallo al entregarlo (timeout, auth, remitente no verificado).
            log.error("Error al enviar correo de verificación a {}: {}", to, e.getMessage(), e);
            throw new RuntimeException("Error al enviar el correo de verificación: " + e.getMessage(), e);
        }
```

- [ ] **Step 8: Correr toda la suite**

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/Pasantias_Backend" && ./mvnw test
```

Esperado: BUILD SUCCESS.

- [ ] **Step 9: Commit**

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/Pasantias_Backend" && git add src/main/java/com/example/herbalife_clubes/ src/test/java/com/example/herbalife_clubes/services/AuthServiceRegisterTest.java && git commit -m "fix(auth): register sin token y sin ocultar fallos de envio"
```

> ⚠️ **Antes de desplegar esta fase:** las apps ya instaladas que no tengan la Fase 3 van a romperse al registrarse (Flutter lanza `ValidationException: La respuesta de autenticación no incluyó token`). Publicar primero la versión de la app con las Tasks 7-9 y darle tiempo a propagarse, o forzar actualización mínima. Los usuarios ya logueados no se ven afectados: su token sigue siendo válido.

---

# FASE 5 — Un token de usuario no verificado no sirve para nada

Es la que cierra el agujero de verdad. Requiere un paso de datos previo.

### Task 11: Auditar y sanear los usuarios existentes

**Contexto:** `Usuario.isEnabled()` devuelve `true` sólo si `estado` es `"ACTIVO"` o `null`. En cuanto el filtro JWT empiece a respetarlo (Task 12), **cualquier usuario con otro `estado` queda fuera**. Hay que saber qué valores existen realmente antes de activar el chequeo.

**Files:** ninguno — es trabajo sobre la BD de producción.

- [ ] **Step 1: Ver qué estados existen**

```sql
SELECT estado, COUNT(*) FROM usuarios GROUP BY estado ORDER BY 2 DESC;
```

- [ ] **Step 2: Decidir por cada estado**

| Estado encontrado | Acción |
|---|---|
| `ACTIVO` | Nada, siguen entrando |
| `NULL` | Nada, `isEnabled()` los deja pasar (usuarios previos al campo) |
| `PENDIENTE_VERIFICACION` | Los creados por este bug. Ver Step 3 |
| `BLOQUEADO` | Correcto que queden fuera |
| Cualquier otro valor | **Parar y revisar antes de seguir** — un estado inesperado bloquearía usuarios legítimos |

- [ ] **Step 3: Sanear los pendientes**

```sql
-- Cuántos son y de cuándo
SELECT id, email, created_at FROM usuarios
WHERE estado = 'PENDIENTE_VERIFICACION' ORDER BY created_at DESC;
```

Para los que sean cuentas reales de prueba tuyas o de tu compañera, activarlos a mano:

```sql
UPDATE usuarios SET estado = 'ACTIVO' WHERE email IN ('tu@correo.com', 'otro@correo.com');
```

Para el resto (registros abandonados que nunca verificaron), borrarlos. El `ON DELETE` de `verification_codes` no es cascade, así que primero van los códigos:

```sql
DELETE FROM verification_codes WHERE usuario_id IN (
    SELECT id FROM usuarios
    WHERE estado = 'PENDIENTE_VERIFICACION' AND created_at < NOW() - INTERVAL '24 hours'
);

DELETE FROM usuarios
WHERE estado = 'PENDIENTE_VERIFICACION' AND created_at < NOW() - INTERVAL '24 hours';
```

> Hacer backup de la base antes de correr los DELETE. Si algún usuario pendiente tiene membresías o pedidos asociados, el DELETE va a fallar por FK — en ese caso activarlo en vez de borrarlo.

- [ ] **Step 4: Confirmar que quedó limpio**

```sql
SELECT estado, COUNT(*) FROM usuarios GROUP BY estado;
```

Esperado: sólo `ACTIVO`, `NULL` y eventualmente `BLOQUEADO`.

---

### Task 12: El filtro JWT rechaza usuarios no habilitados

**Files:**
- Modify: `Pasantias_Backend/src/main/java/com/example/herbalife_clubes/security/JwtAuthenticationFilter.java:47-68`
- Test: `Pasantias_Backend/src/test/java/com/example/herbalife_clubes/security/JwtAuthenticationFilterTest.java`

- [ ] **Step 1: Escribir el test que falla**

Crear `src/test/java/com/example/herbalife_clubes/security/JwtAuthenticationFilterTest.java`:

```java
package com.example.herbalife_clubes.security;

import com.example.herbalife_clubes.entities.Rol;
import com.example.herbalife_clubes.entities.Usuario;
import jakarta.servlet.FilterChain;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpHeaders;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetailsService;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class JwtAuthenticationFilterTest {

    private static final String TOKEN = "un.jwt.cualquiera";
    private static final String EMAIL = "jairo@example.com";

    @Mock private JwtService jwtService;
    @Mock private UserDetailsService userDetailsService;
    @Mock private FilterChain filterChain;

    @InjectMocks
    private JwtAuthenticationFilter filter;

    @AfterEach
    void limpiarContexto() {
        SecurityContextHolder.clearContext();
    }

    private Usuario usuarioCon(String estado) {
        Rol rol = new Rol();
        rol.setId(4);
        rol.setNombre("USUARIO_BASICO");
        Usuario u = new Usuario();
        u.setId(42);
        u.setEmail(EMAIL);
        u.setPasswordHash("hash");
        u.setEstado(estado);
        u.setRol(rol);
        return u;
    }

    private MockHttpServletRequest requestConToken() {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.addHeader(HttpHeaders.AUTHORIZATION, "Bearer " + TOKEN);
        return request;
    }

    @Test
    void noAutenticaAUsuarioPendienteDeVerificacion() throws Exception {
        Usuario pendiente = usuarioCon("PENDIENTE_VERIFICACION");
        when(jwtService.extractUsername(TOKEN)).thenReturn(EMAIL);
        when(userDetailsService.loadUserByUsername(EMAIL)).thenReturn(pendiente);

        filter.doFilter(requestConToken(), new MockHttpServletResponse(), filterChain);

        assertNull(SecurityContextHolder.getContext().getAuthentication(),
                "Un usuario sin verificar no puede quedar autenticado");
        verify(jwtService, never()).isTokenValid(any(), any());
        verify(filterChain).doFilter(any(), any());
    }

    @Test
    void autenticaAUsuarioActivoConTokenValido() throws Exception {
        Usuario activo = usuarioCon("ACTIVO");
        when(jwtService.extractUsername(TOKEN)).thenReturn(EMAIL);
        when(userDetailsService.loadUserByUsername(EMAIL)).thenReturn(activo);
        when(jwtService.isTokenValid(eq(TOKEN), eq(activo))).thenReturn(true);

        filter.doFilter(requestConToken(), new MockHttpServletResponse(), filterChain);

        assertNotNull(SecurityContextHolder.getContext().getAuthentication());
        assertEquals(EMAIL,
                SecurityContextHolder.getContext().getAuthentication().getName());
    }

    @Test
    void noAutenticaAUsuarioBloqueado() throws Exception {
        Usuario bloqueado = usuarioCon("BLOQUEADO");
        when(jwtService.extractUsername(TOKEN)).thenReturn(EMAIL);
        when(userDetailsService.loadUserByUsername(EMAIL)).thenReturn(bloqueado);

        filter.doFilter(requestConToken(), new MockHttpServletResponse(), filterChain);

        assertNull(SecurityContextHolder.getContext().getAuthentication());
    }
}
```

- [ ] **Step 2: Correr el test y verificar que falla**

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/Pasantias_Backend" && ./mvnw test -Dtest=JwtAuthenticationFilterTest
```

Esperado: FAIL en `noAutenticaAUsuarioPendienteDeVerificacion` y `noAutenticaAUsuarioBloqueado` — hoy el filtro no consulta el estado.

- [ ] **Step 3: Agregar el chequeo**

En `src/main/java/com/example/herbalife_clubes/security/JwtAuthenticationFilter.java`, reemplazar el bloque interno del `try`:

```java
                UserDetails userDetails = this.userDetailsService.loadUserByUsername(username);

                if (jwtService.isTokenValid(jwt, userDetails)) {
```

por:

```java
                UserDetails userDetails = this.userDetailsService.loadUserByUsername(username);

                // Un token criptográficamente válido no alcanza: el usuario tiene
                // que estar habilitado y no bloqueado. Sin esto, el JWT emitido a
                // una cuenta sin verificar abre toda la API.
                if (!userDetails.isEnabled() || !userDetails.isAccountNonLocked()) {
                    logger.warn("Token de usuario deshabilitado o bloqueado; se continúa como anónimo");
                    filterChain.doFilter(request, response);
                    return;
                }

                if (jwtService.isTokenValid(jwt, userDetails)) {
```

- [ ] **Step 4: Correr los tests y verificar que pasan**

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/Pasantias_Backend" && ./mvnw test -Dtest=JwtAuthenticationFilterTest
```

Esperado: PASS, 3 tests.

- [ ] **Step 5: Correr toda la suite**

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/Pasantias_Backend" && ./mvnw test
```

Esperado: BUILD SUCCESS.

- [ ] **Step 6: Commit**

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/Pasantias_Backend" && git add src/main/java/com/example/herbalife_clubes/security/JwtAuthenticationFilter.java src/test/java/com/example/herbalife_clubes/security/JwtAuthenticationFilterTest.java && git commit -m "fix(security): rechazar tokens de usuarios no habilitados"
```

- [ ] **Step 7: Verificación manual post-deploy**

Con la Task 11 ya ejecutada, desplegar y comprobar:

1. Un usuario ya activo sigue entrando normal.
2. Registrar uno nuevo, copiar el `userId`, y forzar `estado = 'PENDIENTE_VERIFICACION'` en la BD. Con su token, `GET /api/auth/me` debe devolver **403**, no 200.

---

# FASE 6 — Higiene

### Task 13: Purgar registros pendientes vencidos

**Contexto:** Con todo lo anterior, un registro abandonado deja una fila muerta en `usuarios` que ocupa el email (la columna es `UNIQUE`), impidiendo que esa persona se vuelva a registrar. Hay que limpiarlas.

**Files:**
- Create: `Pasantias_Backend/src/main/java/com/example/herbalife_clubes/scheduled/PendingRegistrationCleanup.java`
- Modify: `Pasantias_Backend/src/main/java/com/example/herbalife_clubes/HerbalifeClubesApplication.java`
- Modify: `Pasantias_Backend/src/main/java/com/example/herbalife_clubes/repositories/UsuarioRepository.java`
- Modify: `Pasantias_Backend/src/main/java/com/example/herbalife_clubes/repositories/VerificationCodeRepository.java`

- [ ] **Step 1: Agregar las queries de purga**

En `UsuarioRepository.java`, agregar los imports necesarios y el método:

```java
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.time.LocalDateTime;
import java.util.List;
```

```java
    /**
     * Registros que nunca completaron la verificación de correo y ya vencieron.
     * Ocupan el email (columna UNIQUE) impidiendo que la persona se re-registre.
     */
    @Query("SELECT u FROM Usuario u WHERE u.estado = 'PENDIENTE_VERIFICACION' AND u.createdAt < :limite")
    List<Usuario> findPendientesVencidos(@Param("limite") LocalDateTime limite);
```

En `VerificationCodeRepository.java`, agregar:

```java
    /**
     * Borra los códigos de un conjunto de usuarios. La FK de verification_codes
     * no es ON DELETE CASCADE, así que hay que limpiarlos antes de borrar usuarios.
     */
    @Modifying
    @Query("DELETE FROM VerificationCode vc WHERE vc.usuario IN :usuarios")
    void deleteByUsuarioIn(@Param("usuarios") java.util.List<Usuario> usuarios);
```

- [ ] **Step 2: Crear el job**

Crear `src/main/java/com/example/herbalife_clubes/scheduled/PendingRegistrationCleanup.java`:

```java
package com.example.herbalife_clubes.scheduled;

import com.example.herbalife_clubes.entities.Usuario;
import com.example.herbalife_clubes.repositories.UsuarioRepository;
import com.example.herbalife_clubes.repositories.VerificationCodeRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

/**
 * Borra los registros que nunca verificaron su correo.
 *
 * Sin esto, un registro abandonado deja el email ocupado para siempre (usuarios.email
 * es UNIQUE) y la persona no puede volver a intentarlo.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class PendingRegistrationCleanup {

    private final UsuarioRepository usuarioRepository;
    private final VerificationCodeRepository verificationCodeRepository;

    @Value("${app.verification.pending-ttl-hours:24}")
    private int pendingTtlHours;

    /** Todos los días a las 04:00. */
    @Scheduled(cron = "${app.verification.cleanup-cron:0 0 4 * * *}")
    @Transactional
    public void purgarRegistrosPendientes() {
        LocalDateTime limite = LocalDateTime.now().minusHours(pendingTtlHours);
        List<Usuario> vencidos = usuarioRepository.findPendientesVencidos(limite);

        if (vencidos.isEmpty()) {
            log.debug("Purga de registros pendientes: nada que borrar");
            return;
        }

        verificationCodeRepository.deleteByUsuarioIn(vencidos);
        usuarioRepository.deleteAll(vencidos);

        log.info("Purga de registros pendientes: {} usuarios eliminados (más de {}h sin verificar)",
                vencidos.size(), pendingTtlHours);
    }
}
```

- [ ] **Step 3: Habilitar el scheduling**

En `src/main/java/com/example/herbalife_clubes/HerbalifeClubesApplication.java`, agregar el import y la anotación sobre la clase:

```java
import org.springframework.scheduling.annotation.EnableScheduling;
```

```java
@SpringBootApplication
@EnableScheduling
public class HerbalifeClubesApplication {
```

- [ ] **Step 4: Agregar las propiedades**

En `application.properties`, bajo el bloque de verificación:

```properties
# Horas que sobrevive un registro sin verificar antes de purgarse.
app.verification.pending-ttl-hours=24
# Cron de la purga (por defecto, 04:00 todos los días).
app.verification.cleanup-cron=0 0 4 * * *
```

- [ ] **Step 5: Verificar que el contexto levanta**

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/Pasantias_Backend" && ./mvnw test
```

Esperado: BUILD SUCCESS. `HerbalifeClubesApplicationTests` valida que el contexto de Spring carga con el nuevo bean y el scheduling activo.

- [ ] **Step 6: Commit**

```bash
cd "C:/Users/Jairo/Documents/Flutter Quillo/Pasantias_Backend" && git add src/main/java/com/example/herbalife_clubes/ src/main/resources/application.properties && git commit -m "feat(auth): purgar registros sin verificar vencidos"
```

---

## Checklist de cierre

Antes de dar el trabajo por terminado, comprobar contra producción:

- [ ] Registrarse con un correo real → el OTP llega a la bandeja (no a spam)
- [ ] El correo dice "Nutrition Clubs", no "Nutrilife Club"
- [ ] Cerrar la app en la pantalla del OTP y reabrirla → cae en `/guest-home`, no adentro
- [ ] Volver, ingresar el OTP correcto → entra a `/basic-home`
- [ ] Cerrar y reabrir → entra directo, sin pedir OTP otra vez
- [ ] Ingresar un OTP incorrecto → mensaje de error, sin sesión creada
- [ ] `SELECT estado, COUNT(*) FROM usuarios GROUP BY estado;` → sin `PENDIENTE_VERIFICACION` viejos
- [ ] Login con Google sigue funcionando (esos usuarios nacen `ACTIVO` y no pasan por OTP)
- [ ] `./mvnw test` y `flutter test` en verde en ambos repos

## Fuera de alcance

Anotado para no perderlo, pero **no** forma parte de este plan:

- **No crear la fila en `usuarios` hasta verificar.** Requiere una tabla `registros_pendientes` y mover la creación del usuario a `/verify-email`. Este plan usa el enfoque estándar (crear inerte + activar + purgar), que consigue el mismo efecto observable con bastante menos código.
- **Migrar a la API HTTP de Brevo (puerto 443).** Sólo hace falta si Render llega a cerrar también el 2525.
- **`/register-basico` sin token.** Emite el token junto al QR de activación; cambiarlo toca el flujo de anfitriones.
- **Verificación de correo para usuarios de Google.** Nacen `ACTIVO` porque Google ya verificó la dirección; es correcto.
