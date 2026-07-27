import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Validaciones estáticas VULN-FL-04 (sin keystore ni secretos).
void main() {
  final root = _projectRoot();
  final appGradle = File('${root.path}/android/app/build.gradle.kts');
  final proguard = File('${root.path}/android/app/proguard-rules.pro');
  final androidGitignore = File('${root.path}/android/.gitignore');
  final example = File('${root.path}/android/key.properties.example');

  test('release no referencia signingConfigs.debug', () {
    final text = appGradle.readAsStringSync();
    expect(
      RegExp(r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)')
          .hasMatch(text),
      isFalse,
    );
  });

  test('existe signingConfigs.release condicional', () {
    final text = appGradle.readAsStringSync();
    expect(text.contains('create("release")'), isTrue);
  });

  test('minify y resource shrinking activos en release', () {
    final text = appGradle.readAsStringSync();
    expect(RegExp(r'isMinifyEnabled\s*=\s*true').hasMatch(text), isTrue);
    expect(RegExp(r'isShrinkResources\s*=\s*true').hasMatch(text), isTrue);
    expect(text.contains('proguard-android-optimize.txt'), isTrue);
    expect(text.contains('proguard-rules.pro'), isTrue);
  });

  test('proguard-rules.pro no desactiva ofuscación ni usa keep-all', () {
    expect(proguard.existsSync(), isTrue);
    final text = proguard.readAsStringSync();
    expect(text.contains('-dontobfuscate'), isFalse);
    expect(text.contains('-dontshrink'), isFalse);
    expect(RegExp(r'-keep\s+class\s+\*\*\s*\{\s*\*;\s*\}').hasMatch(text), isFalse);
    expect(
      RegExp(r'^\s*-ignorewarnings\s*$', multiLine: true).hasMatch(text),
      isFalse,
    );
  });

  test('secretos ignorados y example sin password debug', () {
    final ignore = androidGitignore.readAsStringSync();
    expect(ignore.contains('key.properties'), isTrue);
    expect(ignore.contains('*.jks') || ignore.contains('**/*.jks'), isTrue);
    expect(
      ignore.contains('*.keystore') || ignore.contains('**/*.keystore'),
      isTrue,
    );

    final exampleText = example.readAsStringSync();
    expect(
      RegExp(
        r'^(storePassword|keyPassword)=android\s*$',
        multiLine: true,
      ).hasMatch(exampleText),
      isFalse,
    );
    expect(
      exampleText.contains('REEMPLAZAR_LOCALMENTE') ||
          exampleText.contains('REPLACE'),
      isTrue,
    );
  });

  test('applicationId permanece com.nutritionclubs.app', () {
    final text = appGradle.readAsStringSync();
    final match = RegExp(r'applicationId\s*=\s*"([^"]+)"').firstMatch(text);
    expect(match, isNotNull);
    expect(match!.group(1), 'com.nutritionclubs.app');
  });
}

Directory _projectRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    if (File('${dir.path}/pubspec.yaml').existsSync() &&
        Directory('${dir.path}/android').existsSync()) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return Directory.current;
}
