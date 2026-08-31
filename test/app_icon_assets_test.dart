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
    expect(text.contains('@drawable/ic_launcher_foreground'), isTrue);

    final colors = File('$res/values/colors.xml');
    expect(colors.existsSync(), isTrue, reason: 'falta ${colors.path}');
    expect(colors.readAsStringSync().contains('ic_launcher_background'), isTrue);

    final foreground = File('$res/drawable-xxxhdpi/ic_launcher_foreground.png');
    expect(foreground.existsSync(), isTrue, reason: 'falta ${foreground.path}');
    expect(_pngSize(foreground).width, 432);
  });

  test('el foreground no lleva inset extra que encoja el isotipo', () {
    // El foreground ya viene dimensionado para la zona segura del adaptive
    // icon (R/W = 0.30). Un inset > 0 lo encogería una segunda vez y el
    // isotipo se vería diminuto en el lanzador.
    final text =
        File('$res/mipmap-anydpi-v26/ic_launcher.xml').readAsStringSync();
    final inset = RegExp(r'android:inset\s*=\s*"(\d+)%"').firstMatch(text);
    if (inset != null) {
      expect(
        inset.group(1),
        '0',
        reason: 'adaptive_icon_foreground_inset debe ser 0 en pubspec.yaml',
      );
    }
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
