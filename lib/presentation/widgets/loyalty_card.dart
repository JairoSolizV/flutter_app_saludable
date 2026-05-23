import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';

class LoyaltyCard extends StatelessWidget {
  final int stamps;
  final int maxStamps;
  final String clubName;
  final String? fechaFin;
  final String tipoMetrica; // 'ASISTENCIA', 'CONSUMO', 'REFERIDOS'
  final int puntosRecompensa;

  const LoyaltyCard({
    super.key,
    this.stamps = 0,
    this.maxStamps = 10,
    this.clubName = 'Sin Club Asignado',
    this.fechaFin,
    this.tipoMetrica = 'ASISTENCIA',
    this.puntosRecompensa = 0,
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titleForMetrica(),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$stamps/$maxStamps Sellos',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Grid de Sellos
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: maxStamps,
            itemBuilder: (context, index) {
              final isCompleted = index < stamps;
              return Container(
                decoration: BoxDecoration(
                  color: isCompleted ? AppTheme.primaryColor : Colors.grey[100],
                  shape: BoxShape.circle,
                  boxShadow: isCompleted
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(LucideIcons.star, color: Colors.white, size: 18)
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 20),
          if (puntosRecompensa > 0)
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
                     'Recompensa: $puntosRecompensa pts',
                     style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
                   ),
                ],
              ),
            ),
          if (fechaFin != null)
            Text(
              'Válido hasta: $fechaFin',
              style: const TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.w600),
            ),
          const SizedBox(height: 4),
          Text(
            '¡Solo ${maxStamps - stamps} ${unidadForMetrica()} más para tu meta!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String titleForMetrica() {
    switch (tipoMetrica) {
      case 'CONSUMO': return 'Logro de Consumo';
      case 'REFERIDOS': return 'Reto de Referidos';
      case 'ASISTENCIA':
      default: return 'Tarjeta de Fidelidad';
    }
  }

  String unidadForMetrica() {
    switch (tipoMetrica) {
      case 'CONSUMO': return 'compras';
      case 'REFERIDOS': return 'invitados';
      case 'ASISTENCIA':
      default: return 'consumos';
    }
  }
}
