import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../providers/user_provider.dart';

class BasicUserEditProfileScreen extends StatefulWidget {
  const BasicUserEditProfileScreen({super.key});

  @override
  State<BasicUserEditProfileScreen> createState() => _BasicUserEditProfileScreenState();
}

class _BasicUserEditProfileScreenState extends State<BasicUserEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController; // Read only?
  late TextEditingController _phoneController;
  late TextEditingController _birthDateController;
  
  // Social Media Controllers
  final _instagramController = TextEditingController();
  final _facebookController = TextEditingController();
  final _tiktokController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<UserProvider>(context, listen: false).currentUser;
    _nameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _birthDateController = TextEditingController(text: user?.birthDate ?? '');
    
    // Load social media if exists
    if (user?.socialMedia != null) {
        _instagramController.text = user!.socialMedia!['instagram'] ?? '';
        _facebookController.text = user.socialMedia!['facebook'] ?? '';
        _tiktokController.text = user.socialMedia!['tiktok'] ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _birthDateController.dispose();
    _instagramController.dispose();
    _facebookController.dispose();
    _tiktokController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF7AC142), 
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        // Backend usually expects YYYY-MM-DD
        _birthDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        final provider = Provider.of<UserProvider>(context, listen: false);
        
        // Prepare social media map
        final Map<String, dynamic> socialMedia = {};
        if (_instagramController.text.isNotEmpty) socialMedia['instagram'] = _instagramController.text;
        if (_facebookController.text.isNotEmpty) socialMedia['facebook'] = _facebookController.text;
        if (_tiktokController.text.isNotEmpty) socialMedia['tiktok'] = _tiktokController.text;

        await provider.updateUserProfile(
          name: _nameController.text,
          phone: _phoneController.text,
          birthDate: _birthDateController.text.isEmpty ? null : _birthDateController.text,
          socialMedia: socialMedia.isEmpty ? null : socialMedia,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Perfil actualizado correctamente')),
          );
          context.pop();
        }
      } catch (e) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al actualizar: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
     return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        title: const Text('Editar Mis Datos', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Avatar
               Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFF7AC142),
                    child: Text(
                      _nameController.text.isNotEmpty ? _nameController.text.substring(0, 1).toUpperCase() : 'U',
                      style: const TextStyle(fontSize: 40, color: Colors.white),
                    ),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF333333),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      onPressed: () {
                         // TODO: Implementar subida de foto
                      },
                    ),
                  )
                ],
              ),
              const SizedBox(height: 10),
              const Text("Cambiar foto de perfil", style: TextStyle(color: Color(0xFF7AC142), fontSize: 12)),
              
              const SizedBox(height: 30),

              // Campos Generales
              _buildSectionTitle("Información Personal"),
              _buildTextField(label: "Nombre Completo", controller: _nameController, icon: Icons.person_outline),
              const SizedBox(height: 16),
              _buildTextField(label: "Correo Electrónico", controller: _emailController, icon: Icons.email_outlined, readOnly: true), // Email read-only usually
              const SizedBox(height: 16),
              _buildTextField(label: "Número de Celular", controller: _phoneController, icon: Icons.phone_android),
              const SizedBox(height: 16),
              
              // Fecha Nacimiento
               GestureDetector(
                onTap: () => _selectDate(context),
                child: AbsorbPointer(
                  child: _buildTextField(
                    label: "Fecha de Nacimiento", 
                    controller: _birthDateController, 
                    icon: Icons.calendar_today,
                  ),
                ),
              ),
              
              const SizedBox(height: 30),

              // Redes Sociales
              _buildSectionTitle("Redes Sociales (Usuarios)"),
              _buildTextField(label: "Instagram", controller: _instagramController, icon: LucideIcons.instagram),
              const SizedBox(height: 16),
              _buildTextField(label: "Facebook", controller: _facebookController, icon: LucideIcons.facebook),
              const SizedBox(height: 16),
              // Lucide doesn't have tiktok in this version likely, using generic or material
              _buildTextField(label: "TikTok", controller: _tiktokController, icon: Icons.music_note),

              const SizedBox(height: 40),

              // Botón Guardar
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveProfile,
                  icon: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save, color: Colors.white),
                  label: Text(
                    _isLoading ? "Guardando..." : "Guardar Cambios",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7AC142),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16, top: 8),
        child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
      ),
    );
  }

  Widget _buildTextField({
    required String label, 
    required TextEditingController controller, 
    required IconData icon,
    bool readOnly = false,
  }) {
    return Container(
       decoration: BoxDecoration(
         color: Colors.grey[50],
         borderRadius: BorderRadius.circular(12),
         border: Border.all(color: Colors.grey[200]!),
       ),
       child: TextFormField(
         controller: controller,
         readOnly: readOnly,
         decoration: InputDecoration(
           labelText: label,
           prefixIcon: Icon(icon, color: Colors.grey[400]),
           border: InputBorder.none,
           contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
           floatingLabelBehavior: FloatingLabelBehavior.auto,
         ),
       ),
    );
  }
}
