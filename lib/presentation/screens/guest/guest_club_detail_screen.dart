import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../data/datasources/remote/club_remote_data_source.dart';

import 'package:url_launcher/url_launcher.dart'; // Para abrir links
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../../main.dart'; // Acceso a clubRemoteDataSource

class GuestClubDetailScreen extends StatefulWidget {
  final Club club;

  const GuestClubDetailScreen({super.key, required this.club});

  @override
  State<GuestClubDetailScreen> createState() => _GuestClubDetailScreenState();
}

class _GuestClubDetailScreenState extends State<GuestClubDetailScreen> {
  Anfitrion? _anfitrion;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    try {
      final anfitrion = await clubRemoteDataSource.getAnfitrion(widget.club.anfitrionId);
      if (mounted) setState(() { _anfitrion = anfitrion; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openMap(double lat, double lng) async {
    final googleUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(googleUrl)) {
      await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
    } else {
      // Fallback a web si no hay app
      await launchUrl(googleUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.club.nombreClub),
        backgroundColor: const Color(0xFF7AC142),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Banner del Club (Placeholder o imagen del club si tuvieras)
            Container(
              height: 200,
              width: double.infinity,
              color: Colors.grey[200],
              child: const Icon(Icons.storefront, size: 80, color: Colors.grey),
            ),
            
            // Info Principal
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                     children: [
                       const CircleAvatar(
                         radius: 30,
                         backgroundColor: Color(0xFF7AC142),
                         child: Icon(Icons.person, color: Colors.white, size: 30),
                       ),
                       const SizedBox(width: 16),
                       Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           const Text('Anfitrión', style: TextStyle(color: Colors.grey, fontSize: 12)),
                           Text(widget.club.anfitrionNombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                         ],
                       )
                     ],
                   ),
                   const Divider(height: 32),
                   
                   _InfoRow(icon: LucideIcons.mapPin, title: 'Dirección', value: widget.club.direccion),
                   const SizedBox(height: 16),
                   _InfoRow(icon: LucideIcons.clock, title: 'Horario', value: widget.club.horario),
                   const SizedBox(height: 16),
                   
                   // Info Extra del Anfitrión (Cargada asíncronamente)
                   if (_loading) 
                      const Center(child: LinearProgressIndicator(color: Color(0xFF7AC142)))
                   else if (_anfitrion != null) ...[
                      if (_anfitrion!.telefono.isNotEmpty) ...[
                        _InfoRow(
                          icon: LucideIcons.phone, 
                          title: 'Teléfono', 
                          value: _anfitrion!.telefono,
                          isLink: true,
                          onTap: () => launchUrl(Uri.parse('tel:${_anfitrion!.telefono}')),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_anfitrion!.redesSociales.isNotEmpty) ...[
                        const _InfoRow(icon: LucideIcons.instagram, title: 'Redes Sociales', value: 'Ver Perfil'),
                        // Aquí podrías parsear el link real si viene en el JSON
                        const SizedBox(height: 16),
                      ]
                   ],

                   const _InfoRow(icon: LucideIcons.star, title: 'Estado', value: 'Club Verificado'),

                ],
              ),
            ),


            const Divider(thickness: 8, color: Color(0xFFF5F5F5)),

            // Acciones para Invitado
            // Acciones para Invitado
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '¿Cómo llegar?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Obtén indicaciones para visitar este club y conocer al anfitrión.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () => _openMap(widget.club.lat, widget.club.lng),
                      icon: const Icon(LucideIcons.map),
                      label: const Text('ABRIR EN GOOGLE MAPS', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4285F4), // Google Blue
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Boton secundario login (solo si no está logueado)
                  Consumer<UserProvider>(
                    builder: (context, userProvider, child) {
                      if (userProvider.currentUser != null) return const SizedBox.shrink();
                      return Center(
                        child: TextButton(
                          onPressed: () => context.go('/login'),
                          child: const Text('Ya soy socio, Iniciar Sesión'),
                        ),
                      );
                    },
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final bool isLink;
  final VoidCallback? onTap;

  const _InfoRow({
    required this.icon, 
    required this.title, 
    required this.value,
    this.isLink = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: isLink ? Colors.blue : Colors.grey, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  value, 
                  style: TextStyle(
                    color: isLink ? Colors.blue : Colors.black87, 
                    fontSize: 16,
                    decoration: isLink ? TextDecoration.underline : null,
                  )
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
