import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app_saludable/domain/entities/user.dart';
import 'package:flutter_app_saludable/presentation/providers/auth_provider.dart';
import 'package:flutter_app_saludable/presentation/providers/user_provider.dart';

/// Hidrata [UserProvider] desde SQLite tras un bootstrap auth exitoso.
///
/// Usa [UserProvider.loadUser] para no copiar JWT a memoria del provider de UI.
/// Si SQLite no responde, cae al perfil de bootstrap sin token.
@visibleForTesting
Future<void> hydrateUserProviderAfterBootstrap(
  UserProvider userProvider,
  User authenticatedUser,
) async {
  await userProvider.loadUser(authenticatedUser.id);
  if (userProvider.currentUser == null) {
    userProvider.setUser(authenticatedUser.withoutToken());
  }
}

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
    if (user != null && user.role != 'guest') {
      final userProvider = context.read<UserProvider>();
      await hydrateUserProviderAfterBootstrap(userProvider, user);
      if (!mounted) return;

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
      return;
    }

    final route = await auth.resolveColdStartRoute();
    if (!mounted) return;

    if (route == '/verify-email') {
      final pendingEmail = await auth.getPendingVerificationEmail();
      if (!mounted) return;
      context.go('/verify-email', extra: {'email': pendingEmail ?? ''});
      return;
    }

    context.go('/login');
  }

  static const Color _brandBlue = Color(0xFF00346D);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final logoWidth = (screenWidth * 0.38).clamp(96.0, 160.0);
    final barWidth = (screenWidth * 0.42).clamp(120.0, 180.0);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo apaisado con fondo blanco horneado; solo se fija el ancho
                // para respetar proporción y evitar overflow en pantallas chicas.
                Image.asset(
                  'assets/images/expande_logo.jpg',
                  width: logoWidth,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: barWidth,
                  child: const ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      backgroundColor: Color(0x2200346D),
                      color: _brandBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
