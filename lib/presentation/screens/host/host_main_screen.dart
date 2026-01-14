import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

class HostMainScreen extends StatelessWidget {
  final Widget child;

  const HostMainScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _calculateSelectedIndex(context),
        onTap: (int index) => _onItemTapped(index, context),
        selectedItemColor: const Color(0xFF7AC142),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.home),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.shoppingBag),
            label: 'Pedidos',
          ),
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.scan),
            label: 'Escanear', 
          ),
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.users),
            label: 'Socios', 
          ),
          BottomNavigationBarItem(
             icon: Icon(LucideIcons.settings),
             label: 'Config', 
          ),
        ],
      ),
    );
  }

  static int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/host-dashboard')) return 0;
    if (location.startsWith('/host-orders')) return 1;
    // ... otros índices
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/host-dashboard');
        break;
      case 1:
        context.go('/host-orders');
        break;
      // ... otros casos
    }
  }
}
