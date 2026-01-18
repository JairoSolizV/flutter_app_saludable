import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';

class HostProfileScreen extends StatelessWidget {
  const HostProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
      ),
      body: ListView(
        children: [
          if (user != null)
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF7AC142)),
              accountName: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              accountEmail: Text(user.email),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                  style: const TextStyle(fontSize: 32, color: Color(0xFF7AC142)),
                ),
              ),
            ),
          
          ListTile(
            leading: const Icon(LucideIcons.user),
            title: const Text('Editar Perfil'),
            onTap: () {
              // TODO: Implementar edición de perfil anfitrión
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Próximamente')));
            },
          ),
          ListTile(
            leading: const Icon(LucideIcons.store),
            title: const Text('Datos del Club'),
            onTap: () {
              // TODO: Implementar edición de club
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Próximamente')));
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(LucideIcons.logOut, color: Colors.red),
            title: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red)),
            onTap: () async {
              await Provider.of<AuthProvider>(context, listen: false).logout();
              Provider.of<UserProvider>(context, listen: false).logout();
              if (context.mounted) {
                context.go('/guest-home');
              }
            },
          ),
        ],
      ),
    );
  }
}
