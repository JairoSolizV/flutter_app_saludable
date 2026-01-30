import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../data/datasources/remote/membresia_remote_data_source.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Escanear Código QR"),
        backgroundColor: Colors.transparent,
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

      // 1. Necesitamos saber la membresía del usuario para este club (o la activa)
      //    Por simplificación, asumiremos que usamos la primera membresía activa del usuario que coincida con el club
      //    O buscamos la membresía asociada a ese usuario.
      
      final dataSource = Provider.of<MembresiaRemoteDataSource>(context, listen: false);
      final membresias = await dataSource.getMembresiasPorUsuario(int.parse(user.id));
      
      // Buscar si tiene membresía en ese club
      final membership = membresias.firstWhere(
        (m) => m.clubId == clubId, 
        orElse: () => throw Exception("No tienes una membresía activa en este club.")
      );

      // 2. Registrar Asistencia
      await dataSource.registrarAsistencia(
        membresiaId: membership.id,
        clubId: clubId,
      );

      if (mounted) {
         // Detener la cámara
         await cameraController.stop();
         setState(() => _isProcessing = false);
         
         // Mostrar éxito
         final shouldReload = await showDialog<bool>(
           context: context,
           barrierDismissible: false,
           builder: (context) => AlertDialog(
             title: const Text("¡Asistencia Registrada!"),
             content: Column(
               mainAxisSize: MainAxisSize.min,
               children: const [
                 Icon(LucideIcons.checkCircle, color: Colors.green, size: 50),
                 SizedBox(height: 10),
                 Text("Tu visita ha sido registrada correctamente. ¡Disfruta tu consumo!"),
               ],
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
         
         // Volver al home y recargar datos
         if (mounted) {
           context.pop(shouldReload ?? true); // Retornar resultado para que el home sepa que debe recargar
         }
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString().replaceAll('Exception: ', '')}"), backgroundColor: Colors.red),
        );
        // Retardo para permitir intentar de nuevo
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }
  
  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}
