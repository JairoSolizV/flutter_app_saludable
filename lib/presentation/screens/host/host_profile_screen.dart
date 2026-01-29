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

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Configuración', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
           children: [
             const SizedBox(height: 10),
             // Header Estilo Basic User
             Container(
               padding: const EdgeInsets.all(24),
               decoration: BoxDecoration(
                 color: const Color(0xFF7AC142), // Verde marca
                 borderRadius: BorderRadius.circular(20),
                 boxShadow: [
                    BoxShadow(color: const Color(0xFF7AC142).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))
                 ],
               ),
               child: Row(
                 children: [
                    CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.white,
                      child: Text(
                        user.name.isNotEmpty ? user.name.substring(0, 2).toUpperCase() : 'AN',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF7AC142)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           Text(
                             user.name,
                             style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                           ),
                           const SizedBox(height: 4),
                           Text(
                             user.email,
                             style: const TextStyle(fontSize: 14, color: Colors.white70),
                           ),
                           const SizedBox(height: 4),
                           Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('Anfitrión', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                           )
                        ],
                      ),
                    )
                 ],
               ),
             ),

             const SizedBox(height: 30),

             // Opciones
             _OptionTile(
               icon: LucideIcons.user,
               title: 'Editar Perfil',
               onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Próximamente'))),
             ),
             _OptionTile(
               icon: LucideIcons.store,
               title: 'Datos del Club',
               onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Próximamente'))),
             ),
             
             const SizedBox(height: 40),

             // Botón Cerrar Sesión
             TextButton.icon(
                onPressed: () async {
                   await Provider.of<AuthProvider>(context, listen: false).logout();
                   Provider.of<UserProvider>(context, listen: false).logout();
                   if (context.mounted) {
                     context.go('/guest-home');
                   }
                },
                icon: const Icon(LucideIcons.logOut, color: Colors.redAccent),
                label: const Text("Cerrar Sesión", style: TextStyle(color: Colors.redAccent, fontSize: 16)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                  backgroundColor: Colors.red[50],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
             ),
           ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _OptionTile({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
         color: Colors.white,
         border: Border.all(color: Colors.grey[200]!),
         borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF7AC142)), // Icono verde
        title: Text(title, style: const TextStyle(color: Color(0xFF333333), fontWeight: FontWeight.w500)),
        trailing: Icon(Icons.chevron_right, color: Colors.grey[300]),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
