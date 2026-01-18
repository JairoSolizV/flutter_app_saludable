import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../../data/datasources/remote/club_remote_data_source.dart';
import '../../../data/datasources/remote/membresia_remote_data_source.dart';

class HostScanScreen extends StatefulWidget {
  const HostScanScreen({super.key});

  @override
  State<HostScanScreen> createState() => _HostScanScreenState();
}

class _HostScanScreenState extends State<HostScanScreen> {
  bool _isScanning = true;

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

  void _onDetect(BarcodeCapture capture) {
    if (!_isScanning) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? code = barcodes.first.rawValue;
      if (code != null) {
        setState(() {
          _isScanning = false;
        });
        _handleScanResult(code);
      }
    }
  }

  Future<void> _handleScanResult(String code) async {
    final scannedUserId = int.tryParse(code);
    if (scannedUserId == null) {
      _showError('Código QR no válido: $code');
      return;
    }

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUser = userProvider.currentUser;
    if (currentUser == null) {
      _showError('No hay sesión de anfitrión activa');
      return;
    }

    final int hostId = int.tryParse(currentUser.id) ?? 0;
    
    // Dialogo de confirmación inicial
    final shouldProcess = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Registrar Nuevo Socio'),
        content: Text('ID detectado: $scannedUserId\n\n¿Deseas agregar este usuario a tu Club?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Registrar'),
          ),
        ],
      ),
    );

    if (shouldProcess != true) {
      setState(() => _isScanning = true);
      return;
    }

    // Proceso de registro
    _showLoading();

    try {
      final clubDataSource = Provider.of<ClubRemoteDataSource>(context, listen: false);
      final membresiaDataSource = Provider.of<MembresiaRemoteDataSource>(context, listen: false);

      // 1. Obtener Club del Anfitrión
      final club = await clubDataSource.getClubByHostId(hostId);
      if (club == null) {
        throw Exception('No se encontró un club asociado a este anfitrión.');
      }

      // 2. Crear Membresía
      await membresiaDataSource.crearMembresia(
        usuarioId: scannedUserId,
        clubId: club.id,
      );

      if (!mounted) return;
      Navigator.pop(context); // Cerrar loading
      
      // 3. Éxito
      _showSuccess('El usuario ha sido registrado como socio del Club "${club.nombreClub}"');

    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Cerrar loading
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _showLoading() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _isScanning = true);
            },
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  void _showSuccess(String message) {
     showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¡Registro Exitoso!'),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 64),
                const SizedBox(height: 16),
                Text(message, textAlign: TextAlign.center),
            ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _isScanning = true);
            },
            child: const Text('Aceptar'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear QR de Usuario'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: _onDetect,
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF7AC142), width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                 children: [
                    // Esquinas decorativas podrían ir aquí para más estilo,
                    // por ahora el borde es suficiente como guía.
                    Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                                "Encuadra el QR aquí",
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontWeight: FontWeight.bold,
                                    shadows: const [Shadow(color: Colors.black, blurRadius: 4)]
                                ),
                            ),
                        )
                    )
                 ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
