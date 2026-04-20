import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../domain/entities/logro.dart';
import 'package:intl/intl.dart';

class CompositeLoyaltyCard extends StatelessWidget {
  final LogroProgreso progreso;
  final String clubName;

  const CompositeLoyaltyCard({
    super.key,
    required this.progreso,
    this.clubName = 'Sin Club Asignado',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      progreso.nombre,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    Text(
                      clubName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              if (progreso.completado)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.checkCircle, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text("COMPLETADO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('EN PROGRESO', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 10)),
                ),
            ],
          ),
          const SizedBox(height: 24),
          
          const Text("Requisitos del Reto", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
          const SizedBox(height: 12),
          
          ...progreso.requisitos.map((req) => _buildRequirementRow(req)).toList(),
          
          const SizedBox(height: 20),
          if (progreso.puntosRecompensa > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                   const Icon(LucideIcons.medal, size: 14, color: Colors.orange),
                   const SizedBox(width: 4),
                   Text(
                     'Recompensa: ${progreso.puntosRecompensa} pts',
                     style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
                   ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRequirementRow(RequisitoProgreso req) {
    IconData icon;
    String label;
    switch (req.tipoMetrica.toUpperCase()) {
      case 'CONSUMO':
        icon = LucideIcons.coffee;
        label = 'Consumos';
        break;
      case 'REFERIDOS':
        icon = LucideIcons.users;
        label = 'Referidos';
        break;
      case 'ASISTENCIA':
      default:
        icon = LucideIcons.checkSquare;
        label = 'Asistencias';
        break;
    }

    final double progress = req.cantidadEsperada > 0 
        ? (req.cantidadActual / req.cantidadEsperada).clamp(0.0, 1.0)
        : 0.0;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey[700]),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(color: Colors.grey[800], fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              Text(
                '${req.cantidadActual}/${req.cantidadEsperada}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF7AC142)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7AC142)),
            ),
          ),
        ],
      ),
    );
  }
}
