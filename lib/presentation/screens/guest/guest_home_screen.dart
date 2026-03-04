import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

class GuestHomeScreen extends StatelessWidget {
  const GuestHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // Color fondo suave
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Text('Hola, Invitado', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
             Row(
               children: [
                 Icon(LucideIcons.mapPin, size: 14, color: Colors.grey),
                 SizedBox(width: 4),
                 Text('Santa Cruz', style: TextStyle(fontSize: 12, color: Colors.grey)),
               ],
             )
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero Banner
            Container(
              height: 200,
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                image: const DecorationImage(
                  image: NetworkImage('https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?ixlib=rb-4.0.3&auto=format&fit=crop&w=1000&q=80'), // Placeholder gym/healthy
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                  ),
                ),
                padding: const EdgeInsets.all(20),
                alignment: Alignment.bottomLeft,
                child: const Text(
                  'Descubre tu\nmejor versión',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            // Grid de Botones Principales
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _BigCard(
                      title: 'Crear Cuenta',
                      icon: LucideIcons.userPlus,
                      color: const Color(0xFFE8F5E9), // Light green
                      iconColor: const Color(0xFF7AC142), // Primary green
                      onTap: () => context.go('/register'), 
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),

             const SizedBox(height: 24),

             const SizedBox(height: 24),
             
             // Artículo Hardcodeado
             Padding(
               padding: const EdgeInsets.symmetric(horizontal: 16),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   const Text('Consejos Diarios', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 12),
                   Container(
                     decoration: BoxDecoration(
                       color: Colors.white,
                       borderRadius: BorderRadius.circular(16),
                       boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
                     ),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            child: Image.network(
                              'https://images.unsplash.com/photo-1490645935967-10de6ba17061?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
                              height: 150,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('5 Beneficios del Té Verde', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Text(
                                  'Descubre cómo el té verde puede ayudarte a mejorar tu metabolismo y aumentar tu energía diaria de forma natural...',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                       ],
                     ),
                   ),

                   const SizedBox(height: 24),

                   const Text('Próximos Eventos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 12),
                   Container(
                     decoration: BoxDecoration(
                       color: Colors.white,
                       borderRadius: BorderRadius.circular(16),
                       boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
                     ),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            child: Image.network(
                              'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80', // Yoga / Exercise image
                              height: 150,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Expanded(child: Text('Día de Entrenamiento Fit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text('Mañana, 18:00', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Únete a nosotros para una sesión intensa de entrenamiento al aire libre. Todos los niveles son bienvenidos.',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                       ],
                     ),
                   )
                 ],
               ),
             ),
             const SizedBox(height: 80), // Espacio final
          ],
        ),
      ),
    );
  }
}

class _BigCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  const _BigCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
      return InkWell(
        onTap: onTap,
        child: Container(
          height: 160,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
               BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                   color: color,
                   shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 32),
              ),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
        ),
      );
  }
}

class _HomeMenuCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _HomeMenuCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Theme.of(context).primaryColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
