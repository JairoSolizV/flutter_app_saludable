import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../data/datasources/remote/sabor_remote_data_source.dart';
import '../../../../domain/entities/sabor.dart';
import '../../../../domain/entities/product.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';
import 'package:flutter_app_saludable/presentation/widgets/refreshable_scroll_view.dart';

/// Legacy: gestión de sabores por club.
/// El listado activo del anfitrión ya no navega aquí (FLUTTER-PROD-LEGACY-001).
class HostProductSaboresScreen extends StatefulWidget {
  final int clubId;
  final Product product;

  const HostProductSaboresScreen({
    super.key,
    required this.clubId,
    required this.product,
  });

  @override
  State<HostProductSaboresScreen> createState() => _HostProductSaboresScreenState();
}

class _HostProductSaboresScreenState extends State<HostProductSaboresScreen> {
  List<Sabor> _sabores = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSabores();
  }

  Future<void> _loadSabores() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final ds = Provider.of<SaborRemoteDataSource>(context, listen: false);
      final sabores = await ds.getSaboresDeProductoEnClub(widget.clubId, int.parse(widget.product.id));
      if (mounted) {
        setState(() {
          _sabores = sabores;
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

  Future<void> _toggleSabor(Sabor sabor) async {
    try {
      final ds = Provider.of<SaborRemoteDataSource>(context, listen: false);
      final updated = await ds.toggleSaborEnClub(
        widget.clubId,
        int.parse(widget.product.id),
        sabor.id,
      );

      if (mounted) {
        setState(() {
          final idx = _sabores.indexWhere((s) => s.id == updated.id);
          if (idx >= 0) {
            _sabores[idx] = updated;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cambiar sabor: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activosCount = _sabores.where((s) => s.disponible).length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Sabores'),
            Text(
              widget.product.name,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSabores,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? RefreshableScrollView(
                  onRefresh: _loadSabores,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadSabores,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : _sabores.isEmpty
                  ? RefreshableScrollView(
                      onRefresh: _loadSabores,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.icecream_outlined, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            const Text(
                              'Este producto no tiene sabores asignados.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'El administrador del Hub debe asignar sabores a este producto.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[500], fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        // Header con resumen
                        Container(
                          padding: const EdgeInsets.all(16),
                          color: Colors.grey[50],
                          child: Row(
                            children: [
                              Icon(Icons.icecream, color: AppTheme.primaryColor),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Activa los sabores que ofreces en tu club para este producto.',
                                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: activosCount > 0 ? Colors.green.shade50 : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: activosCount > 0 ? Colors.green : Colors.grey,
                                  ),
                                ),
                                child: Text(
                                  '$activosCount/${_sabores.length}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: activosCount > 0 ? Colors.green.shade800 : Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Lista de sabores
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _loadSabores,
                            color: AppTheme.primaryColor,
                            child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _sabores.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final sabor = _sabores[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: sabor.disponible
                                      ? AppTheme.primaryColor.withOpacity(0.1)
                                      : Colors.grey.shade100,
                                  child: Icon(
                                    Icons.icecream_outlined,
                                    color: sabor.disponible ? AppTheme.primaryColor : Colors.grey,
                                  ),
                                ),
                                title: Text(
                                  sabor.nombre,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: sabor.disponible ? Colors.black : Colors.grey,
                                  ),
                                ),
                                subtitle: Text(
                                  sabor.disponible ? 'Disponible' : 'No disponible',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: sabor.disponible ? Colors.green : Colors.grey,
                                  ),
                                ),
                                trailing: Switch(
                                  activeColor: AppTheme.primaryColor,
                                  value: sabor.disponible,
                                  onChanged: (_) => _toggleSabor(sabor),
                                ),
                              );
                            },
                          ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}
