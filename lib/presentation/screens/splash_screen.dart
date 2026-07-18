import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';
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
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.eco, size: 80, color: Colors.white),
            ),
            const SizedBox(height: 24),
            const Text(
              'Nutrilife Club',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Club de Nutrición',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
