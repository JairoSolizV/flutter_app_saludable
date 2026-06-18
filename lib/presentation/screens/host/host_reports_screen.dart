import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../../data/datasources/remote/club_remote_data_source.dart';
import '../../../data/datasources/remote/report_remote_data_source.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';

/// Pantalla minimalista: filtros por rango y descarga PDF / Excel.
class HostReportsScreen extends StatefulWidget {
  const HostReportsScreen({super.key});

  @override
  State<HostReportsScreen> createState() => _HostReportsScreenState();
}

class _HostReportsScreenState extends State<HostReportsScreen> {
  static const Color _green = AppTheme.primaryColor;
  static const Color _greenDark = Color(0xFF5A9A32);

  DateTime? _inicio;
  DateTime? _fin;
  int? _clubId;
  bool _cargandoClub = true;
  bool _descargando = false;
  String? _errorClub;

  @override
  void initState() {
    super.initState();
    _cargarClub();
  }

  Future<void> _cargarClub() async {
    setState(() {
      _cargandoClub = true;
      _errorClub = null;
    });
    try {
      final ds = Provider.of<ClubRemoteDataSource>(context, listen: false);
      final club = await ds.getMyClub();
      if (!mounted) return;
      setState(() {
        _clubId = club?.id;
        _cargandoClub = false;
        if (club == null) {
          _errorClub = 'No hay un club asociado a tu cuenta de anfitrión.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargandoClub = false;
        _errorClub = 'No se pudo obtener tu club. Intenta de nuevo.';
      });
    }
  }

  Future<void> _elegirFecha({required bool esInicio}) async {
    final inicial = esInicio ? (_inicio ?? DateTime.now()) : (_fin ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: _green, onPrimary: Colors.white),
          ),
          child: child!,
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (esInicio) {
        _inicio = picked;
        if (_fin != null && _fin!.isBefore(_inicio!)) {
          _fin = _inicio;
        }
      } else {
        _fin = picked;
        if (_inicio != null && _inicio!.isAfter(_fin!)) {
          _inicio = _fin;
        }
      }
    });
  }

  bool _fechasListas() => _inicio != null && _fin != null;

  Future<void> _descargar(String formato) async {
    if (!_fechasListas()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona fecha de inicio y fecha de fin.')),
      );
      return;
    }
    final clubId = _clubId;
    if (clubId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorClub ?? 'Club no disponible.')),
      );
      return;
    }

    setState(() => _descargando = true);
    try {
      final reportDs = Provider.of<ReportRemoteDataSource>(context, listen: false);
      final bytes = await reportDs.descargarReporte(
        clubId: clubId,
        fechaInicio: _inicio!,
        fechaFin: _fin!,
        formato: formato,
      );

      final dir = await getApplicationDocumentsDirectory();
      final ext = formato == 'EXCEL' ? 'xlsx' : 'pdf';
      final nombre = 'reporte_gestion_club${clubId}_${_fmt(_inicio!)}_${_fmt(_fin!)}.$ext';
      final ruta = p.join(dir.path, nombre);
      final file = File(ruta);
      await file.writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      final result = await OpenFile.open(ruta);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Archivo guardado. ${result.message}')),
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.message ?? e.error?.toString() ?? 'Error de red';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar o abrir el archivo: $e')),
      );
    } finally {
      if (mounted) setState(() => _descargando = false);
    }
  }

  String _fmt(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  String _etiquetaFecha(DateTime? d) =>
      d == null ? 'Seleccionar' : DateFormat('dd/MM/yyyy').format(d);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F4),
      appBar: AppBar(
        title: const Text('Estadísticas y reportes'),
        backgroundColor: _green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _cargarClub,
            color: _green,
            child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_cargandoClub)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(color: _green),
                    ),
                  )
                else if (_errorClub != null)
                  _MensajeTarjeta(texto: _errorClub!, esError: true)
                else ...[
                  Text(
                    'Exporta el reporte de gestión de tu club en el rango elegido.',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 14, height: 1.35),
                  ),
                  const SizedBox(height: 20),
                  _TarjetaFiltros(
                    inicio: _inicio,
                    fin: _fin,
                    etiquetaInicio: _etiquetaFecha(_inicio),
                    etiquetaFin: _etiquetaFecha(_fin),
                    onInicio: () => _elegirFecha(esInicio: true),
                    onFin: () => _elegirFecha(esInicio: false),
                  ),
                  const SizedBox(height: 24),
                  _BotonDescarga(
                    titulo: 'Descargar reporte en PDF',
                    subtitulo: 'Documento listo para compartir o imprimir',
                    icono: LucideIcons.fileText,
                    colorFondo: _green,
                    colorTexto: Colors.white,
                    onTap: _descargando ? null : () => _descargar('PDF'),
                  ),
                  const SizedBox(height: 14),
                  _BotonDescarga(
                    titulo: 'Descargar reporte en Excel',
                    subtitulo: 'Hoja de cálculo para análisis detallado',
                    icono: LucideIcons.sheet,
                    colorFondo: Colors.white,
                    colorTexto: _greenDark,
                    bordeVerde: true,
                    onTap: _descargando ? null : () => _descargar('EXCEL'),
                  ),
                ],
              ],
            ),
          ),
          ),
          if (_descargando)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.25),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: _green, strokeWidth: 3),
                      SizedBox(height: 16),
                      Text(
                        'Generando archivo…',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MensajeTarjeta extends StatelessWidget {
  final String texto;
  final bool esError;

  const _MensajeTarjeta({required this.texto, this.esError = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: esError ? Colors.red.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: esError ? Colors.red.shade200 : Colors.blue.shade100),
      ),
      child: Text(texto, style: TextStyle(color: esError ? Colors.red.shade900 : Colors.blue.shade900)),
    );
  }
}

class _TarjetaFiltros extends StatelessWidget {
  final DateTime? inicio;
  final DateTime? fin;
  final String etiquetaInicio;
  final String etiquetaFin;
  final VoidCallback onInicio;
  final VoidCallback onFin;

  const _TarjetaFiltros({
    required this.inicio,
    required this.fin,
    required this.etiquetaInicio,
    required this.etiquetaFin,
    required this.onInicio,
    required this.onFin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.calendarRange, color: Colors.green.shade700, size: 22),
              const SizedBox(width: 8),
              Text(
                'Rango de fechas',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text('Fecha de inicio', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 6),
          _SelectorFecha(etiqueta: etiquetaInicio, tieneValor: inicio != null, onTap: onInicio),
          const SizedBox(height: 16),
          Text('Fecha de fin', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 6),
          _SelectorFecha(etiqueta: etiquetaFin, tieneValor: fin != null, onTap: onFin),
        ],
      ),
    );
  }
}

class _SelectorFecha extends StatelessWidget {
  final String etiqueta;
  final bool tieneValor;
  final VoidCallback onTap;

  const _SelectorFecha({
    required this.etiqueta,
    required this.tieneValor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tieneValor ? AppTheme.primaryColor.withValues(alpha: 0.5) : Colors.grey.shade300),
            color: tieneValor ? AppTheme.primaryColor.withValues(alpha: 0.06) : Colors.grey.shade50,
          ),
          child: Row(
            children: [
              Icon(LucideIcons.calendarDays, size: 20, color: tieneValor ? const Color(0xFF5A9A32) : Colors.grey),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  etiqueta,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: tieneValor ? FontWeight.w600 : FontWeight.w400,
                    color: tieneValor ? Colors.grey.shade900 : Colors.grey.shade500,
                  ),
                ),
              ),
              Icon(Icons.expand_more_rounded, color: Colors.grey.shade500),
            ],
          ),
        ),
      ),
    );
  }
}

class _BotonDescarga extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final IconData icono;
  final Color colorFondo;
  final Color colorTexto;
  final bool bordeVerde;
  final VoidCallback? onTap;

  const _BotonDescarga({
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.colorFondo,
    required this.colorTexto,
    this.bordeVerde = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          decoration: BoxDecoration(
            color: colorFondo,
            borderRadius: BorderRadius.circular(20),
            border: bordeVerde ? Border.all(color: AppTheme.primaryColor, width: 2) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: bordeVerde ? 0.04 : 0.12),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: bordeVerde ? AppTheme.primaryColor.withValues(alpha: 0.12) : Colors.white24,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icono, size: 28, color: bordeVerde ? const Color(0xFF5A9A32) : Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colorTexto)),
                    const SizedBox(height: 4),
                    Text(
                      subtitulo,
                      style: TextStyle(fontSize: 12, color: bordeVerde ? Colors.grey.shade600 : Colors.white70),
                    ),
                  ],
                ),
              ),
              Icon(LucideIcons.download, color: colorTexto.withValues(alpha: bordeVerde ? 1 : 0.9)),
            ],
          ),
        ),
      ),
    );
  }
}
