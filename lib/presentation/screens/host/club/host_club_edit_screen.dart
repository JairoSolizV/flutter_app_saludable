import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../data/datasources/remote/club_remote_data_source.dart';
import '../../../../main.dart'; // acceso a clubRemoteDataSource global

class HostClubEditScreen extends StatefulWidget {
  final Club club;

  const HostClubEditScreen({super.key, required this.club});

  @override
  State<HostClubEditScreen> createState() => _HostClubEditScreenState();
}

class _HostClubEditScreenState extends State<HostClubEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _scheduleCtrl;
  late TextEditingController _imageCtrl;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.club.nombreClub);
    _addressCtrl = TextEditingController(text: widget.club.direccion);
    _scheduleCtrl = TextEditingController(text: widget.club.horario);
    _imageCtrl = TextEditingController(); // Initially empty, will fetch
    _loadCurrentPhoto();
  }

  Future<void> _loadCurrentPhoto() async {
    try {
      final photos = await clubRemoteDataSource.getFotosClub(widget.club.id);
      if (photos.isNotEmpty) {
        // Assume last is newest
        final cover = photos.lastWhere((p) => p.tipo == 'PORTADA', orElse: () => photos.last);
        setState(() {
          _imageCtrl.text = cover.urlFoto;
        });
      }
    } catch (e) {
      // Ignore error keeping field empty
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _scheduleCtrl.dispose();
    _imageCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final Map<String, dynamic> data = {
        'nombreClub': _nameCtrl.text.trim(),
        'direccion': _addressCtrl.text.trim(),
        'horario': _scheduleCtrl.text.trim(),
        // 'fotoUrl': _imageCtrl.text.trim(), // REMOVED: Managed separately
      };

      // 1. Update basic info
      await clubRemoteDataSource.updateClub(widget.club.id, data);

      // 2. Update photo if changed and not empty
      if (_imageCtrl.text.trim().isNotEmpty) {
         // Check if it's different handling could be complex without storing original
         // For now, always upload if not empty. A better way: check against loaded.
         // Or just upload. Backend adds to list.
         await clubRemoteDataSource.subirFotoClub(widget.club.id, _imageCtrl.text.trim());
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Club actualizado correctamente')),
        );
        context.pop(); // Volver
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Editar Club"),
        backgroundColor: const Color(0xFF7AC142),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Detalles del Club", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              _buildTextField(
                label: "Nombre del Club",
                controller: _nameCtrl,
                icon: LucideIcons.store,
                validator: (v) => v!.isEmpty ? "Requerido" : null,
              ),
              const SizedBox(height: 16),

              _buildTextField(
                label: "Dirección",
                controller: _addressCtrl,
                icon: LucideIcons.mapPin,
                validator: (v) => v!.isEmpty ? "Requerido" : null,
              ),
              const SizedBox(height: 16),

              _buildTextField(
                label: "Horario",
                controller: _scheduleCtrl,
                icon: LucideIcons.clock,
                hint: "Ej. Lun-Vie 08:00 - 12:00",
              ),
              const SizedBox(height: 30),

              const Text("Imagen del Club", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("Ingresa la URL de la imagen de portada de tu club.", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),

              _buildTextField(
                label: "URL de la Imagen",
                controller: _imageCtrl,
                icon: LucideIcons.image,
                hint: "https://ejemplo.com/foto.jpg",
                maxLines: 1,
              ),
              
              // Preview de la imagen si hay URL
              ValueListenableBuilder(
                valueListenable: _imageCtrl,
                builder: (context, value, child) {
                  if (value.text.isEmpty) return const SizedBox.shrink();
                  return Container(
                    margin: const EdgeInsets.only(top: 16),
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: Image.network(
                      value.text,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) => const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7AC142),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("GUARDAR CAMBIOS", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? Function(String?)? validator,
    String? hint,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.grey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
