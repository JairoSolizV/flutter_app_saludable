import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../providers/user_provider.dart';
import '../../widgets/socio_steps_stepper.dart';

class BasicUserHomeScreen extends StatelessWidget {
  const BasicUserHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).currentUser;
    final userName = user?.name.split(' ').first ?? 'Usuario';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(''),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: InkWell(
              key: const Key('basic-home-profile-avatar'),
              onTap: () => context.go('/basic-profile'),
              customBorder: const CircleBorder(),
              child: Tooltip(
                message: 'Ver mi perfil',
                child: CircleAvatar(
                  backgroundColor: Colors.grey[300],
                  child: Text(userName.substring(0, 1).toUpperCase()),
                ),
              ),
            ),
          ),
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
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),

            // Card QR de activación
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
                  // Formato ACTIVATE:{userId}: lo consume HostScanScreen
                  // para activar al usuario como socio del club.
                  QrImageView(
                    data: user != null
                        ? 'ACTIVATE:${user.id}'
                        : 'ACTIVATE:invitado',
                    version: QrVersions.auto,
                    size: 200.0,
                    foregroundColor: const Color(0xFF333333),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            const Text(
              'Cómo convertirte en socio',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Seguí estos 3 pasos',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const SocioStepsStepper(),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
