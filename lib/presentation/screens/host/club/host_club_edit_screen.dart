import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:latlong2/latlong.dart';
import '../../../../data/datasources/remote/club_remote_data_source.dart';
import '../../../../main.dart'; // acceso a clubRemoteDataSource global
import '../../../widgets/schedule_selector.dart';
import '../../../widgets/location_picker_dialog.dart';

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
  late TextEditingController _imageCtrl;

  String _schedule = '';
  double? _lat;
  double? _lng;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.club.nombreClub);
    _addressCtrl = TextEditingController(text: widget.club.direccion);
    _schedule = widget.club.horario; // Inicializar con el horario del club
    _lat = widget.club.lat; // Inicializar con las coordenadas del club
    _lng = widget.club.lng;
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
    _imageCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_schedule.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona el horario de atención'), backgroundColor: Colors.orange),
        );
        setState(() => _isLoading = false);
        return;
      }

      if (_lat == null || _lng == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona la ubicación del club'), backgroundColor: Colors.orange),
        );
        setState(() => _isLoading = false);
        return;
      }

      final Map<String, dynamic> data = {
        'nombreClub': _nameCtrl.text.trim(),
        'direccion': _addressCtrl.text.trim(),
        'horario': _schedule,
        'lat': _lat!,
        'lng': _lng!,
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
              // Sección: Detalles del Club
              const Text("Detalles del Club", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              _buildTextField(
                label: "Nombre del Club",
                controller: _nameCtrl,
                icon: LucideIcons.store,
                readOnly: true,
                helperText: "El nombre del club no se puede cambiar libremente. Por favor, comunícate con soporte.",
              ),
              const SizedBox(height: 24),

              // Sección: Horario de Atención
              const Divider(height: 1),
              const SizedBox(height: 24),
              const Text("Horario de Atención", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              
              ScheduleSelector(
                initialSchedule: _schedule.isNotEmpty ? _schedule : null,
                onScheduleChanged: (schedule) {
                  setState(() => _schedule = schedule);
                },
              ),
              const SizedBox(height: 24),

              // Sección: Ubicación del Club
              const Divider(height: 1),
              const SizedBox(height: 24),
              const Text("Ubicación del Club", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              
              OutlinedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push<LatLng>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LocationPickerDialog(
                        initialLocation: _lat != null && _lng != null
                            ? LatLng(_lat!, _lng!)
                            : null,
                      ),
                    ),
                  );
                  
                  if (result != null) {
                    setState(() {
                      _lat = result.latitude;
                      _lng = result.longitude;
                    });
                  }
                },
                icon: const Icon(LucideIcons.mapPin),
                label: Text(_lat == null ? 'Seleccionar Ubicación' : 'Ubicación seleccionada'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  side: BorderSide(
                    color: _lat == null ? Colors.grey.shade400 : const Color(0xFF7AC142),
                    width: 2,
                  ),
                ),
              ),
              
              if (_lat != null && _lng != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F9E8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFF7AC142), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Lat: ${_lat!.toStringAsFixed(6)}, Lng: ${_lng!.toStringAsFixed(6)}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF2C5E1A)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Sección: Dirección
              const Divider(height: 1),
              const SizedBox(height: 24),
              _buildTextField(
                label: "Dirección",
                controller: _addressCtrl,
                icon: LucideIcons.mapPin,
                validator: (v) => v!.isEmpty ? "Requerido" : null,
              ),
              const SizedBox(height: 24),

              // Sección: Imagen del Club
              const Divider(height: 1),
              const SizedBox(height: 24),
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

              const SizedBox(height: 32),

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
    bool readOnly = false,
    String? helperText,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        prefixIcon: Icon(icon, color: Colors.grey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: readOnly,
        fillColor: readOnly ? Colors.grey[100] : null,
      ),
    );
  }
}
