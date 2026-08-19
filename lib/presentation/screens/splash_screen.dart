import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app_saludable/presentation/providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _decidirRutaInicial();
  }

  Future<void> _decidirRutaInicial() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    final user = await auth.bootstrapSession();
    if (!mounted) return;

    // Sesión válida solo con perfil + token coherentes (AuthProvider).
    if (user == null || user.role == 'guest') {
      context.go('/guest-home');
      return;
    }

    switch (user.role) {
      case 'host':
        context.go('/host-dashboard');
        break;
      case 'basic_user':
        context.go('/basic-home');
        break;
      default:
        context.go('/member-home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // El logo es apaisado (709x444) y trae el fondo blanco horneado en el
            // JPEG: se fija solo el ancho para respetar su proporción, y encaja
            // con el fondo blanco del Scaffold.
            Image.asset(
              'assets/images/expande_logo.jpg',
              width: 240,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 16),
            const Text(
              'Expande',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF14284B),
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                'Asistencia por QR, pedidos y puntos de socio',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
