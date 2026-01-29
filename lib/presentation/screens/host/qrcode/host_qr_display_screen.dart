import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:convert';

class HostQrDisplayScreen extends StatelessWidget {
  final int clubId;
  final String clubName;

  const HostQrDisplayScreen({
    super.key, 
    required this.clubId,
    required this.clubName,
  });

  @override
  Widget build(BuildContext context) {
    // Payload JSON para el QR
    final Map<String, dynamic> qrData = {
      'clubId': clubId,
      'type': 'attendance',
      'clubName': clubName, // Opcional, para UI antes de confirmar
    };
    final String qrString = jsonEncode(qrData);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Código QR de Asistencia"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Escanea para registrar asistencia",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                clubName,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 40),
              
              // Contenedor del QR
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ],
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: QrImageView(
                  data: qrString,
                  version: QrVersions.auto,
                  size: 250.0,
                  foregroundColor: const Color(0xFF7AC142),
                ),
              ),
              
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(LucideIcons.scanLine, color: Color(0xFF7AC142)),
                    SizedBox(width: 10),
                    Text("Muestra este código a tus socios", style: TextStyle(color: Color(0xFF7AC142), fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
