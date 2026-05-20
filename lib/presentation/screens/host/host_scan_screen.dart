import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../providers/user_provider.dart';
import '../../../data/datasources/remote/club_remote_data_source.dart';
import '../../../data/datasources/remote/qr_remote_data_source.dart';

class HostScanScreen extends StatefulWidget {
  final int? preSocioId;
  final int? prefilledReferralId;

  const HostScanScreen({
    super.key,
    this.preSocioId,
    this.prefilledReferralId,
  });

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

    // Determinar tipo de QR
    if (code.startsWith('SOCIO:')) {
      // QR de socio - validar con backend
      await _validateSocioQR(code);
    } else if (code.startsWith('ACTIVATE:')) {
      // QR de activación - flujo original
      await _handleActivationQR(code);
    } else {
      // QR desconocido
      if (mounted) {
        _showError('Código QR no reconocido. Debe ser un QR de socio o de activación.');
        await _restartCamera();
      }
    }
  }

  Future<void> _validateSocioQR(String qrCode) async {
    // Mostrar loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      final clubDataSource = Provider.of<ClubRemoteDataSource>(context, listen: false);
      final qrDataSource = Provider.of<QRRemoteDataSource>(context, listen: false);

      // Obtener club del anfitrión
      final club = await clubDataSource.getMyClub();
      if (club == null) {
        throw Exception('No se encontró club para este anfitrión.');
      }

      // Validar QR del socio
      final validationResponse = await qrDataSource.validarSocioQR(qrCode, club.id);

      // Cerrar loading
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // Mostrar resultado
      if (!mounted) return;
      await _showSocioValidationResult(validationResponse);

      // Reiniciar cámara
      if (mounted) {
        await _restartCamera();
      }
    } catch (e) {
      // Cerrar loading
      try {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
      } catch (_) {}

      if (mounted) {
        _showError('Error al validar QR: ${e.toString().replaceAll('Exception: ', '')}');
        await _restartCamera();
      }
    }
  }

  Future<void> _showSocioValidationResult(QRValidacionResponse response) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              response.valido ? LucideIcons.checkCircle : LucideIcons.xCircle,
              color: response.valido ? Colors.green : Colors.red,
              size: 28,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                response.valido ? 'Socio Válido' : 'Socio Inválido',
                style: TextStyle(
                  color: response.valido ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (response.nombreCompleto != null) ...[
                _InfoRow('Nombre', response.nombreCompleto!),
                const SizedBox(height: 8),
              ],
              if (response.numeroSocio != null) ...[
                _InfoRow('Número de Socio', response.numeroSocio!),
                const SizedBox(height: 8),
              ],
              if (response.estado != null) ...[
                _InfoRow('Estado', response.estado!),
                const SizedBox(height: 8),
              ],
              if (response.nivelNombre != null) ...[
                _InfoRow('Nivel', response.nivelNombre!),
                const SizedBox(height: 8),
              ],
              if (response.rachaActual != null) ...[
                _InfoRow('Racha Actual', '${response.rachaActual} días'),
                const SizedBox(height: 8),
              ],
              if (response.rachaMaxima != null) ...[
                _InfoRow('Racha Máxima', '${response.rachaMaxima} días'),
                const SizedBox(height: 8),
              ],
              if (response.mensaje != null) ...[
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  response.mensaje!,
                  style: TextStyle(
                    color: response.valido ? Colors.green[700] : Colors.red[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleActivationQR(String code) async {
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      final clubDataSource = Provider.of<ClubRemoteDataSource>(context, listen: false);
      final currentUser = Provider.of<UserProvider>(context, listen: false).currentUser;
      final int hostId = int.tryParse(currentUser?.id ?? '0') ?? 0;

      print('SCAN_DEBUG: Buscando club hostId: $hostId');
      final club = await clubDataSource.getMyClub();
      
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
        'qrPayload': code,
        'clubId': club.id,
        'preSocioId': widget.preSocioId,
        'prefilledReferralId': widget.prefilledReferralId,
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
        title: const Text('Escanear QR de Socio'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2C5E1A), // Dark Green for branding
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2C5E1A)),
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
                                "Encuadra el QR del socio aquí",
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
