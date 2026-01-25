import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

class MemberMainScreen extends StatelessWidget {
  final Widget child;

  const MemberMainScreen({super.key, required this.child});

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
            icon: Icon(LucideIcons.calendarCheck),
            label: 'Asistencia', // Attendance Placeholder
          ),
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.shoppingBag),
            label: 'Pedidos',
          ),
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.award),
            label: 'Logros', // Achievements Placeholder
          ),
          BottomNavigationBarItem(
             icon: Icon(LucideIcons.user),
             label: 'Perfil', // Profile Placeholder
          ),
        ],
      ),
    );
  }

  static int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/member-home')) return 0;
    if (location.startsWith('/member-attendance')) return 1;
    if (location.startsWith('/member-orders')) return 2;
    if (location.startsWith('/member-achievements')) return 3;
    if (location.startsWith('/member-profile')) return 4;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/member-home');
        break;
      case 1:
        context.go('/member-attendance'); 
        break;
      case 2:
        context.go('/member-orders');
        break;
      case 3:
        context.go('/member-achievements');
        break;
      case 4:
         context.go('/member-profile');
         break;
    }
  }
}
