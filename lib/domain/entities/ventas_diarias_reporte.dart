class ProductoVentaDiaria {
  final int? productoId;
  final String nombre;
  final int cantidad;
  final bool esCombo;
  final double subtotal;

  const ProductoVentaDiaria({
    this.productoId,
    required this.nombre,
    required this.cantidad,
    this.esCombo = false,
    required this.subtotal,
  });

  factory ProductoVentaDiaria.fromJson(Map<String, dynamic> json) {
    return ProductoVentaDiaria(
      productoId: json['productoId'] as int?,
      nombre: json['nombre'] as String? ?? '',
      cantidad: (json['cantidad'] as num?)?.toInt() ?? 1,
      esCombo: json['esCombo'] as bool? ?? false,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
    );
  }

  String get etiquetaCorta => cantidad > 1 ? '$nombre (x$cantidad)' : nombre;
}

class RegistroVentaDiaria {
  final int numeroFila;
  final DateTime fecha;
  final String hora;
  final String nombre;
  final String estatusVisita;
  final String? numeroSocio;
  final List<ProductoVentaDiaria> productos;
  final String? tipoPago;
  final double totalBs;
  final String origen;
  final int pedidoId;

  const RegistroVentaDiaria({
    required this.numeroFila,
    required this.fecha,
    required this.hora,
    required this.nombre,
    required this.estatusVisita,
    this.numeroSocio,
    this.productos = const [],
    this.tipoPago,
    required this.totalBs,
    required this.origen,
    required this.pedidoId,
  });

  factory RegistroVentaDiaria.fromJson(Map<String, dynamic> json) {
    final productosJson = json['productos'] as List<dynamic>? ?? [];
    return RegistroVentaDiaria(
      numeroFila: (json['numeroFila'] as num?)?.toInt() ?? 0,
      fecha: DateTime.parse(json['fecha'] as String),
      hora: json['hora'] as String? ?? '',
      nombre: json['nombre'] as String? ?? '',
      estatusVisita: json['estatusVisita'] as String? ?? '',
      numeroSocio: json['numeroSocio'] as String?,
      productos: productosJson
          .map((e) => ProductoVentaDiaria.fromJson(e as Map<String, dynamic>))
          .toList(),
      tipoPago: json['tipoPago'] as String?,
      totalBs: (json['totalBs'] as num?)?.toDouble() ?? 0,
      origen: json['origen'] as String? ?? '',
      pedidoId: (json['pedidoId'] as num?)?.toInt() ?? 0,
    );
  }

  String get productosTexto =>
      productos.map((p) => p.etiquetaCorta).join(', ');
}

class RankingProductoDia {
  final String nombre;
  final int cantidad;

  const RankingProductoDia({required this.nombre, required this.cantidad});

  factory RankingProductoDia.fromJson(Map<String, dynamic> json) {
    return RankingProductoDia(
      nombre: json['nombre'] as String? ?? '',
      cantidad: (json['cantidad'] as num?)?.toInt() ?? 0,
    );
  }
}

class ResumenDiaVentas {
  final DateTime fecha;
  final int totalVentas;
  final double totalIngresosBs;
  final Map<String, double> ingresosPorTipoPago;
  final int conteoNuevos;
  final int conteoReferidos;
  final List<RankingProductoDia> rankingProductos;

  const ResumenDiaVentas({
    required this.fecha,
    required this.totalVentas,
    required this.totalIngresosBs,
    this.ingresosPorTipoPago = const {},
    required this.conteoNuevos,
    required this.conteoReferidos,
    this.rankingProductos = const [],
  });

  factory ResumenDiaVentas.fromJson(Map<String, dynamic> json) {
    final ingresosRaw = json['ingresosPorTipoPago'] as Map<String, dynamic>? ?? {};
    final rankingRaw = json['rankingProductos'] as List<dynamic>? ?? [];
    return ResumenDiaVentas(
      fecha: DateTime.parse(json['fecha'] as String),
      totalVentas: (json['totalVentas'] as num?)?.toInt() ?? 0,
      totalIngresosBs: (json['totalIngresosBs'] as num?)?.toDouble() ?? 0,
      ingresosPorTipoPago: ingresosRaw.map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      ),
      conteoNuevos: (json['conteoNuevos'] as num?)?.toInt() ?? 0,
      conteoReferidos: (json['conteoReferidos'] as num?)?.toInt() ?? 0,
      rankingProductos: rankingRaw
          .map((e) => RankingProductoDia.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class VentasDiariasReporte {
  final int clubId;
  final String nombreClub;
  final DateTime fecha;
  final ResumenDiaVentas resumen;
  final List<RegistroVentaDiaria> filas;

  const VentasDiariasReporte({
    required this.clubId,
    required this.nombreClub,
    required this.fecha,
    required this.resumen,
    this.filas = const [],
  });

  factory VentasDiariasReporte.fromJson(Map<String, dynamic> json) {
    final filasRaw = json['filas'] as List<dynamic>? ?? [];
    return VentasDiariasReporte(
      clubId: (json['clubId'] as num?)?.toInt() ?? 0,
      nombreClub: json['nombreClub'] as String? ?? '',
      fecha: DateTime.parse(json['fecha'] as String),
      resumen: ResumenDiaVentas.fromJson(json['resumen'] as Map<String, dynamic>),
      filas: filasRaw
          .map((e) => RegistroVentaDiaria.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
