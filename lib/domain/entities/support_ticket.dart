class SupportTicket {
  final int id;
  final int userId;
  final String tipoSolicitud;
  final String asunto;
  final String mensaje;
  final String estado; // ABIERTO, CERRADO
  final DateTime fechaCreacion;
  final String? respuestaAdmin;

  SupportTicket({
    required this.id,
    required this.userId,
    required this.tipoSolicitud,
    required this.asunto,
    required this.mensaje,
    required this.estado,
    required this.fechaCreacion,
    this.respuestaAdmin,
  });

  factory SupportTicket.fromMap(Map<String, dynamic> map) {
    return SupportTicket(
      id: map['id'] ?? 0,
      userId: map['usuarioId'] ?? map['usuario_id'] ?? 0,
      tipoSolicitud: map['tipoSolicitud'] ?? map['tipo_solicitud'] ?? 'Otro',
      asunto: map['asunto'] ?? '',
      mensaje: map['mensaje'] ?? '',
      estado: map['estado']?.toString().toUpperCase() ?? 'ABIERTO',
      fechaCreacion: map['fechaCreacion'] != null 
          ? DateTime.parse(map['fechaCreacion'].toString()) 
          : DateTime.now(),
      respuestaAdmin: map['respuestaAdmin'] ?? map['respuesta_admin'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'usuarioId': userId,
      'tipoSolicitud': tipoSolicitud,
      'asunto': asunto,
      'mensaje': mensaje,
      'estado': estado,
      'fechaCreacion': fechaCreacion.toIso8601String(),
      'respuestaAdmin': respuestaAdmin,
    };
  }
}
