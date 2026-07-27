import java.io.File
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

/**
 * Credenciales de firma release.
 * Precedencia: variables de entorno NUTRILIFE_* > android/key.properties.
 * Nunca se imprimen valores; solo nombres de propiedades faltantes.
 */
data class ReleaseSigningInputs(
    val storeFile: File,
    val storePassword: String,
    val keyAlias: String,
    val keyPassword: String,
)

fun loadReleaseSigningInputs(project: Project): Pair<ReleaseSigningInputs?, List<String>> {
    val props = Properties()
    val propsFile = project.rootProject.file("key.properties")
    if (propsFile.exists()) {
        propsFile.inputStream().use { props.load(it) }
    }

    fun read(propKey: String, envKey: String): String? =
        System.getenv(envKey)?.trim()?.takeIf { it.isNotEmpty() }
            ?: props.getProperty(propKey)?.trim()?.takeIf { it.isNotEmpty() }

    val storeFileRaw = read("storeFile", "NUTRILIFE_KEYSTORE_PATH")
    val storePassword = read("storePassword", "NUTRILIFE_KEYSTORE_PASSWORD")
    val keyAlias = read("keyAlias", "NUTRILIFE_KEY_ALIAS")
    val keyPassword = read("keyPassword", "NUTRILIFE_KEY_PASSWORD")

    val missing = mutableListOf<String>()
    if (storeFileRaw == null) missing += "storeFile / NUTRILIFE_KEYSTORE_PATH"
    if (storePassword == null) missing += "storePassword / NUTRILIFE_KEYSTORE_PASSWORD"
    if (keyAlias == null) missing += "keyAlias / NUTRILIFE_KEY_ALIAS"
    if (keyPassword == null) missing += "keyPassword / NUTRILIFE_KEY_PASSWORD"
    if (missing.isNotEmpty()) {
        return null to missing
    }

    val candidate = File(storeFileRaw!!)
    val storeFile =
        if (candidate.isAbsolute) {
            candidate
        } else {
            project.rootProject.file(storeFileRaw)
        }
    if (!storeFile.isFile) {
        return null to
            listOf(
                "storeFile / NUTRILIFE_KEYSTORE_PATH (archivo keystore inexistente o inaccesible)",
            )
    }

    return ReleaseSigningInputs(
        storeFile = storeFile,
        storePassword = storePassword!!,
        keyAlias = keyAlias!!,
        keyPassword = keyPassword!!,
    ) to emptyList()
}

fun taskRequiresReleaseSigning(taskName: String): Boolean {
    return taskName.matches(Regex("""assemble.*Release""")) ||
        taskName.matches(Regex("""bundle.*Release""")) ||
        taskName.matches(Regex("""package.*Release(Bundle)?""")) ||
        taskName.matches(Regex("""sign.*Release.*""")) ||
        taskName == "validateSigningRelease"
}

val (releaseSigningInputs, releaseSigningMissing) = loadReleaseSigningInputs(project)

android {
    namespace = "com.nutritionclubs.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Identificador único y definitivo de la app en Google Play.
        applicationId = "com.nutritionclubs.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Solo se crea cuando hay credenciales reales. Sin fallback a debug.
        if (releaseSigningInputs != null) {
            create("release") {
                storeFile = releaseSigningInputs.storeFile
                storePassword = releaseSigningInputs.storePassword
                keyAlias = releaseSigningInputs.keyAlias
                keyPassword = releaseSigningInputs.keyPassword
            }
        }
    }

    buildTypes {
        release {
            // VULN-FL-04: nunca usar signingConfigs.debug aquí.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            if (releaseSigningInputs != null) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

// Bloquea assembleRelease / bundleRelease / firmas sin credenciales (sin unsigned silencioso).
gradle.taskGraph.whenReady {
    val releaseTasks = allTasks.filter { taskRequiresReleaseSigning(it.name) }
    if (releaseTasks.isNotEmpty() && releaseSigningInputs == null) {
        val missingList =
            if (releaseSigningMissing.isEmpty()) {
                "credenciales de firma release"
            } else {
                releaseSigningMissing.joinToString(", ")
            }
        throw GradleException(
            "VULN-FL-04: no se puede construir release sin firma oficial. " +
                "Falta o es inválido: $missingList. " +
                "Configure android/key.properties (local, fuera de Git) o las variables " +
                "NUTRILIFE_KEYSTORE_PATH, NUTRILIFE_KEYSTORE_PASSWORD, " +
                "NUTRILIFE_KEY_ALIAS, NUTRILIFE_KEY_PASSWORD. " +
                "No hay fallback a firma debug. Ver docs/ANDROID_RELEASE_BUILD.md.",
        )
    }
}

flutter {
    source = "../.."
}

/**
 * Validación estática anti-regresión VULN-FL-04.
 * No requiere keystore; segura para CI y desarrollo local.
 */
tasks.register("verifyReleaseSecurity") {
    group = "verification"
    description =
        "Verifica firma release, R8/shrinking y que secretos estén ignorados (VULN-FL-04)."

    doLast {
        val buildText = file("build.gradle.kts").readText()

        check(
            !Regex("""signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)""")
                .containsMatchIn(buildText),
        ) {
            "Existe asignación a signingConfigs.debug (prohibido para release)"
        }
        check(buildText.contains("""create("release")""")) {
            "Debe existir signingConfigs.create(\"release\") (condicional a credenciales)"
        }
        check(Regex("""isMinifyEnabled\s*=\s*true""").containsMatchIn(buildText)) {
            "isMinifyEnabled debe ser true en release"
        }
        check(Regex("""isShrinkResources\s*=\s*true""").containsMatchIn(buildText)) {
            "isShrinkResources debe ser true en release"
        }
        check(buildText.contains("proguard-android-optimize.txt")) {
            "Debe usarse proguard-android-optimize.txt"
        }
        check(buildText.contains("proguard-rules.pro")) {
            "Debe referenciar proguard-rules.pro"
        }

        val proguardFile = file("proguard-rules.pro")
        check(proguardFile.isFile) { "Falta android/app/proguard-rules.pro" }
        val proguardText = proguardFile.readText()
        check(!proguardText.contains("-dontobfuscate")) {
            "proguard-rules.pro no debe desactivar ofuscación (-dontobfuscate)"
        }
        check(!proguardText.contains("-dontshrink")) {
            "proguard-rules.pro no debe desactivar shrinking (-dontshrink)"
        }
        check(!Regex("""-keep\s+class\s+\*\*\s*\{\s*\*;\s*\}""").containsMatchIn(proguardText)) {
            "proguard-rules.pro no debe usar keep-all global"
        }
        check(!Regex("""(?m)^\s*-ignorewarnings\s*$""").containsMatchIn(proguardText)) {
            "proguard-rules.pro no debe usar -ignorewarnings global"
        }

        val gitignore = rootProject.file(".gitignore")
        check(gitignore.isFile) { "Falta android/.gitignore" }
        val ignoreText = gitignore.readText()
        check(ignoreText.contains("key.properties")) {
            "android/.gitignore debe ignorar key.properties"
        }
        check(ignoreText.contains("*.jks") || ignoreText.contains("**/*.jks")) {
            "android/.gitignore debe ignorar *.jks"
        }
        check(
            ignoreText.contains("*.keystore") || ignoreText.contains("**/*.keystore"),
        ) {
            "android/.gitignore debe ignorar *.keystore"
        }

        val example = rootProject.file("key.properties.example")
        check(example.isFile) { "Falta android/key.properties.example" }
        val exampleText = example.readText()
        check(
            !Regex("""(?m)^(storePassword|keyPassword)=android\s*$""")
                .containsMatchIn(exampleText),
        ) {
            "key.properties.example no debe usar la contraseña debug 'android'"
        }
        check(
            exampleText.contains("REEMPLAZAR_LOCALMENTE") ||
                exampleText.contains("REPLACE"),
        ) {
            "key.properties.example debe usar placeholders, no secretos reales"
        }

        val appIdMatch = Regex("""applicationId\s*=\s*"([^"]+)"""").find(buildText)
        check(appIdMatch != null && appIdMatch.groupValues[1] == "com.nutritionclubs.app") {
            "applicationId debe permanecer com.nutritionclubs.app"
        }

        logger.lifecycle("verifyReleaseSecurity: OK (VULN-FL-04)")
    }
}
