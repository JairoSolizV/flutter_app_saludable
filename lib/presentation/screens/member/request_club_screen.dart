import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:latlong2/latlong.dart';
import '../../providers/user_provider.dart';
import '../../../data/datasources/remote/club_remote_data_source.dart';
import '../../widgets/schedule_selector.dart';
import '../../widgets/location_picker_dialog.dart';
import 'package:flutter_app_saludable/core/clubs/club_location.dart';
import 'package:flutter_app_saludable/core/errors/error_mapper.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';
import 'package:flutter_app_saludable/core/utils/input_formatters.dart';

class RequestClubScreen extends StatefulWidget {
  const RequestClubScreen({super.key});

  @override
  State<RequestClubScreen> createState() => _RequestClubScreenState();
}
class _RequestClubScreenState extends State<RequestClubScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  
  String _schedule = '';
  double? _lat;
  double? _lng;
  
  bool _isLoading = false;

  bool get _hasValidLocation =>
      ClubLocationValidation.isValidCoordinates(_lat, _lng);

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    if (_schedule.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona el horario de atención'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (!_hasValidLocation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(ClubLocationFormMessages.selectLocation),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final user = userProvider.currentUser;

      if (user == null) {
        throw Exception("Usuario no autenticado");
      }

      final clubDataSource = Provider.of<ClubRemoteDataSource>(context, listen: false);
      
      // Debug: Verificar valores antes de enviar
      debugPrint('[REQUEST CLUB] Enviando solicitud:');
      debugPrint('[REQUEST CLUB]   nombreClub: ${_nameController.text.trim()}');
      debugPrint('[REQUEST CLUB]   direccion: ${_addressController.text.trim()}');
      debugPrint('[REQUEST CLUB]   horario: $_schedule');
      debugPrint('[REQUEST CLUB]   lat: $_lat');
      debugPrint('[REQUEST CLUB]   lng: $_lng');
      debugPrint('[REQUEST CLUB]   hubId: 1');
      debugPrint('[REQUEST CLUB]   anfitrionId: ${user.id}');
      
      if (!_hasValidLocation) {
        throw Exception(ClubLocationFormMessages.selectLocation);
      }
      
      await clubDataSource.solicitarCreacionClub(
        anfitrionId: int.parse(user.id),
        nombreClub: _nameController.text.trim(),
        direccion: _addressController.text.trim(),
        horario: _schedule,
        lat: _lat!,
        lng: _lng!,
        hubId: 1, // Default HUB Santa Cruz----------------------------------------------------------- Esto puede cambiarse a HUBID de la BD cuando se extienda por  hubs
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
            content: Text(ErrorMapper.publicMessage(e)),
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
        backgroundColor: AppTheme.primaryColor,
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
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.store, color: AppTheme.primaryColor, size: 32),
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
                maxLength: 100,
                inputFormatters: AppFormatters.largo(100),
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _addressController,
                label: "Dirección",
                hint: "Calle, número y barrio",
                icon: LucideIcons.mapPin,
                validator: (v) => v == null || v.isEmpty ? "Ingresa una dirección" : null,
                maxLength: 200,
                inputFormatters: AppFormatters.largo(200),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              const Text("Horario de Atención", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              
              ScheduleSelector(
                onScheduleChanged: (schedule) {
                  setState(() => _schedule = schedule);
                },
              ),
              
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              const Text("Ubicación del Club", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              
              OutlinedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push<LatLng>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LocationPickerDialog(
                        initialLocation: _hasValidLocation
                            ? LatLng(_lat!, _lng!)
                            : null,
                      ),
                    ),
                  );
                  
                  if (result != null) {
                    if (ClubLocationValidation.isValidCoordinates(
                      result.latitude,
                      result.longitude,
                    )) {
                      debugPrint(
                        '[REQUEST CLUB] Ubicación seleccionada: Lat=${result.latitude}, Lng=${result.longitude}',
                      );
                      setState(() {
                        _lat = result.latitude;
                        _lng = result.longitude;
                      });
                    } else if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ClubLocationErrorMessages.forCode(
                              ClubLocationErrorCodes.invalid,
                            ),
                          ),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  } else {
                    debugPrint('[REQUEST CLUB] Usuario canceló la selección de ubicación');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Debes confirmar la ubicación para continuar'),
                          backgroundColor: Colors.orange,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(LucideIcons.mapPin),
                label: Text(_hasValidLocation
                    ? ClubLocationFormMessages.locationSelected
                    : 'Seleccionar Ubicación'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  side: BorderSide(
                    color: _hasValidLocation
                        ? AppTheme.primaryColor
                        : Colors.grey.shade400,
                    width: 2,
                  ),
                ),
              ),
              
              if (_hasValidLocation) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F9E8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ClubLocationFormMessages.locationSelected,
                          style: TextStyle(fontSize: 12, color: Color(0xFF2C5E1A)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 32),
              
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: (_isLoading || !_hasValidLocation) ? null : _submitRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
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
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
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
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
        fillColor: Colors.white,
        filled: true,
        counterText: '',
      ),
      validator: validator,
      maxLines: maxLines,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
    );
  }
}
