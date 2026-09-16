import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';

/// Card limpia con el código de sorteo persistente del backend.
///
/// Muestra únicamente el título `TU CÓDIGO` y el valor recibido (p. ej. `4827`).
class RaffleCodeCard extends StatelessWidget {
  final String codigo;

  const RaffleCodeCard({
    super.key,
    required this.codigo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'TU CÓDIGO',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            codigo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.bold,
              letterSpacing: 6,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
