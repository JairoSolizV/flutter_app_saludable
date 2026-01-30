import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../providers/user_provider.dart';
import '../../../data/datasources/remote/club_remote_data_source.dart';

class RequestClubScreen extends StatefulWidget {
  const RequestClubScreen({super.key});

  @override
  State<RequestClubScreen> createState() => _RequestClubScreenState();
}

class _RequestClubScreenState extends State<RequestClubScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final user = userProvider.currentUser;

      if (user == null) {
        throw Exception("Usuario no autenticado");
      }

      final clubDataSource = Provider.of<ClubRemoteDataSource>(context, listen: false);
      
      await clubDataSource.solicitarCreacionClub(
        anfitrionId: int.parse(user.id),
        nombreClub: _nameController.text.trim(),
        direccion: _addressController.text.trim(),
        hubId: 2, // Default HUB Santa Cruz
      );

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Solicitud Enviada'),
            content: const Text(
              'Tu solicitud para crear un nuevo club ha sido enviada exitosamente.\n\n'
              'El administrador revisará tu petición y te notificará pronto.'
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx); // Close dialog
                  context.pop(); // Go back
                },
                child: const Text('Entendido'),
              )
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll("Exception:", "")}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Solicitar mi Club", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF7AC142),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9E8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF7AC142).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.store, color: Color(0xFF7AC142), size: 32),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        "¡Emprende tu propio Club!\nCompleta los datos y asignaremos tu solicitud al HUB Santa Cruz.",
                        style: TextStyle(color: Color(0xFF2C5E1A), fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text("Información del Club", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              
              _buildTextField(
                controller: _nameController,
                label: "Nombre del Club",
                hint: "Ej. Club Vida Sana",
                icon: LucideIcons.tag,
                validator: (v) => v == null || v.isEmpty ? "Ingresa un nombre" : null,
              ),
              const SizedBox(height: 16),
              
              _buildTextField(
                controller: _addressController,
                label: "Dirección",
                hint: "Calle, número y barrio",
                icon: LucideIcons.mapPin,
                validator: (v) => v == null || v.isEmpty ? "Ingresa una dirección" : null,
              ),
              
              const SizedBox(height: 32),
              
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7AC142),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  child: _isLoading 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Enviar Solicitud", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.grey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF7AC142), width: 2),
        ),
        fillColor: Colors.white,
        filled: true,
      ),
      validator: validator,
      maxLines: maxLines,
    );
  }
}
