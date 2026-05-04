import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../../data/datasources/remote/membresia_remote_data_source.dart';
import '../../../../data/datasources/remote/club_remote_data_source.dart';
import '../../../../domain/entities/club_membership.dart';
import '../../../providers/user_provider.dart';

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
                backgroundColor: const Color(0xFF7AC142),
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
                backgroundColor: const Color(0xFF7AC142),
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
                backgroundColor: const Color(0xFF7AC142),
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
                backgroundColor: const Color(0xFF7AC142),
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

  /// Calcula la distancia en metros entre dos coordenadas usando la fórmula de Haversine
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Meter, LatLng(lat1, lon1), LatLng(lat2, lon2));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Escanear Código QR"),
        backgroundColor: const Color(0xFF7AC142),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: cameraController.torchState,
              builder: (context, state, child) {
                switch (state) {
                  case TorchState.off:
                    return const Icon(Icons.flash_off, color: Colors.grey);
                  case TorchState.on:
                    return const Icon(Icons.flash_on, color: Colors.yellow);
                }
              },
            ),
            onPressed: () => cameraController.toggleTorch(),
          ),
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: cameraController.cameraFacingState,
              builder: (context, state, child) {
                switch (state) {
                  case CameraFacing.front:
                    return const Icon(Icons.camera_front);
                  case CameraFacing.back:
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
                border: Border.all(color: const Color(0xFF7AC142), width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                 child: CircularProgressIndicator(color: Color(0xFF7AC142)),
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

      // Capturar DataSources ANTES de cualquier await para evitar usar context tras gaps async
      final clubDataSource = Provider.of<ClubRemoteDataSource>(context, listen: false);
      final membresiaDataSource = Provider.of<MembresiaRemoteDataSource>(context, listen: false);

      // 1. Solicitar permisos de ubicación
      await _requestLocationPermission();

      // 2. Obtener ubicación actual del usuario
      final Position userPosition = await _getCurrentLocation();
      final double userLat = userPosition.latitude;
      final double userLng = userPosition.longitude;

      // 3. Obtener coordenadas del club
      Club? club;
      if (mounted) {
        club = await clubDataSource.getClubById(clubId);
      } else {
        return;
      }
      
      if (club == null) {
        throw Exception("No se pudo obtener la información del club");
      }

      // 4. Calcular distancia entre usuario y club
      final double distance = _calculateDistance(
        userLat, 
        userLng, 
        club.lat, 
        club.lng
      );

      // 5. Validar que esté dentro de 40 metros (opcional - comentado para asistencias globales)
      // Las asistencias globales permiten registrar en cualquier club activo
      // La validación de distancia es opcional y puede ser removida si se desea
      const double maxDistanceMeters = 40.0;
      if (distance > maxDistanceMeters) {
        // Mostrar advertencia pero permitir continuar (asistencias globales)
        final shouldContinue = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Advertencia de Distancia'),
            content: Text(
              "Estás a ${distance.toStringAsFixed(1)}m del club. "
              "¿Deseas registrar la asistencia de todas formas?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7AC142),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Continuar'),
              ),
            ],
          ),
        );
        if (shouldContinue != true) {
          if (mounted) {
            setState(() => _isProcessing = false);
          }
          return;
        }
      }

      // 6. Obtener membresía del usuario (asistencias globales - cualquier club activo)
      if (!mounted) return;
      final List<ClubMembership> membresias =
          await membresiaDataSource.getMembresiasPorUsuario(int.parse(user.id));
      
      if (membresias.isEmpty) {
        throw Exception("No tienes una membresía activa. Debes ser socio de un club para registrar asistencia.");
      }

      // Usar la primera membresía activa (asistencias globales - sin restricción de HUB/club)
      final membership = membresias.first;

      // 7. Registrar Asistencia
      final asistenciaResponse = await membresiaDataSource.registrarAsistencia(
        membresiaId: membership.id,
        clubId: clubId, // Club del QR escaneado (cualquier club activo)
        latitud: userLat,
        longitud: userLng,
      );

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
      
      final errorMessage = e.toString().replaceAll('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $errorMessage"), backgroundColor: Colors.red),
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
