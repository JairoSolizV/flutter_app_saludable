import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../providers/support_provider.dart';

class SupportCenterScreen extends StatefulWidget {
  const SupportCenterScreen({super.key});

  @override
  State<SupportCenterScreen> createState() => _SupportCenterScreenState();
}

class _SupportCenterScreenState extends State<SupportCenterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  
  String _tipoSolicitud = 'Soporte Técnico';
  final _asuntoController = TextEditingController();
  final _mensajeController = TextEditingController();
  
  final List<String> _tiposSoporte = [
    'Soporte Técnico',
    'Problema en el Club',
    'Sugerencia',
    'Otro'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Cargar tickets al inicio
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupportProvider>().fetchMyTickets();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _asuntoController.dispose();
    _mensajeController.dispose();
    super.dispose();
  }

  void _submitTicket() async {
    if (_formKey.currentState!.validate()) {
      final provider = context.read<SupportProvider>();
      
      final success = await provider.createTicket(
        _tipoSolicitud,
        _asuntoController.text,
        _mensajeController.text,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Reporte enviado correctamente!')),
        );
        _asuntoController.clear();
        _mensajeController.clear();
        setState(() {
          _tipoSolicitud = 'Soporte Técnico';
        });
        // Cambiar a la pestaña de "Mis Reportes"
        _tabController.animateTo(1);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar el reporte: ${provider.error}'),
            backgroundColor: Colors.red,
          )
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Centro de Soporte', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF7AC142),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF7AC142),
          tabs: const [
            Tab(text: 'Nuevo Reporte'),
            Tab(text: 'Mis Reportes'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNewTicketForm(),
          _buildTicketHistory(),
        ],
      ),
    );
  }

  Widget _buildNewTicketForm() {
    final isLoading = context.watch<SupportProvider>().isLoading;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '¿En qué podemos ayudarte?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Describe el problema o sugerencia con detalle. Nuestro equipo lo revisará y te responderá pronto.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            
            // Tipo de Solicitud
            DropdownButtonFormField<String>(
              initialValue: _tipoSolicitud,
              decoration: const InputDecoration(
                labelText: 'Tipo de Solicitud',
                border: OutlineInputBorder(),
              ),
              items: _tiposSoporte.map((tipo) {
                return DropdownMenuItem(
                  value: tipo,
                  child: Text(tipo),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _tipoSolicitud = value);
                }
              },
            ),
            const SizedBox(height: 16),
            
            // Asunto
            TextFormField(
              controller: _asuntoController,
              decoration: const InputDecoration(
                labelText: 'Asunto (Breve resumen)',
                border: OutlineInputBorder(),
                hintText: 'Ej. No puedo completar mi pedido',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Por favor ingresa un asunto';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Mensaje
            TextFormField(
              controller: _mensajeController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Descripción detallada del mensaje',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Por favor describe el problema detalladamente';
                }
                if (value.length < 10) {
                  return 'El mensaje debe ser más largo';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),
            
            // Botón Enviar
            ElevatedButton(
              onPressed: isLoading ? null : _submitTicket,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7AC142),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Enviar Reporte',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketHistory() {
    return Consumer<SupportProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.tickets.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF7AC142)));
        }

        if (provider.error != null && provider.tickets.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.black38),
                const SizedBox(height: 16),
                Text(
                  'Error al cargar el historial: \n${provider.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => provider.fetchMyTickets(),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7AC142)),
                  child: const Text('Reintentar', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        }

        final tickets = provider.tickets;

        if (tickets.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.messageSquare, size: 64, color: Colors.black12),
                SizedBox(height: 16),
                Text(
                  'No tienes reportes de soporte creados',
                  style: TextStyle(fontSize: 16, color: Colors.black45),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: const Color(0xFF7AC142),
          onRefresh: () => provider.fetchMyTickets(),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: tickets.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final ticket = tickets[index];
              final isAbierto = ticket.estado.toUpperCase() == 'ABIERTO';
              final colorEstado = isAbierto ? Colors.orange : Colors.green;
              final Color bgEstado = isAbierto ? Colors.orange.shade50 : Colors.green.shade50;

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                    title: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text(
                            ticket.asunto,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          '${ticket.tipoSolicitud} • ${DateFormat('dd MMM yyyy, HH:mm').format(ticket.fechaCreacion)}',
                          style: const TextStyle(color: Colors.black54, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: bgEstado,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            ticket.estado,
                            style: TextStyle(
                              color: colorEstado,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    children: [
                      const Divider(height: 24),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Tu mensaje:',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          ticket.mensaje,
                          style: const TextStyle(color: Colors.black87),
                        ),
                      ),
                      
                      if (!isAbierto && ticket.respuestaAdmin != null && ticket.respuestaAdmin!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade100),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(LucideIcons.shieldCheck, size: 16, color: Colors.blue.shade700),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Respuesta de Administración:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                ticket.respuestaAdmin!,
                                style: const TextStyle(color: Colors.black87),
                              ),
                            ],
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
