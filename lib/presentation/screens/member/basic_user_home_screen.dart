import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../providers/user_provider.dart';

class BasicUserHomeScreen extends StatelessWidget {
  const BasicUserHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).currentUser;
    final userName = user?.name.split(' ').first ?? 'Usuario';

    return Scaffold( // Guardamos Scaffold por el AppBar y el body
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(''), 
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.grey),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
          CircleAvatar(
             backgroundColor: Colors.grey[300],
             child: Text(userName.substring(0, 1).toUpperCase()),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Text(
              'Hola, $userName',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
            const Text(
              'Empieza tu camino saludable',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            
            // Botón Buscar Clubes
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: () => context.go('/basic-map'), 
                icon: const Icon(Icons.search, color: Colors.white),
                label: const Text(
                  'Buscar Clubes Cercanos',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7AC142),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 4,
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Card QR
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'Muestra este QR al anfitrión para unirte',
                    style: TextStyle(fontSize: 14, color: Color(0xFF555555)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  // QR Generado con el ID del usuario
                  QrImageView(
                    data: user?.id ?? 'invitado',
                    version: QrVersions.auto,
                    size: 200.0,
                    foregroundColor: const Color(0xFF333333),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Sección Tips de Nutrición (Placeholder como en la imagen)
            const Row(
              children: [
                Icon(LucideIcons.apple, color: Color(0xFF7AC142), size: 20),
                SizedBox(width: 8),
                Text(
                  'Tips de Nutrición',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF7AC142)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                image: const DecorationImage(
                  image: NetworkImage('https://images.unsplash.com/photo-1490645935967-10de6ba17061?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80'), // Placeholder image
                  fit: BoxFit.cover,
                ),
              ),
            ),
             const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
