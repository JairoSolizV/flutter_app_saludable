import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';

class BasicUserProfileScreen extends StatefulWidget {
  const BasicUserProfileScreen({super.key});

  @override
  State<BasicUserProfileScreen> createState() => _BasicUserProfileScreenState();
}

class _BasicUserProfileScreenState extends State<BasicUserProfileScreen> {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Provider.of<AuthProvider>(context, listen: false).syncProfile();
      if (mounted) {
         final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
         if (user != null) {
            Provider.of<UserProvider>(context, listen: false).setUser(user);
         }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Escuchamos AuthProvider también por si actualiza el usuario globalmente, 
    // pero UserProvider es quien suele dar el usuario.
    // Ojo: UserProvider carga de local. AuthProvider guarda en local.
    // Debemos asegurar que UserProvider se actualice.
    // AuthProvider actualiza _currentUser, pero UserProvider tiene su propio _currentUser.
    // Solución rápida: Usar AuthProvider.currentUser si está disponible, o recargar UserProvider.
    
    // Mejor flujo: AuthProvider update -> LocalDB. UserProvider load -> LocalDB.
    // Trigger UserProvider reload after AuthProvider sync.
    
    final userProvider = Provider.of<UserProvider>(context);
    // Si AuthProvider actualizó, deberíamos pedirle a UserProvider que recargue
    // Vamos a forzar la recarga en el callback de initState mejor.
    
    final user = userProvider.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text("Cargando...")));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
             icon: const Icon(Icons.more_horiz, color: Colors.grey),
             onPressed: () {},
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            // Header con Avatar y Datos
            Row(
              children: [
                CircleAvatar(
                  radius: 35,
                  backgroundColor: const Color(0xFF7AC142),
                  child: Text(
                    user.name.substring(0, 2).toUpperCase(),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.normal, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.phone ?? 'Sin teléfono',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 30),

            // Opciones de lista
            _OptionTile(
              icon: LucideIcons.edit2,
              title: "Editar mis datos",
              onTap: () {
                context.go('/basic-profile/edit');
              },
            ),


            const SizedBox(height: 30),

            // Card: ¿Quieres ser Anfitrión?
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF7AC142),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7AC142).withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                   const Text(
                    "¿Quieres ser Anfitrión?",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                   ),
                   const SizedBox(height: 8),
                   const Text(
                    "Registra tu propio Club y forma parte de nuestra comunidad",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                   ),
                   const SizedBox(height: 20),
                   SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton(
                      onPressed: () {
                        // Navegar a solicitud de anfitrión (Future task)
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Funcionalidad 'Solicitar Registro' en desarrollo")),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        foregroundColor: const Color(0xFF7AC142),
                      ),
                      child: const Text("Solicitar Registro", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                   )
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Botón Cerrar Sesión (estético para desarrollo)
            TextButton.icon(
              onPressed: () {
                 Provider.of<AuthProvider>(context, listen: false).logout();
                 context.go('/login');
              },
              icon: const Icon(LucideIcons.logOut, color: Colors.grey),
              label: const Text("Cerrar Sesión", style: TextStyle(color: Colors.grey)),
            )
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
        leading: Icon(icon, color: Colors.grey[400]),
        title: Text(title, style: const TextStyle(color: Color(0xFF333333), fontWeight: FontWeight.w500)),
        trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
