import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/auth_provider.dart';

class MemberProfileScreen extends StatelessWidget {
  const MemberProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.currentUser;

    if (userProvider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (user == null) {
      return const Scaffold(body: Center(child: Text("Error: Usuario no encontrado")));
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200.0,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF7AC142),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF7AC142), Color(0xFF6BB032)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                       const SizedBox(height: 48),
                       CircleAvatar(
                         radius: 40,
                         backgroundColor: Colors.white,
                         child: Text(
                           user.name.substring(0, 1).toUpperCase(),
                           style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF7AC142)),
                         ),
                       ),
                       const SizedBox(height: 8),
                       Text(user.name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                       Text(user.email, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
                IconButton(
                    icon: const Icon(LucideIcons.edit3, color: Colors.white),
                    onPressed: () {
                        // Navegar a edición
                         _showEditDialog(context, userProvider);
                    },
                )
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                   _ProfileCard(
                       icon: LucideIcons.phone,
                       title: 'Teléfono',
                       value: user.phone ?? 'No registrado'
                   ),
                   const SizedBox(height: 16),
                   _ProfileCard(
                       icon: LucideIcons.trophy,
                       title: 'Membresía',
                       value: 'Nivel Oro',
                       trailing: const Icon(Icons.star, color: Colors.orange),
                   ),
                   const SizedBox(height: 16),
                   _ProfileCard(
                       icon: LucideIcons.mapPin,
                       title: 'Club Principal',
                       value: 'Club Vida Activa',
                   ),
                   const SizedBox(height: 24),
                   SizedBox(
                       width: double.infinity,
                       child: ElevatedButton.icon(
                           onPressed: () async {
                              // Obtener Providers
                              final auth = Provider.of<AuthProvider>(context, listen: false); // Asumiendo que AuthProvider está disponible en el árbol
                              final userProv = Provider.of<UserProvider>(context, listen: false);
                              
                              await auth.logout();
                              userProv.logout(); // Necesitamos asegurar que UserProvider tenga un método para limpiar
                              
                              if (context.mounted) {
                                context.go('/guest-home');
                              }
                           },
                           icon: const Icon(LucideIcons.logOut),
                           label: const Text('Cerrar Sesión'),
                           style: ElevatedButton.styleFrom(
                               backgroundColor: Colors.red[50],
                               foregroundColor: Colors.red,
                               padding: const EdgeInsets.all(16)
                           ),
                       )
                   )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, UserProvider provider) {
      final nameCtrl = TextEditingController(text: provider.currentUser?.name);
      final phoneCtrl = TextEditingController(text: provider.currentUser?.phone);

      showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
              title: const Text('Editar Perfil'),
              content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                      TextField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(labelText: 'Nombre'),
                      ),
                      TextField(
                          controller: phoneCtrl,
                          decoration: const InputDecoration(labelText: 'Teléfono'),
                      ),
                  ],
              ),
              actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                  ElevatedButton(
                      onPressed: () async {
                          await provider.updateUserProfile(
                              name: nameCtrl.text,
                              phone: phoneCtrl.text
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                      }, 
                      child: const Text('Guardar'),
                  )
              ],
          )
      );
  }
}

class _ProfileCard extends StatelessWidget {
    final IconData icon;
    final String title;
    final String value;
    final Widget? trailing;

    const _ProfileCard({required this.icon, required this.title, required this.value, this.trailing});

    @override
    Widget build(BuildContext context) {
        return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
            ),
            child: Row(
                children: [
                    Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFF0F9E8), borderRadius: BorderRadius.circular(12)),
                        child: Icon(icon, color: const Color(0xFF7AC142)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                        ),
                    ),
                    if (trailing != null) trailing!,
                ],
            ),
        );
    }
}
