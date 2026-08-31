import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../data/datasources/remote/membresia_remote_data_source.dart';
import '../../../../domain/entities/club_membership.dart';
import '../../../providers/user_provider.dart';
import 'package:flutter_app_saludable/core/attendance/attendance_location_params.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/core/errors/error_mapper.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';

/// Extra de navegación al catálogo del club de la membresía (no el del QR).
Map<String, dynamic> comboRequiredOrderExtra(ClubMembership membership) {
  return {
    'clubId': membership.clubId,
    'clubNombre': membership.clubNombre,
  };
}

/// Diálogo de negocio cuando POST /asistencias/registrar responde COMBO_REQUIRED.
class ComboRequiredAttendanceDialog extends StatelessWidget {
  const ComboRequiredAttendanceDialog({super.key});

  static const String title = 'Combo requerido';
  static const String body =
      'Para registrar tu asistencia necesitas tener un combo entregado hoy. '
      'Puedes realizar tu pedido en el club de tu membresía.';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(title),
      content: const Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Entendido'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Hacer pedido'),
        ),
      ],
    );
  }
}

/// Muestra el diálogo COMBO_REQUIRED y, si el socio acepta, abre el catálogo
/// del club de su membresía.
Future<void> handleComboRequiredAttendance({
  required BuildContext context,
  required ClubMembership membership,
}) async {
  final goToOrder = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const ComboRequiredAttendanceDialog(),
  );
  if (!context.mounted) return;
  if (goToOrder == true) {
    context.push(
      '/member-orders/new/club-products',
      extra: comboRequiredOrderExtra(membership),
    );
  }
}

class MemberQrScanScreen extends StatefulWidget {
  const MemberQrScanScreen({super.key});

  @override
  State<MemberQrScanScreen> createState() => _MemberQrScanScreenState();
}

class _MemberQrScanScreenState extends State<MemberQrScanScreen> {
  bool _isProcessing = false;
  MobileScannerController cameraController = MobileScannerController();

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      await Permission.camera.request();
    }
  }

  Future<void> _requestLocationPermission() async {
    if (!mounted) return;
    
    var status = await Permission.location.status;
    
    // Si el permiso está denegado permanentemente, mostrar diálogo para abrir configuración
    if (status.isPermanentlyDenied) {
      if (!mounted) return;
      final shouldOpenSettings = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Permiso de Ubicación Requerido'),
          content: const Text(
            'Para registrar tu asistencia, necesitamos acceso a tu ubicación. '
            'El permiso está deshabilitado. Por favor, habilítalo en la configuración de la app.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Abrir Configuración'),
            ),
          ],
        ),
      );
      
      if (shouldOpenSettings == true) {
        await openAppSettings();
        // Verificar nuevamente después de abrir configuración
        await Future.delayed(const Duration(milliseconds: 500));
        status = await Permission.location.status;
        if (!status.isGranted) {
          throw Exception('Por favor, habilita el permiso de ubicación en la configuración de la app.');
        }
      } else {
        throw Exception('Se requiere permiso de ubicación para registrar asistencia');
      }
    } else if (!status.isGranted) {
      // Mostrar diálogo explicativo antes de solicitar el permiso
      if (!mounted) return;
      final shouldRequest = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Permiso de Ubicación'),
          content: const Text(
            'Para registrar tu asistencia, necesitamos verificar que estés cerca del club. '
            '¿Permites que la app acceda a tu ubicación?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Permitir'),
            ),
          ],
        ),
      );
      
      if (shouldRequest == true) {
        status = await Permission.location.request();
        if (!status.isGranted) {
          throw Exception('Se requiere permiso de ubicación para registrar asistencia');
        }
      } else {
        throw Exception('Se requiere permiso de ubicación para registrar asistencia');
      }
    }
  }

  Future<Position> _getCurrentLocation() async {
    if (!mounted) {
      throw Exception('La aplicación no está disponible');
    }
    
    // Verificar si los servicios de ubicación están habilitados
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) throw Exception('La aplicación no está disponible');
      final shouldOpenSettings = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Ubicación Deshabilitada'),
          content: const Text(
            'Los servicios de ubicación están deshabilitados. '
            'Por favor, actívalos en la configuración del dispositivo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Abrir Configuración'),
            ),
          ],
        ),
      );
      
      if (shouldOpenSettings == true) {
        await Geolocator.openLocationSettings();
        throw Exception('Por favor, activa los servicios de ubicación y vuelve a intentar.');
      } else {
        throw Exception('Los servicios de ubicación están deshabilitados.');
      }
    }

    // Verificar permisos (ya deberían estar otorgados por _requestLocationPermission)
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      throw Exception('Se requiere permiso de ubicación para registrar asistencia');
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return throw Exception('Permiso denegado permanentemente');
      
      final shouldOpenSettings = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Permiso Denegado'),
          content: const Text(
            'Los permisos de ubicación están permanentemente denegados. '
            'Por favor, habilítalos en la configuración de la app.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Abrir Configuración'),
            ),
          ],
        ),
      );
      
      if (shouldOpenSettings == true) {
        await openAppSettings();
        throw Exception('Por favor, habilita el permiso de ubicación en la configuración.');
      } else {
        throw Exception('Se requiere permiso de ubicación para registrar asistencia');
      }
    }

    // Obtener ubicación actual
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Escanear Código QR"),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: ValueListenableBuilder<MobileScannerState>(
              valueListenable: cameraController,
              builder: (context, state, child) {
                switch (state.torchState) {
                  case TorchState.off:
                  case TorchState.unavailable:
                    return const Icon(Icons.flash_off, color: Colors.grey);
                  case TorchState.on:
                    return const Icon(Icons.flash_on, color: Colors.yellow);
                  case TorchState.auto:
                    return const Icon(Icons.flash_auto, color: Colors.yellow);
                }
              },
            ),
            onPressed: () => cameraController.toggleTorch(),
          ),
          IconButton(
            icon: ValueListenableBuilder<MobileScannerState>(
              valueListenable: cameraController,
              builder: (context, state, child) {
                switch (state.cameraDirection) {
                  case CameraFacing.front:
                    return const Icon(Icons.camera_front);
                  case CameraFacing.back:
                    return const Icon(Icons.camera_rear);
                  case CameraFacing.external:
                  case CameraFacing.unknown:
                    return const Icon(Icons.camera_rear);
                }
              },
            ),
            onPressed: () => cameraController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: _onDetect,
          ),
          
          // Overlay de guía
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                 child: CircularProgressIndicator(color: AppTheme.primaryColor),
              ),
            )
        ],
      ),
    );
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return; // Evitar múltiples escaneos
    
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        setState(() => _isProcessing = true);
        await _processQrCode(barcode.rawValue!);
        break; // Solo procesar el primero
      }
    }
  }

  Future<void> _processQrCode(String rawData) async {
    try {
      final Map<String, dynamic> data = jsonDecode(rawData);
      
      if (data['type'] != 'attendance' || data['clubId'] == null) {
         throw Exception("Código QR no válido para asistencia");
      }

      final int clubId = data['clubId'];
      final user = Provider.of<UserProvider>(context, listen: false).currentUser;
      if (user == null) throw Exception("Usuario no autenticado");

      // Capturar DataSource ANTES de cualquier await
      final membresiaDataSource =
          Provider.of<MembresiaRemoteDataSource>(context, listen: false);

      // 1. Solicitar permisos de ubicación
      await _requestLocationPermission();

      // 2. Obtener ubicación actual del usuario
      final Position userPosition = await _getCurrentLocation();
      final location = AttendanceLocationParams.fromPosition(userPosition);

      // 3. Obtener membresía del usuario (asistencias globales - cualquier club activo)
      if (!mounted) return;
      final List<ClubMembership> membresias =
          await membresiaDataSource.getMembresiasPorUsuario(int.parse(user.id));
      
      if (membresias.isEmpty) {
        throw Exception("No tienes una membresía activa. Debes ser socio de un club para registrar asistencia.");
      }

      // Usar la primera membresía activa (asistencias globales - sin restricción de HUB/club)
      final membership = membresias.first;

      // 4. Registrar asistencia (validación de distancia en backend)
      late final AsistenciaResponse asistenciaResponse;
      try {
        asistenciaResponse = await membresiaDataSource.registrarAsistencia(
          membresiaId: membership.id,
          clubId: clubId,
          latitud: location.latitud,
          longitud: location.longitud,
          precisionMetros: location.precisionMetros,
        );
      } on ComboRequiredException {
        if (!mounted) return;
        await handleComboRequiredAttendance(
          context: context,
          membership: membership,
        );
        if (mounted) setState(() => _isProcessing = false);
        return;
      }

      if (!mounted) return;

      // Detener la cámara
      await cameraController.stop();
      if (!mounted) return;
      setState(() => _isProcessing = false);

      // Mostrar éxito con información de racha
      final shouldReload = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              const Icon(LucideIcons.checkCircle, color: Colors.green, size: 28),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "¡Asistencia Registrada!",
                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(asistenciaResponse.mensaje ?? "Tu visita ha sido registrada correctamente. ¡Disfruta tu consumo!"),
                if (asistenciaResponse.rachaActual != null || asistenciaResponse.rachaMaxima != null) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  if (asistenciaResponse.rachaActual != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.flame, color: Colors.orange, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Racha Actual: ${asistenciaResponse.rachaActual} días',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  if (asistenciaResponse.rachaMaxima != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.trophy, color: Colors.amber, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Racha Máxima: ${asistenciaResponse.rachaMaxima} días',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true); // Retornar true para indicar que se debe recargar
              },
              child: const Text("Aceptar"),
            )
          ],
        ),
      );

      if (!mounted) return;
      // Volver al home y recargar datos
      context.pop(shouldReload ?? true); // Retornar resultado para que el home sepa que debe recargar

    } catch (e) {
      if (!mounted) return;
      
      final errorMessage = ErrorMapper.publicMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
      // Retardo para permitir intentar de nuevo
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _isProcessing = false);
    }
  }
  
  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}
