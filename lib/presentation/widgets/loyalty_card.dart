import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class LoyaltyCard extends StatelessWidget {
  final int stamps; // Total de sellos actuales (ej. 8)
  final int maxStamps; // Total para recompensa (ej. 10)

  const LoyaltyCard({
    super.key,
    this.stamps = 8,
    this.maxStamps = 10,
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
                    'Tarjeta de Fidelidad',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  Text(
                    'Club Vida Activa',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Color(0xFF7AC142).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$stamps/$maxStamps Sellos',
                  style: TextStyle(
                    color: Color(0xFF7AC142),
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
              final isGift = index == maxStamps - 1;

              if (isGift) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.yellow[100],
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.yellow[400]!, width: 2),
                    boxShadow: [
                         BoxShadow(
                             color: Colors.yellow.withOpacity(0.5),
                             blurRadius: 10,
                             spreadRadius: 2
                         )
                    ]
                  ),
                  child: const Center(
                    child: Icon(LucideIcons.gift, color: Colors.orange, size: 20),
                  ),
                );
              }

              return Container(
                decoration: BoxDecoration(
                  color: isCompleted ? const Color(0xFF7AC142) : Colors.grey[100],
                  shape: BoxShape.circle,
                  boxShadow: isCompleted
                      ? [
                          BoxShadow(
                            color: const Color(0xFF7AC142).withOpacity(0.4),
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
          Text(
            '¡Solo ${maxStamps - stamps} consumos más para tu recompensa sorpresa!',
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
}
