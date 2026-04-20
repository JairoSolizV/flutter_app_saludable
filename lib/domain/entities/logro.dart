class RequisitoLogro {
  final String tipoMetrica;
  final int cantidadEsperada;

  RequisitoLogro({
    required this.tipoMetrica,
    required this.cantidadEsperada,
  });

  factory RequisitoLogro.fromJson(Map<String, dynamic> json) {
    return RequisitoLogro(
      tipoMetrica: json['tipoMetrica']?.toString() ?? '',
      cantidadEsperada: json['cantidadEsperada'] is int
          ? json['cantidadEsperada'] as int
          : int.tryParse(json['cantidadEsperada']?.toString() ?? '') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tipoMetrica': tipoMetrica,
      'cantidadEsperada': cantidadEsperada,
    };
  }
}

class Logro {
  final int id;
  final String nombre;
  final String descripcion;
  final String? iconoUrl;
  final String? estadoAprobacion;
  final int? puntosRecompensa;
  final DateTime? fechaInicio;
  final DateTime? fechaFin;
  final List<RequisitoLogro> requisitos;

  Logro({
    required this.id,
    required this.nombre,
    required this.descripcion,
    this.iconoUrl,
    this.estadoAprobacion,
    this.puntosRecompensa,
    this.fechaInicio,
    this.fechaFin,
    this.requisitos = const [],
  });

  factory Logro.fromJson(Map<String, dynamic> json) {
    DateTime? parseFecha(dynamic value) {
      if (value == null) return null;
      if (value is String) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    var requisitosList = json['requisitos'] as List? ?? [];
    List<RequisitoLogro> parsedRequisitos = requisitosList.map((e) => RequisitoLogro.fromJson(e)).toList();

    return Logro(
      id: json['id'] as int,
      nombre: json['nombre'] as String? ?? '',
      descripcion: json['descripcion'] as String? ?? '',
      iconoUrl: json['iconoUrl'] as String?,
      estadoAprobacion: json['estadoAprobacion']?.toString(),
      puntosRecompensa: json['puntosRecompensa'] is int
          ? json['puntosRecompensa'] as int
          : int.tryParse(json['puntosRecompensa']?.toString() ?? ''),
      fechaInicio: parseFecha(json['fechaInicio']),
      fechaFin: parseFecha(json['fechaFin']),
      requisitos: parsedRequisitos,
    );
  }
}

class RequisitoProgreso {
  final String tipoMetrica;
  final int cantidadEsperada;
  final int cantidadActual;

  RequisitoProgreso({
    required this.tipoMetrica,
    required this.cantidadEsperada,
    required this.cantidadActual,
  });

  factory RequisitoProgreso.fromJson(Map<String, dynamic> json) {
    return RequisitoProgreso(
      tipoMetrica: json['tipoMetrica']?.toString() ?? '',
      cantidadEsperada: json['cantidadEsperada'] is int
          ? json['cantidadEsperada'] as int
          : int.tryParse(json['cantidadEsperada']?.toString() ?? '') ?? 0,
      cantidadActual: json['cantidadActual'] is int
          ? json['cantidadActual'] as int
          : int.tryParse(json['cantidadActual']?.toString() ?? '') ?? 0,
    );
  }
}

class LogroProgreso {
  final int logroId;
  final String nombre;
  final bool completado;
  final int puntosRecompensa;
  final List<RequisitoProgreso> requisitos;

  LogroProgreso({
    required this.logroId,
    required this.nombre,
    required this.completado,
    required this.puntosRecompensa,
    this.requisitos = const [],
  });

  factory LogroProgreso.fromJson(Map<String, dynamic> json) {
    var requisitosList = json['requisitos'] as List? ?? [];
    List<RequisitoProgreso> parsedRequisitos = requisitosList.map((e) => RequisitoProgreso.fromJson(e)).toList();

    return LogroProgreso(
      logroId: json['logroId'] as int,
      nombre: json['nombre'] as String? ?? '',
      completado: json['completado'] == true || json['completado'] == 'true',
      puntosRecompensa: json['puntosRecompensa'] is int
          ? json['puntosRecompensa'] as int
          : int.tryParse(json['puntosRecompensa']?.toString() ?? '') ?? 0,
      requisitos: parsedRequisitos,
    );
  }
}
