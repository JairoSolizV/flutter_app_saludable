import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../data/datasources/remote/logro_remote_data_source.dart';
import '../../../../domain/entities/logro.dart';

class HostClubLogrosScreen extends StatefulWidget {
  const HostClubLogrosScreen({super.key});

  @override
  State<HostClubLogrosScreen> createState() => _HostClubLogrosScreenState();
}

class _HostClubLogrosScreenState extends State<HostClubLogrosScreen> {
  bool _isLoading = true;
  String? _error;
  List<Logro> _logros = [];

  @override
  void initState() {
    super.initState();
    _loadLogros();
  }

  Future<void> _loadLogros() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dataSource = Provider.of<LogroRemoteDataSource>(context, listen: false);
      final logros = await dataSource.getLogros();

      if (mounted) {
        setState(() {
          _logros = logros;
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

  Color _estadoColor(String? estado) {
    switch ((estado ?? '').toUpperCase()) {
      case 'APROBADO':
        return Colors.green;
      case 'PENDIENTE':
        return Colors.orange;
      case 'RECHAZADO':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _estadoLabel(String? estado) {
    switch ((estado ?? '').toUpperCase()) {
      case 'APROBADO':
        return 'Aprobado';
      case 'PENDIENTE':
        return 'Pendiente';
      case 'RECHAZADO':
        return 'Rechazado';
      default:
        return estado ?? 'Desconocido';
    }
  }

  String _tipoMetricaLabel(String? tipo) {
    switch ((tipo ?? '').toUpperCase()) {
      case 'CONSUMO': return 'Consumo';
      case 'ASISTENCIA': return 'Asistencia';
      case 'REFERIDOS': return 'Referidos';
      default: return 'General';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logros / Retos del Club'),
        backgroundColor: const Color(0xFF7AC142),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: _loadLogros,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7AC142)))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.alertCircle, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                )
              : _logros.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Text(
                          'Aún no has creado logros/retos para tu club.\nCrea uno nuevo para incentivar a tus socios.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadLogros,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _logros.length,
                        itemBuilder: (context, index) {
                          final logro = _logros[index];
                          final estadoColor = _estadoColor(logro.estadoAprobacion);

                          final isPendiente = (logro.estadoAprobacion ?? '').toUpperCase() == 'PENDIENTE';
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: isPendiente ? 4 : 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              // Borde destacado para logros pendientes
                              side: isPendiente 
                                ? BorderSide(color: estadoColor, width: 2)
                                : BorderSide.none,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          logro.nombre,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      if (logro.estadoAprobacion != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: estadoColor.withOpacity(isPendiente ? 0.2 : 0.1),
                                            borderRadius: BorderRadius.circular(12),
                                            // Borde más visible para pendientes
                                            border: isPendiente 
                                              ? Border.all(color: estadoColor, width: 1.5)
                                              : null,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (isPendiente)
                                                Icon(
                                                  LucideIcons.clock,
                                                  size: 14,
                                                  color: estadoColor,
                                                ),
                                              if (isPendiente) const SizedBox(width: 4),
                                              Text(
                                                _estadoLabel(logro.estadoAprobacion),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: estadoColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (logro.descripcion.isNotEmpty)
                                    Text(
                                      logro.descripcion,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  if (logro.requisitos.isNotEmpty) ...[
                                    Row(
                                      children: [
                                        Icon(LucideIcons.activity, size: 16, color: Colors.grey[700]),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Requisitos:',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    ...logro.requisitos.map((req) {
                                       return Padding(
                                         padding: const EdgeInsets.only(left: 22, bottom: 2),
                                         child: Text(
                                            '• ${req.cantidadEsperada} ${_tipoMetricaLabel(req.tipoMetrica)}',
                                            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                         ),
                                       );
                                    }).toList(),
                                  ],
                                  if (logro.puntosRecompensa != null) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(LucideIcons.star, size: 16, color: Colors.amber[700]),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${logro.puntosRecompensa} puntos de recompensa',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (logro.fechaInicio != null || logro.fechaFin != null) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(LucideIcons.calendarRange, size: 16, color: Colors.grey[700]),
                                        const SizedBox(width: 6),
                                        Text(
                                          _buildRangoFechas(logro),
                                          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/host/logros/new'),
        icon: const Icon(LucideIcons.plus),
        label: const Text('Crear reto/logro'),
        backgroundColor: const Color(0xFF7AC142),
      ),
    );
  }

  String _buildRangoFechas(Logro logro) {
    final inicio = logro.fechaInicio;
    final fin = logro.fechaFin;
    String format(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    if (inicio != null && fin != null) {
      return '${format(inicio)}  →  ${format(fin)}';
    } else if (inicio != null) {
      return 'Desde ${format(inicio)}';
    } else if (fin != null) {
      return 'Hasta ${format(fin)}';
    }
    return '';
  }
}


