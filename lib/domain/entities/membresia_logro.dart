import 'logro.dart';

class MembresiaLogro {
  final int id;
  final int membresiaId;
  final Logro logro;

  MembresiaLogro({
    required this.id,
    required this.membresiaId,
    required this.logro,
  });

  factory MembresiaLogro.fromJson(Map<String, dynamic> json) {
    return MembresiaLogro(
      id: json['id'] as int,
      membresiaId: json['membresiaId'] as int? ?? (json['membresia'] is Map ? (json['membresia'] as Map)['id'] as int? : null) ?? 0,
      logro: Logro.fromJson(json['logro'] as Map<String, dynamic>),
    );
  }
}

