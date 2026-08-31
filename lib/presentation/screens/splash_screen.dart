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
  /// Desplaza el bloque logo+barra ligeramente hacia arriba del centro óptico.
  static const double _blockLift = 18;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;
    // ~70–95 px en iPhone normal; responsive en pantallas más chicas/grandes.
    final logoWidth = (screenWidth * 0.22).clamp(70.0, 95.0);
    final barWidth = (screenWidth * 0.42).clamp(120.0, 180.0);
    final decodeWidth = (logoWidth * media.devicePixelRatio).round();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Transform.translate(
            offset: const Offset(0, -_blockLift),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo Expande (asset histórico del splash); ancho responsive.
                  Image.asset(
                    'assets/images/expande_logo.jpg',
                    width: logoWidth,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    cacheWidth: decodeWidth,
                  ),
                  const SizedBox(height: 18),
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
      ),
    );
  }
}
