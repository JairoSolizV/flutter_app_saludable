import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

class HostDashboardScreen extends StatelessWidget {
  const HostDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF7AC142), Color(0xFF6BB032)],
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text('Panel de Anfitrión', style: TextStyle(color: Colors.white70)),
                                Text('Club Vida Activa', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const CircleAvatar(
                              backgroundColor: Colors.white30,
                              child: Icon(LucideIcons.settings, color: Colors.white),
                            )
                          ],
                        ),
                        const SizedBox(height: 20),
                        Container(
                           padding: const EdgeInsets.all(12),
                           decoration: BoxDecoration(
                               color: Colors.white.withOpacity(0.9),
                               borderRadius: BorderRadius.circular(16)
                           ),
                           child: Row(
                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
                               children: [
                                   Column(
                                       crossAxisAlignment: CrossAxisAlignment.start,
                                       children: const [
                                           Text('Estado del Club', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                           Text('Activo y Verificado', style: TextStyle(color: Color(0xFF7AC142), fontWeight: FontWeight.bold)),
                                       ],
                                   ),
                                   Container(
                                       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                       decoration: BoxDecoration(
                                           color: Colors.green[100],
                                           borderRadius: BorderRadius.circular(20)
                                       ),
                                       child: const Text('Abierto', style: TextStyle(color: Colors.green, fontSize: 12)),
                                   )
                               ],
                           ),
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                   // QR Section
                   Container(
                       padding: const EdgeInsets.all(24),
                       decoration: BoxDecoration(
                           color: Colors.white,
                           borderRadius: BorderRadius.circular(24),
                           boxShadow: [
                               BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, 5))
                           ]
                       ),
                       child: Column(
                           children: [
                               const Text('QR del Club para Asistencia', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                               const SizedBox(height: 16),
                               Container(
                                   width: 180, height: 180,
                                   decoration: BoxDecoration(
                                       border: Border.all(color: const Color(0xFF7AC142), width: 4),
                                       borderRadius: BorderRadius.circular(16)
                                   ),
                                   child: const Center(child: Icon(LucideIcons.qrCode, size: 100, color: Color(0xFF333333))),
                               ),
                               const SizedBox(height: 12),
                               const Text('Los socios deben escanear este código', style: TextStyle(color: Colors.grey, fontSize: 12)),
                           ],
                       ),
                   ),

                   const SizedBox(height: 24),

                   // Orders Card
                   InkWell(
                       onTap: () => context.go('/host-orders'),
                       child: Container(
                           padding: const EdgeInsets.all(20),
                           decoration: BoxDecoration(
                               color: const Color(0xFF333333),
                               borderRadius: BorderRadius.circular(20),
                               boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, 5))],
                           ),
                           child: Row(
                               children: [
                                   Expanded(
                                       child: Column(
                                           crossAxisAlignment: CrossAxisAlignment.start,
                                           children: [
                                               const Text('Pedidos Recibidos', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                               const Text('Gestionar órdenes de socios', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                               const SizedBox(height: 12),
                                               Row(
                                                   children: [
                                                       _DotInfo(label: '1 Preparando', color: Colors.orange),
                                                       const SizedBox(width: 12),
                                                       _DotInfo(label: '1 Listo', color: Colors.green),
                                                   ],
                                               )
                                           ],
                                       ),
                                   ),
                                   Container(
                                       width: 40, height: 40,
                                       decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                       child: const Center(child: Text('3', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                   )
                               ],
                           ),
                       ),
                   ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DotInfo extends StatelessWidget {
    final String label;
    final Color color;
    const _DotInfo({required this.label, required this.color});

    @override
    Widget build(BuildContext context) {
        return Row(
            children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10))
            ],
        );
    }
}
