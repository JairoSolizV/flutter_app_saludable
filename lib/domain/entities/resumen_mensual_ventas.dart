class ResumenMesKpi {
  final int totalVentas;
  final double totalIngresosBs;

  const ResumenMesKpi({
    required this.totalVentas,
    required this.totalIngresosBs,
  });

  factory ResumenMesKpi.fromJson(Map<String, dynamic> json) {
    return ResumenMesKpi(
      totalVentas: (json['totalVentas'] as num?)?.toInt() ?? 0,
      totalIngresosBs: (json['totalIngresosBs'] as num?)?.toDouble() ?? 0,
    );
  }
}

class VentasPorDiaMes {
  final DateTime fecha;
  final int totalVentas;
  final double totalIngresosBs;

  const VentasPorDiaMes({
    required this.fecha,
    required this.totalVentas,
    required this.totalIngresosBs,
  });

  factory VentasPorDiaMes.fromJson(Map<String, dynamic> json) {
    return VentasPorDiaMes(
      fecha: DateTime.parse(json['fecha'] as String),
      totalVentas: (json['totalVentas'] as num?)?.toInt() ?? 0,
      totalIngresosBs: (json['totalIngresosBs'] as num?)?.toDouble() ?? 0,
    );
  }
}

class TopProductoMes {
  final int? productoId;
  final String nombre;
  final int cantidadVendida;

  const TopProductoMes({
    this.productoId,
    required this.nombre,
    required this.cantidadVendida,
  });

  factory TopProductoMes.fromJson(Map<String, dynamic> json) {
    return TopProductoMes(
      productoId: json['productoId'] as int?,
      nombre: json['nombre'] as String? ?? '',
      cantidadVendida: (json['cantidadVendida'] as num?)?.toInt() ?? 0,
    );
  }
}

class ResumenMensualVentas {
  final int clubId;
  final String nombreClub;
  final int anio;
  final int mes;
  final String nombreMes;
  final ResumenMesKpi resumen;
  final List<VentasPorDiaMes> ventasPorDia;
  final List<TopProductoMes> topProductos;

  const ResumenMensualVentas({
    required this.clubId,
    required this.nombreClub,
    required this.anio,
    required this.mes,
    required this.nombreMes,
    required this.resumen,
    this.ventasPorDia = const [],
    this.topProductos = const [],
  });

  factory ResumenMensualVentas.fromJson(Map<String, dynamic> json) {
    final ventasRaw = json['ventasPorDia'] as List<dynamic>? ?? [];
    final topRaw = json['topProductos'] as List<dynamic>? ?? [];
    return ResumenMensualVentas(
      clubId: (json['clubId'] as num?)?.toInt() ?? 0,
      nombreClub: json['nombreClub'] as String? ?? '',
      anio: (json['anio'] as num?)?.toInt() ?? 0,
      mes: (json['mes'] as num?)?.toInt() ?? 0,
      nombreMes: json['nombreMes'] as String? ?? '',
      resumen: ResumenMesKpi.fromJson(json['resumen'] as Map<String, dynamic>),
      ventasPorDia: ventasRaw
          .map((e) => VentasPorDiaMes.fromJson(e as Map<String, dynamic>))
          .toList(),
      topProductos: topRaw
          .map((e) => TopProductoMes.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  String get etiquetaPeriodo => '$nombreMes $anio';
}
