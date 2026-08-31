import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/app.dart';
import 'package:flutter_app_saludable/core/di/app_dependencies.dart';

/// Entry point. Sin variables globales de dependencias.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dependencies = await AppDependencies.bootstrap();
  runApp(ExpandeApp(dependencies: dependencies));
}
