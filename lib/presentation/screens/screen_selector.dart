import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

class ScreenSelector extends StatelessWidget {
  const ScreenSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dev: Selector de Pantallas')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SelectorTile(
            title: 'Invitado (Guest)',
            icon: LucideIcons.user,
            color: Colors.blue,
            onTap: () => context.go('/guest-home'),
          ),
          const SizedBox(height: 12),
           _SelectorTile(
            title: 'Miembro (Member)',
            icon: LucideIcons.users,
            color: Colors.green,
            onTap: () => context.go('/member-home'),
          ),
          const SizedBox(height: 12),
           _SelectorTile(
            title: 'Anfitrión (Host)',
            icon: LucideIcons.chefHat,
            color: Colors.orange,
            onTap: () => context.go('/host-dashboard'),
          ),
        ],
      ),
    );
  }
}

class _SelectorTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SelectorTile({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward),
        onTap: onTap,
      ),
    );
  }
}
