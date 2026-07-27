# NutriLife Club — reglas ProGuard / R8 (release)
#
# Principios (VULN-FL-04):
# - Reglas mínimas; no keep-all de la app.
# - No desactivar ofuscación ni shrinking.
# - No -ignorewarnings global.
# - Añadir keeps solo por reflexión/JNI documentada o fallo demostrado en release.
#
# Plugins Dart-only (Dio, Provider, go_router) no requieren reglas Android.
# mobile_scanner aporta consumer ProGuard en su AAR (ML Kit / Barhopper).
# flutter_secure_storage / sqflite / connectivity_plus: sin consumer rules
# propias en pub; se revisan si un build minificado falla en runtime.

# Atributos útiles para correlacionar crashes con mapping.txt de R8.
-keepattributes SourceFile,LineNumberTable,*Annotation*,Signature,InnerClasses,EnclosingMethod
-renamesourcefileattribute SourceFile

# Embedding Flutter / registro de plugins (reflexión en el engine y registrars).
# Motivo: sin estas clases, el arranque nativo de Flutter puede romperse con R8.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
