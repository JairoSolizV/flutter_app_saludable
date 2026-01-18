import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

class BasicUserMainScreen extends StatelessWidget {
  final Widget child;

  const BasicUserMainScreen({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // Determine current index based on route location
    final String location = GoRouterState.of(context).uri.toString();
    
    int currentIndex = 0;
    if (location.startsWith('/basic-map')) {
      currentIndex = 1;
    } else if (location.startsWith('/basic-profile')) {
      currentIndex = 2;
    } else {
      currentIndex = 0;
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        selectedItemColor: const Color(0xFF7AC142),
        unselectedItemColor: Colors.grey[400],
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          switch (index) {
            case 0:
              context.go('/basic-home');
              break;
            case 1:
              context.go('/basic-map');
              break;
            case 2:
              context.go('/basic-profile');
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.home),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.mapPin),
            label: 'Mapa',
          ),
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.user),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
