import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../../data/datasources/remote/club_remote_data_source.dart';
import 'club/host_club_edit_screen.dart';

import 'package:intl/intl.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';
import 'package:flutter_app_saludable/core/utils/input_formatters.dart';
import 'package:flutter_app_saludable/core/utils/validators.dart';

class HostProfileScreen extends StatefulWidget {
  const HostProfileScreen({super.key});

  @override
  State<HostProfileScreen> createState() => _HostProfileScreenState();
}

class _HostProfileScreenState extends State<HostProfileScreen> {

  @override
  void initState() {
    super.initState();
    // Forzar actualización de datos al entrar a configuración
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncUserData();
    });
  }

  Future<void> _syncUserData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    // Si ya estamos cargando, no hacer nada (o mostrar indicador si se desea)
    // Pero aquí es background update
    try {
       await authProvider.syncProfile();
       if (authProvider.currentUser != null) {
          userProvider.setUser(authProvider.currentUser!);
       }
    } catch (e) {
      debugPrint('Error syncing host profile: $e');
    }
  }

  void _showEditDialog(BuildContext context, UserProvider userProvider) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser ?? userProvider.currentUser;
      
      final nameCtrl = TextEditingController(text: user?.name);
      final phoneCtrl = TextEditingController(
        text: Validators.stripBoliviaCountryCode(user?.phone ?? ''),
      );
      final birthDateCtrl = TextEditingController(text: user?.birthDate ?? '');
      
      // Extract instagram safely
      String? currentInstagram;
      if (user?.socialMedia != null && user!.socialMedia!.containsKey('instagram')) {
         currentInstagram = user.socialMedia!['instagram'];
      }
      final instagramCtrl = TextEditingController(text: currentInstagram);

      DateTime? selectedDate;

      if (user?.birthDate != null && user!.birthDate!.isNotEmpty) {
        try {
          selectedDate = DateTime.parse(user.birthDate!);
        } catch (e) {
          // Ignorar error
        }
      }

      showDialog(
          context: context,
          builder: (ctx) => StatefulBuilder(
            builder: (context, setState) => AlertDialog(
                title: const Text('Editar Perfil'),
                content: SingleChildScrollView(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                          TextField(
                              controller: nameCtrl,
                              maxLength: 255,
                              inputFormatters: AppFormatters.letras(255),
                              decoration: const InputDecoration(labelText: 'Nombre', counterText: ''),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                              controller: phoneCtrl,
                              maxLength: 8,
                              inputFormatters: AppFormatters.telefono,
                              decoration: const InputDecoration(labelText: 'Teléfono', counterText: ''),
                              keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                              controller: instagramCtrl,
                              maxLength: 255,
                              inputFormatters: AppFormatters.sinEspacios(255),
                              decoration: const InputDecoration(labelText: 'Instagram (@usuario)', counterText: ''),
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate ?? DateTime.now().subtract(const Duration(days: 365 * 25)),
                                firstDate: DateTime(1900),
                                lastDate: DateTime.now(),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: const ColorScheme.light(
                                        primary: AppTheme.primaryColor,
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null) {
                                setState(() {
                                  selectedDate = picked;
                                  birthDateCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
                                });
                              }
                            },
                            child: AbsorbPointer(
                              child: TextField(
                                  controller: birthDateCtrl,
                                  readOnly: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Fecha de Nacimiento',
                                    suffixIcon: Icon(LucideIcons.calendar),
                                    hintText: 'Selecciona una fecha',
                                  ),
                              ),
                            ),
                          ),
                      ],
                  ),
                ),
                actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                    ElevatedButton(
                        onPressed: () async {
                            try {
                              showDialog(
                                context: ctx,
                                barrierDismissible: false,
                                builder: (context) => const Center(child: CircularProgressIndicator()),
                              );
                              
                              Map<String, dynamic>? updatedSocialMedia;
                              if (instagramCtrl.text.trim().isNotEmpty) {
                                updatedSocialMedia = {'instagram': instagramCtrl.text.trim()};
                              }

                              await authProvider.updateProfile(
                                  name: nameCtrl.text.trim(),
                                  phone: Validators.toBoliviaE164(phoneCtrl.text),
                                  birthDate: birthDateCtrl.text.trim().isEmpty ? null : birthDateCtrl.text.trim(),
                                  socialMedia: updatedSocialMedia,
                              );
                              
                              if (authProvider.currentUser != null) {
                                userProvider.setUser(authProvider.currentUser!);
                              }
                              
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text('Perfil actualizado correctamente'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text('Error al actualizar: ${e.toString().replaceAll('Exception: ', '')}'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                        }, 
                        child: const Text('Guardar'),
                    )
                ],
            ),
          ),
      );
  }

  @override
  Widget build(BuildContext context) {
    // Usamos Consumer para reconstruir cuando cambie el UserProvider
    return Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        final user = userProvider.currentUser;

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
                    color: AppTheme.primaryColor, 
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                        BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))
                    ],
                  ),
                  child: Row(
                    children: [
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: Colors.white,
                          child: Text(
                            user.name.isNotEmpty ? user.name.substring(0, 2).toUpperCase() : 'AN',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
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
                              if (user.phone != null && user.phone!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(LucideIcons.phone, color: Colors.white70, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      user.phone!,
                                      style: const TextStyle(fontSize: 14, color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ],
                              if (user.birthDate != null && user.birthDate!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(LucideIcons.cake, color: Colors.white70, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      user.birthDate!,
                                      style: const TextStyle(fontSize: 14, color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ],
                              if (user.socialMedia != null && user.socialMedia!['instagram'] != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(LucideIcons.instagram, color: Colors.white70, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      user.socialMedia!['instagram'],
                                      style: const TextStyle(fontSize: 14, color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 8), // Adjusted spacing
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
                  onTap: () => _showEditDialog(context, userProvider),
                ),
                _OptionTile(
                  icon: LucideIcons.store,
                  title: 'Datos del Club',
                  onTap: () async {
                    final club = await Provider.of<ClubRemoteDataSource>(context, listen: false).getClubByHostId(int.parse(user.id));
                    if (context.mounted) {
                      if (club != null) {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => HostClubEditScreen(club: club)));
                      } else {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se encontró información de tu club')));
                      }
                    }
                  },
                ),
                _OptionTile(
                  icon: LucideIcons.headphones,
                  title: 'Centro de Soporte',
                  onTap: () {
                    context.push('/support');
                  },
                ),
                
                const SizedBox(height: 40),

                // Botón Cerrar Sesión
                TextButton.icon(
                    onPressed: () async {
                      await Provider.of<AuthProvider>(context, listen: false).logout();
                      userProvider.logout();
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
        leading: Icon(icon, color: AppTheme.primaryColor), // Icono verde
        title: Text(title, style: const TextStyle(color: Color(0xFF333333), fontWeight: FontWeight.w500)),
        trailing: Icon(Icons.chevron_right, color: Colors.grey[300]),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
