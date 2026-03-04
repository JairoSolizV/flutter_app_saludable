import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

class GuestMainScreen extends StatelessWidget {
  final Widget child;

  const GuestMainScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Determinar índice actual basado en la ruta
    final String location = GoRouterState.of(context).matchedLocation;
    int currentIndex = _getIndexFromLocation(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go('/guest-home');
              break;
            case 1:
              context.go('/login');
              break;
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(LucideIcons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.logIn),
            label: 'Ingresar',
          ),
        ],
      ),
    );
  }

  int _getIndexFromLocation(String location) {
    if (location.startsWith('/login')) return 1;
    return 0; // Default home
  }
}
