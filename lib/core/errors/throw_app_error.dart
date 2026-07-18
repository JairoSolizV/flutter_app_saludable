import 'package:dio/dio.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/core/errors/error_mapper.dart';

/// Convierte errores de red a [AppException] sin re-envolver tipos ya mapeados.
Never throwAppError(Object error, {String? fallback, StackTrace? stackTrace}) {
  final mapped = ErrorMapper.fromObject(error, fallback: fallback);
  Error.throwWithStackTrace(mapped, stackTrace ?? StackTrace.current);
}

/// Atajo para bloques `on DioException`.
Never throwDioAsApp(DioException e,
    {String? fallback, StackTrace? stackTrace}) {
  final mapped = ErrorMapper.fromDio(e, fallback: fallback);
  Error.throwWithStackTrace(mapped, stackTrace ?? StackTrace.current);
}

/// Si [error] ya es [AppException], lo relanza conservando stack; si no, mapea.
Never rethrowApp(Object error, {String? fallback, StackTrace? stackTrace}) {
  if (error is AppException) {
    Error.throwWithStackTrace(error, stackTrace ?? StackTrace.current);
  }
  final mapped = ErrorMapper.fromObject(error, fallback: fallback);
  Error.throwWithStackTrace(mapped, stackTrace ?? StackTrace.current);
}
