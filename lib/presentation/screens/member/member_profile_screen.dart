import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/core/utils/input_formatters.dart';
import 'package:flutter_app_saludable/core/utils/validators.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import '../../providers/user_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../data/datasources/remote/qr_remote_data_source.dart';
import '../../../data/datasources/remote/membresia_remote_data_source.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';

class MemberProfileScreen extends StatefulWidget {
  const MemberProfileScreen({super.key});

  @override
  State<MemberProfileScreen> createState() => _MemberProfileScreenState();
}

class _MemberProfileScreenState extends State<MemberProfileScreen> {
  String? _qrData;
  bool _isLoadingQR = true;
  String? _qrError;

  String? _membershipLevel;
  String? _clubName;
  bool _isLoadingMembership = true;

  @override
  void initState() {
    super.initState();
    _loadQR();
    // Cargar membresía después del primer frame para tener acceso al context/providers si es necesario
    // aunque en initState se puede llamar métodos que usen context si listen: false
    WidgetsBinding.instance.addPostFrameCallback((_) {
       _loadMembership();
    });
  }

  Future<void> _loadMembership() async {
      try {
          final userProvider = Provider.of<UserProvider>(context, listen: false);
          final user = userProvider.currentUser;
          
          if (user != null) {
              final membresiaDataSource = Provider.of<MembresiaRemoteDataSource>(context, listen: false);
              final membrs = await membresiaDataSource.getMembresiasPorUsuario(int.parse(user.id));
              
              if (mounted) {
                  setState(() {
                      if (membrs.isNotEmpty) {
                          // Tomamos la primera membresía o la más relevante
                          _membershipLevel = membrs.first.nivelNombre;
                          _clubName = membrs.first.clubNombre;
                      } else {
                          _membershipLevel = 'Sin Membresía';
                          _clubName = 'Sin Club Afiliado';
                      }
                      _isLoadingMembership = false;
                  });
              }
          }
      } catch (e) {
          debugPrint('Error cargando membresía: $e');
          if (mounted) {
              setState(() {
                  _membershipLevel = 'No disponible';
                  _isLoadingMembership = false;
              });
          }
      }
  }

  Future<void> _loadQR() async {
    try {
      final qrDataSource = Provider.of<QRRemoteDataSource>(context, listen: false);
      final qrResponse = await qrDataSource.getSocioQR();
      if (mounted) {
        setState(() {
          _qrData = qrResponse.qrPayload;
          _isLoadingQR = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _qrError = e.toString().replaceAll('Exception: ', '');
          _isLoadingQR = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.currentUser;

    if (userProvider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (user == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Error: Usuario no encontrado',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () async {
                    final auth =
                        Provider.of<AuthProvider>(context, listen: false);
                    final userProv =
                        Provider.of<UserProvider>(context, listen: false);

                    await auth.logout();
                    userProv.logout();

                    if (context.mounted) {
                      context.go('/guest-home');
                    }
                  },
                  icon: const Icon(LucideIcons.logOut),
                  label: const Text('Cerrar sesión'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[50],
                    foregroundColor: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200.0,
            floating: false,
            pinned: true,
            backgroundColor: AppTheme.primaryColor,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppTheme.primaryGradient,
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
                           style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
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
                   // QR del Socio (encima del teléfono)
                   if (_isLoadingQR)
                     Container(
                       padding: const EdgeInsets.all(20),
                       child: const Center(child: CircularProgressIndicator()),
                     )
                   else if (_qrError != null)
                     Container(
                       padding: const EdgeInsets.all(20),
                       decoration: BoxDecoration(
                         color: Colors.white,
                         borderRadius: BorderRadius.circular(16),
                         boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
                       ),
                       child: Column(
                         children: [
                           const Icon(LucideIcons.qrCode, size: 48, color: Colors.grey),
                           const SizedBox(height: 8),
                           Text(
                             'Error al cargar QR',
                             style: TextStyle(color: Colors.grey[600], fontSize: 12),
                           ),
                           TextButton(
                             onPressed: _loadQR,
                             child: const Text('Reintentar'),
                           ),
                         ],
                       ),
                     )
                   else if (_qrData != null)
                     Container(
                       padding: const EdgeInsets.all(20),
                       decoration: BoxDecoration(
                         color: Colors.white,
                         borderRadius: BorderRadius.circular(16),
                         boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
                       ),
                       child: Column(
                         children: [
                           const Row(
                             children: [
                               Icon(LucideIcons.qrCode, color: AppTheme.primaryColor),
                               SizedBox(width: 8),
                               Text(
                                 'Código QR de Identificación',
                                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                               ),
                             ],
                           ),
                           const SizedBox(height: 16),
                           const Text(
                             'Muestra este QR al anfitrión para identificarte',
                             style: TextStyle(fontSize: 12, color: Colors.grey),
                             textAlign: TextAlign.center,
                           ),
                           const SizedBox(height: 16),
                           Container(
                             padding: const EdgeInsets.all(16),
                             decoration: BoxDecoration(
                               color: Colors.white,
                               borderRadius: BorderRadius.circular(12),
                               border: Border.all(color: AppTheme.primaryColor, width: 2),
                             ),
                             child: QrImageView(
                               data: _qrData!,
                               version: QrVersions.auto,
                               size: 200.0,
                               foregroundColor: const Color(0xFF333333),
                             ),
                           ),
                         ],
                       ),
                     ),
                   const SizedBox(height: 16),
                   _ProfileCard(
                       icon: LucideIcons.phone,
                       title: 'Teléfono',
                       value: user.phone ?? 'No registrado'
                   ),
                   if (user.birthDate != null && user.birthDate!.isNotEmpty) ...[
                     const SizedBox(height: 16),
                     _ProfileCard(
                         icon: LucideIcons.calendar,
                         title: 'Fecha de Nacimiento',
                         value: _formatBirthDate(user.birthDate!)
                     ),
                   ],
                   const SizedBox(height: 16),
                   _ProfileCard(
                       icon: LucideIcons.trophy,
                       title: 'Membresía',
                       value: _isLoadingMembership ? 'Cargando...' : (_membershipLevel ?? 'Sin Info'),
                       trailing: const Icon(Icons.star, color: Colors.orange),
                   ),
                   const SizedBox(height: 16),
                   _ProfileCard(
                       icon: LucideIcons.mapPin,
                       title: 'Club Principal',
                       value: _isLoadingMembership ? 'Cargando...' : (_clubName ?? 'Sin Club Afiliado'),
                   ),
                   const SizedBox(height: 24),
                   SizedBox(
                       width: double.infinity,
                       child: ElevatedButton.icon(
                           onPressed: () {
                             context.push('/support');
                           },
                           icon: const Icon(LucideIcons.headphones),
                           label: const Text('Centro de Soporte'),
                           style: ElevatedButton.styleFrom(
                               backgroundColor: Colors.white,
                               foregroundColor: Colors.black87,
                               side: BorderSide(color: Colors.grey.shade300),
                               padding: const EdgeInsets.all(16)
                           ),
                       )
                   ),
                   const SizedBox(height: 16),
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

  String _formatBirthDate(String dateStr) {
    try {
      // Intentar parsear como yyyy-MM-dd
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return dateStr; // Si no se puede parsear, devolver el string original
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
      DateTime? selectedDate;

      // Si hay fecha de nacimiento, parsearla
      if (user?.birthDate != null && user!.birthDate!.isNotEmpty) {
        try {
          selectedDate = DateTime.parse(user.birthDate!);
        } catch (e) {
          // Ignorar error de parsing
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
                              readOnly: true,
                              decoration: InputDecoration(
                                labelText: 'Nombre',
                                helperText: 'El nombre no puede ser modificado.',
                                filled: true,
                                fillColor: Colors.grey[100],
                              ),
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
                              // Mostrar indicador de carga
                              showDialog(
                                context: ctx,
                                barrierDismissible: false,
                                builder: (context) => const Center(child: CircularProgressIndicator()),
                              );
                              
                              // Usar AuthProvider para actualizar en Backend
                              await authProvider.updateProfile(
                                  name: nameCtrl.text.trim(),
                                  phone: Validators.toBoliviaE164(phoneCtrl.text),
                                  birthDate: birthDateCtrl.text.trim().isEmpty ? null : birthDateCtrl.text.trim(),
                              );
                              
                              // Actualizar UserProvider con el usuario actualizado de AuthProvider
                              if (authProvider.currentUser != null) {
                                userProvider.setUser(authProvider.currentUser!);
                              }
                              
                              if (ctx.mounted) {
                                Navigator.pop(ctx); // Cerrar diálogo de carga
                                Navigator.pop(ctx); // Cerrar diálogo de edición
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text('Perfil actualizado correctamente'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                Navigator.pop(ctx); // Cerrar diálogo de carga si está abierto
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
                        child: Icon(icon, color: AppTheme.primaryColor),
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
