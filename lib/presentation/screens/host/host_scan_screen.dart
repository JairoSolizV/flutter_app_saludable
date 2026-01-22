import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../../data/datasources/remote/club_remote_data_source.dart';

class HostScanScreen extends StatefulWidget {
  const HostScanScreen({super.key});

  @override
  State<HostScanScreen> createState() => _HostScanScreenState();
}

class _HostScanScreenState extends State<HostScanScreen> {
  bool _isScanning = true;
  final MobileScannerController _cameraController = MobileScannerController();

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
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
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUser = userProvider.currentUser;
    if (currentUser == null) {
      await _checkAndRestartCamera();
      _showError('No hay sesión de anfitrión activa');
      return;
    }

    final int hostId = int.tryParse(currentUser.id) ?? 0;
    
    // Detener cámara
    await _cameraController.stop();

    if (!mounted) return;

    // 1. Diálogo de confirmación
    final shouldProcess = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Registrar Nuevo Socio'),
        content: Text('Código: $code\n\n¿Activar usuario?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Continuar'),
          ),
        ],
      ),
    );

    if (shouldProcess != true) {
       await _restartCamera();
       return;
    }

    // 2. Mostrar Loading y ejecutar lógica
    // Usamos un context seguro para cerrar el dialog después
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      final clubDataSource = Provider.of<ClubRemoteDataSource>(context, listen: false);

      print('SCAN_DEBUG: Buscando club hostId: $hostId');
      final club = await clubDataSource.getClubByHostId(hostId);
      
      print('SCAN_DEBUG: Club encontrado: ${club?.nombreClub}');

      if (club == null) {
        throw Exception('No se encontró club para este anfitrión.');
      }

      // Cerrar Loading
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Force close dialog
      }

      // 3. Navegar
      if (!mounted) return;
      print('SCAN_DEBUG: Navegando a registro...');
      
      await context.push('/host-register-member', extra: {
        'qrPayload': code, // Pass raw code
        'clubId': club.id,
      });

      // Al volver
      if (mounted) {
         await _restartCamera();
      }

    } catch (e) {
      print('SCAN_DEBUG: Error: $e');
      // Asegurar cierre de loading si falló
      try {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
      } catch (_) {}

      if (mounted) {
        _showError('Error: ${e.toString().replaceAll('Exception: ', '')}');
        await _restartCamera();
      }
    }
  }

  Future<void> _restartCamera() async {
    if (mounted) {
      setState(() => _isScanning = true);
      await _cameraController.start();
    }
  }
  
  // Helper para asegurar que la cámara reinicie si falló algo antes de pararla
  Future<void> _checkAndRestartCamera() async {
     setState(() => _isScanning = true);
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
            onPressed: () async {
              Navigator.pop(context);
              // Cámara se reiniciará después de cerrar el diálogo en el flujo principal o aquí si es necesario
            },
            child: const Text('OK'),
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
            controller: _cameraController,
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
