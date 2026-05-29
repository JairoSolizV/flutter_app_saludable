import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';
import '../../../../data/datasources/remote/membresia_remote_data_source.dart';
import '../../../../domain/entities/arbol_referidos.dart';

class HostReferralTreeScreen extends StatefulWidget {
  final int membresiaId;
  final String memberName;

  const HostReferralTreeScreen({
    super.key,
    required this.membresiaId,
    required this.memberName,
  });

  @override
  State<HostReferralTreeScreen> createState() => _HostReferralTreeScreenState();
}

class _HostReferralTreeScreenState extends State<HostReferralTreeScreen> {
  ArbolReferidos? _arbol;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarArbol(widget.membresiaId);
  }

  Future<void> _cargarArbol(int membresiaId) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ds = Provider.of<MembresiaRemoteDataSource>(context, listen: false);
      final data = await ds.getArbolReferidos(membresiaId);
      setState(() {
        _arbol = data;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _navegarANodo(ArbolReferidos nodo) {
    // Navegar de forma recursiva a la misma pantalla con el nuevo nodo raíz
    context.push(
      '/host/members/${nodo.membresiaId}/referral-tree',
      extra: {'memberName': nodo.nombreCompleto},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Red de ${widget.memberName}'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          'Error: $_error',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => _cargarArbol(widget.membresiaId),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : _arbol == null
                  ? const Center(child: Text('Sin datos de red', style: TextStyle(color: Colors.grey)))
                  : RefreshIndicator(
                      onRefresh: () => _cargarArbol(widget.membresiaId),
                      color: AppTheme.primaryColor,
                      child: _ReferralTreeView(
                        arbol: _arbol!,
                        onNodoTap: _navegarANodo,
                      ),
                    ),
    );
  }
}

class _ReferralTreeView extends StatelessWidget {
  final ArbolReferidos arbol;
  final void Function(ArbolReferidos) onNodoTap;

  const _ReferralTreeView({
    required this.arbol,
    required this.onNodoTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      children: [
        _NodoWidget(nodo: arbol, nivel: 0, onTap: onNodoTap),
      ],
    );
  }
}

class _NodoWidget extends StatefulWidget {
  final ArbolReferidos nodo;
  final int nivel;
  final void Function(ArbolReferidos) onTap;

  const _NodoWidget({
    required this.nodo,
    required this.nivel,
    required this.onTap,
  });

  @override
  State<_NodoWidget> createState() => _NodoWidgetState();
}

class _NodoWidgetState extends State<_NodoWidget> {
  bool _expandido = false;

  @override
  void initState() {
    super.initState();
    // Expandir automáticamente el primer nivel de hijos
    _expandido = widget.nivel < 1;
  }

  @override
  Widget build(BuildContext context) {
    final tieneHijos = widget.nodo.referidos.isNotEmpty;
    final colores = [
      AppTheme.primaryColor, // Verde (raíz actual)
      Colors.indigo,
      Colors.purple,
      Colors.pink,
      Colors.orange,
      Colors.teal,
    ];
    final color = colores[widget.nivel.clamp(0, colores.length - 1)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Línea conectora izquierda
        if (widget.nivel > 0)
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Container(
              width: 2,
              height: 16,
              color: Colors.grey[300],
            ),
          ),
        // Tarjeta del nodo
        Card(
          elevation: widget.nivel == 0 ? 3 : 1,
          margin: EdgeInsets.only(left: widget.nivel * 16.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: color.withOpacity(0.3), width: widget.nivel == 0 ? 1.5 : 1),
          ),
          color: widget.nivel == 0 ? color.withOpacity(0.05) : Colors.white,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => widget.onTap(widget.nodo),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: color.withOpacity(0.1),
                child: Text(
                  widget.nodo.nombreCompleto.isNotEmpty
                      ? widget.nodo.nombreCompleto[0].toUpperCase()
                      : '?',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(
                widget.nodo.nombreCompleto,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Text('${widget.nodo.numeroSocio} · ${widget.nodo.estado}'),
                  if (widget.nodo.clubNombre != null && widget.nodo.clubNombre!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Club: ${widget.nodo.clubNombre}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${widget.nodo.puntosAcumulados} pts',
                        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      if (tieneHijos)
                        Text(
                          '${widget.nodo.referidos.length} ref.',
                          style: TextStyle(color: Colors.grey[500], fontSize: 11),
                        ),
                    ],
                  ),
                  if (tieneHijos) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(_expandido ? Icons.expand_less : Icons.expand_more),
                      onPressed: () => setState(() => _expandido = !_expandido),
                      color: color,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        // Hijos expandibles
        if (_expandido && tieneHijos)
          ...widget.nodo.referidos.map((hijo) => _NodoWidget(
                nodo: hijo,
                nivel: widget.nivel + 1,
                onTap: widget.onTap,
              )),
      ],
    );
  }
}
