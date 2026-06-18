import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../../data/datasources/remote/evento_remote_data_source.dart';
import '../../../domain/entities/evento.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';
import 'package:flutter_app_saludable/presentation/widgets/refreshable_scroll_view.dart';

class EventsListScreen extends StatefulWidget {
  const EventsListScreen({super.key});

  @override
  State<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends State<EventsListScreen> {
  bool _isLoading = true;
  List<Evento> _allEventos = [];
  List<Evento> _eventosFuturos = [];
  String? _error;
  bool _localeInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeLocale();
  }

  Future<void> _initializeLocale() async {
    try {
      await initializeDateFormatting('es', null);
      if (mounted) {
        setState(() {
          _localeInitialized = true;
        });
        _loadEventos();
      }
    } catch (e) {
      // Si falla la inicialización, usar formato sin locale
      if (mounted) {
        setState(() {
          _localeInitialized = false;
        });
        _loadEventos();
      }
    }
  }

  Future<void> _loadEventos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final eventoDataSource = Provider.of<EventoRemoteDataSource>(context, listen: false);
      final eventos = await eventoDataSource.getEventos();
      
      final ahora = DateTime.now();
      
      final eventosFuturos = eventos.where((evento) {
        return evento.fechaEvento.isAfter(ahora);
      }).toList();
      
      // Ordenar por fecha (más cercanos primero)
      eventosFuturos.sort((a, b) => a.fechaEvento.compareTo(b.fechaEvento));
      
      if (mounted) {
        setState(() {
          _allEventos = eventos;
          _eventosFuturos = eventosFuturos;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Eventos Programados',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : _eventosFuturos.isEmpty
                  ? _buildEmptyView()
                  : _buildEventosList(),
    );
  }

  Widget _buildErrorView() {
    return RefreshableScrollView(
      onRefresh: _loadEventos,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.alertCircle,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Error al cargar eventos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Error desconocido',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadEventos,
              icon: const Icon(LucideIcons.refreshCw),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return RefreshableScrollView(
      onRefresh: _loadEventos,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.calendarX,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No hay eventos programados',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Los eventos futuros aparecerán aquí',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventosList() {
    return RefreshIndicator(
      onRefresh: _loadEventos,
      color: AppTheme.primaryColor,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _eventosFuturos.length,
        itemBuilder: (context, index) {
          final evento = _eventosFuturos[index];
          return _buildEventoCard(evento);
        },
      ),
    );
  }

  Widget _buildEventoCard(Evento evento) {
    // Formatear fecha de forma segura
    String fechaFormateada;
    try {
      if (_localeInitialized) {
        fechaFormateada = DateFormat('EEEE, d \'de\' MMMM \'de\' yyyy', 'es')
            .format(evento.fechaEvento);
      } else {
        // Fallback: formato simple sin locale
        fechaFormateada = DateFormat('EEEE, d \'de\' MMMM \'de\' yyyy')
            .format(evento.fechaEvento);
      }
    } catch (e) {
      // Si falla, usar formato básico
      fechaFormateada = DateFormat('dd/MM/yyyy').format(evento.fechaEvento);
    }
    final esHoy = DateTime.now().year == evento.fechaEvento.year &&
        DateTime.now().month == evento.fechaEvento.month &&
        DateTime.now().day == evento.fechaEvento.day;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showEventoDetails(evento),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      LucideIcons.calendar,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          evento.nombre,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C5E1A),
                          ),
                        ),
                        if (evento.clubNombre != null || evento.hubNombre != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            evento.clubNombre ?? evento.hubNombre ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (esHoy)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'HOY',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    LucideIcons.calendar,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    fechaFormateada,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (evento.descripcion.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  evento.descripcion,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showEventoDetails(Evento evento) {
    // Formatear fecha de forma segura
    String fechaFormateada;
    try {
      if (_localeInitialized) {
        fechaFormateada = DateFormat('EEEE, d \'de\' MMMM \'de\' yyyy', 'es')
            .format(evento.fechaEvento);
      } else {
        fechaFormateada = DateFormat('EEEE, d \'de\' MMMM \'de\' yyyy')
            .format(evento.fechaEvento);
      }
    } catch (e) {
      fechaFormateada = DateFormat('dd/MM/yyyy').format(evento.fechaEvento);
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                LucideIcons.calendar,
                color: AppTheme.primaryColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                evento.nombre,
                style: const TextStyle(
                  fontSize: 18,
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
              if (evento.clubNombre != null || evento.hubNombre != null) ...[
                _buildDetailRow(
                  LucideIcons.mapPin,
                  'Ubicación',
                  evento.clubNombre ?? evento.hubNombre ?? '',
                ),
                const SizedBox(height: 12),
              ],
              _buildDetailRow(
                LucideIcons.calendar,
                'Fecha',
                fechaFormateada,
              ),
              if (evento.descripcion.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Descripción',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  evento.descripcion,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cerrar',
              style: TextStyle(color: AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

