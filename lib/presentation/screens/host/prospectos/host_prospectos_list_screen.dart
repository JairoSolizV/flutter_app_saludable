import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../../data/datasources/remote/club_remote_data_source.dart';
import '../../../../data/datasources/remote/prospecto_remote_data_source.dart';
import '../../../../domain/entities/prospecto.dart';

class HostProspectosListScreen extends StatefulWidget {
  const HostProspectosListScreen({super.key});

  @override
  State<HostProspectosListScreen> createState() => _HostProspectosListScreenState();
}

class _HostProspectosListScreenState extends State<HostProspectosListScreen> {
  bool _isLoading = true;
  List<Prospecto> _prospectos = [];
  String? _error;
  int? _clubId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      setState(() { _isLoading = true; _error = null; });
      final clubDs = Provider.of<ClubRemoteDataSource>(context, listen: false);
      final prospectoDs = Provider.of<ProspectoRemoteDataSource>(context, listen: false);
      final club = await clubDs.getMyClub();
      if (club == null) throw Exception('No se encontró el club del anfitrión.');
      _clubId = club.id;
      final list = await prospectoDs.getProspectos(club.id);
      if (mounted) setState(() { _prospectos = list; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceAll('Exception: ', ''); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7AC142)))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: const Color(0xFF7AC142),
                  child: _prospectos.isEmpty ? _buildEmpty() : _buildList(),
                ),
      floatingActionButton: _clubId != null
          ? FloatingActionButton.extended(
              onPressed: () async {
                await context.push('/host/prospectos/new', extra: {'clubId': _clubId!});
                _load();
              },
              backgroundColor: const Color(0xFF7AC142),
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: const Text('Nuevo Prospecto', style: TextStyle(color: Colors.white)),
            )
          : null,
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.alertCircle, size: 48, color: Colors.orange),
          const SizedBox(height: 16),
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _load,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7AC142), foregroundColor: Colors.white),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      children: const [
        SizedBox(height: 100),
        Center(
          child: Column(
            children: [
              Icon(Icons.person_search, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('No hay prospectos aún.', style: TextStyle(color: Colors.grey, fontSize: 16)),
              SizedBox(height: 8),
              Text('Pulsa "Nuevo Prospecto" para crear una ficha.', style: TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _prospectos.length,
      itemBuilder: (_, i) => _ProspectoCard(
        prospecto: _prospectos[i],
        clubId: _clubId!,
        onTap: () async {
          await context.push('/host/prospectos/${_prospectos[i].id}', extra: {'clubId': _clubId!});
          _load();
        },
      ),
    );
  }
}

class _ProspectoCard extends StatelessWidget {
  final Prospecto prospecto;
  final int clubId;
  final VoidCallback onTap;

  const _ProspectoCard({required this.prospecto, required this.clubId, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isConvertido = prospecto.estado == 'CONVERTIDO';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: InkWell(
        onTap: isConvertido ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: isConvertido ? Colors.grey.shade200 : const Color(0xFF7AC142).withOpacity(0.1),
                    child: Text(
                      prospecto.nombre.isNotEmpty ? prospecto.nombre[0].toUpperCase() : '?',
                      style: TextStyle(color: isConvertido ? Colors.grey : const Color(0xFF7AC142), fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(prospecto.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(prospecto.telefono, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ),
                  _EstadoBadge(estado: prospecto.estado),
                ],
              ),
              if (prospecto.referidoPorNombre != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(LucideIcons.userCheck, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('Referido por: ${prospecto.referidoPorNombre}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ],
              if (prospecto.misiones.isNotEmpty && !isConvertido) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Misiones: ${prospecto.misiones.where((m) => m.completada).length}/${prospecto.misiones.length}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text('${(prospecto.progresoGlobal * 100).toInt()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF7AC142))),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: prospecto.progresoGlobal,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7AC142)),
                    minHeight: 6,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EstadoBadge extends StatelessWidget {
  final String estado;
  const _EstadoBadge({required this.estado});

  @override
  Widget build(BuildContext context) {
    final isConvertido = estado == 'CONVERTIDO';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isConvertido ? Colors.blue.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isConvertido ? Colors.blue.shade200 : Colors.orange.shade200),
      ),
      child: Text(
        isConvertido ? 'Convertido' : 'En seguimiento',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isConvertido ? Colors.blue.shade700 : Colors.orange.shade700,
        ),
      ),
    );
  }
}
