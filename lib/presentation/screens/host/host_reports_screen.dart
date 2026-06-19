import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/datasources/remote/club_remote_data_source.dart';
import '../../../data/datasources/remote/resumen_mensual_report_data_source.dart';
import '../../../data/datasources/remote/ventas_diarias_report_data_source.dart';
import '../../../domain/entities/resumen_mensual_ventas.dart';
import '../../../domain/entities/ventas_diarias_reporte.dart';
import '../../widgets/resumen_mensual_widgets.dart';
import '../../widgets/ventas_diarias_table.dart';

/// Reportes del anfitrión: registro diario detallado + resumen mensual (descarga).
class HostReportsScreen extends StatefulWidget {
  const HostReportsScreen({super.key});

  @override
  State<HostReportsScreen> createState() => _HostReportsScreenState();
}

class _HostReportsScreenState extends State<HostReportsScreen>
    with SingleTickerProviderStateMixin {
  static const Color _green = AppTheme.primaryColor;
  static const Color _greenDark = Color(0xFF5A9A32);

  late TabController _tabController;

  int? _clubId;
  bool _cargandoClub = true;
  String? _errorClub;

  // Pestaña día
  DateTime _fechaDia = DateTime.now();
  VentasDiariasReporte? _reporteDia;
  bool _cargandoDia = false;
  String? _errorDia;
  bool _descargandoDia = false;

  // Pestaña resumen mensual
  late DateTime _mesSeleccionado;
  ResumenMensualVentas? _reporteMensual;
  bool _cargandoMes = false;
  String? _errorMes;
  bool _descargandoMes = false;

  static final _moneda = NumberFormat('#,##0.00', 'es_BO');
  static final _fechaCorta = DateFormat('dd/MM/yyyy');

  static const _nombresMes = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];

  String _formatMesAnio(DateTime d) => '${_nombresMes[d.month - 1]} ${d.year}';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _mesSeleccionado = DateTime(now.year, now.month);
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _cargarClub();
  }

  void _onTabChanged() {
    if (_tabController.index == 1 &&
        !_tabController.indexIsChanging &&
        _clubId != null &&
        _reporteMensual == null &&
        !_cargandoMes) {
      _cargarReporteMensual();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
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
      if (club != null) {
        await _cargarReporteDia();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargandoClub = false;
        _errorClub = 'No se pudo obtener tu club. Intenta de nuevo.';
      });
    }
  }

  Future<void> _cargarReporteDia() async {
    final clubId = _clubId;
    if (clubId == null) return;

    setState(() {
      _cargandoDia = true;
      _errorDia = null;
    });
    try {
      final ds = Provider.of<VentasDiariasReportDataSource>(context, listen: false);
      final reporte = await ds.obtenerReporte(clubId: clubId, fecha: _fechaDia);
      if (!mounted) return;
      setState(() {
        _reporteDia = reporte;
        _cargandoDia = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _cargandoDia = false;
        _errorDia = e.message ?? 'Error al cargar el reporte del día.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargandoDia = false;
        _errorDia = 'Error inesperado: $e';
      });
    }
  }

  Future<void> _elegirFechaDia() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaDia,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
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
    setState(() => _fechaDia = picked);
    await _cargarReporteDia();
  }

  void _irAHoy() {
    setState(() => _fechaDia = DateTime.now());
    _cargarReporteDia();
  }

  Future<void> _cargarReporteMensual() async {
    final clubId = _clubId;
    if (clubId == null) return;

    setState(() {
      _cargandoMes = true;
      _errorMes = null;
    });
    try {
      final ds = Provider.of<ResumenMensualReportDataSource>(context, listen: false);
      final reporte = await ds.obtenerReporte(
        clubId: clubId,
        anio: _mesSeleccionado.year,
        mes: _mesSeleccionado.month,
      );
      if (!mounted) return;
      setState(() {
        _reporteMensual = reporte;
        _cargandoMes = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _cargandoMes = false;
        _errorMes = e.message ?? 'Error al cargar el resumen mensual.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargandoMes = false;
        _errorMes = 'Error inesperado: $e';
      });
    }
  }

  Future<void> _elegirMes() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _mesSeleccionado,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Seleccionar mes',
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
      _mesSeleccionado = DateTime(picked.year, picked.month);
      _reporteMensual = null;
    });
    await _cargarReporteMensual();
  }

  void _irAMesActual() {
    final now = DateTime.now();
    setState(() {
      _mesSeleccionado = DateTime(now.year, now.month);
      _reporteMensual = null;
    });
    _cargarReporteMensual();
  }

  Future<void> _descargarMensual(String formato) async {
    final clubId = _clubId;
    if (clubId == null) return;

    setState(() => _descargandoMes = true);
    try {
      final ds = Provider.of<ResumenMensualReportDataSource>(context, listen: false);
      final bytes = await ds.descargarReporte(
        clubId: clubId,
        anio: _mesSeleccionado.year,
        mes: _mesSeleccionado.month,
        formato: formato,
      );
      final ext = formato == 'EXCEL' ? 'xlsx' : 'pdf';
      await _guardarYAbrir(
        bytes: bytes,
        nombre: 'resumen_mensual_club${clubId}_${_mesSeleccionado.year}-${_mesSeleccionado.month.toString().padLeft(2, '0')}.$ext',
      );
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Error al descargar')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _descargandoMes = false);
    }
  }

  Future<void> _descargarDia(String formato) async {
    final clubId = _clubId;
    if (clubId == null) return;

    setState(() => _descargandoDia = true);
    try {
      final ds = Provider.of<VentasDiariasReportDataSource>(context, listen: false);
      final bytes = await ds.descargarReporte(
        clubId: clubId,
        fecha: _fechaDia,
        formato: formato,
      );
      await _guardarYAbrir(
        bytes: bytes,
        nombre: 'registro_ventas_club${clubId}_${_fmt(_fechaDia)}.${formato == 'EXCEL' ? 'xlsx' : 'pdf'}',
      );
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Error al descargar')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _descargandoDia = false);
    }
  }

  Future<void> _guardarYAbrir({required List<int> bytes, required String nombre}) async {
    final dir = await getApplicationDocumentsDirectory();
    final ruta = p.join(dir.path, nombre);
    await File(ruta).writeAsBytes(bytes, flush: true);
    if (!mounted) return;
    final result = await OpenFile.open(ruta);
    if (result.type != ResultType.done && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Archivo guardado. ${result.message}')),
      );
    }
  }

  String _fmt(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  bool get _descargando => _descargandoDia || _descargandoMes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F4),
      appBar: AppBar(
        title: const Text(
          'Reportes',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: _green,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Día detallado'),
            Tab(text: 'Resumen mensual'),
          ],
        ),
      ),
      body: Stack(
        children: [
          if (_cargandoClub)
            const Center(child: CircularProgressIndicator(color: _green))
          else if (_errorClub != null)
            RefreshIndicator(
              onRefresh: _cargarClub,
              color: _green,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [_MensajeTarjeta(texto: _errorClub!, esError: true)],
              ),
            )
          else
            TabBarView(
              controller: _tabController,
              children: [
                _buildTabDia(),
                _buildTabResumen(),
              ],
            ),
          if (_descargando) _OverlayCarga(),
        ],
      ),
    );
  }

  Widget _buildTabDia() {
    return RefreshIndicator(
      onRefresh: _cargarReporteDia,
      color: _green,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          _FilaSelectorFecha(
            etiqueta: _fechaCorta.format(_fechaDia),
            onElegir: _elegirFechaDia,
            onHoy: _irAHoy,
          ),
          const SizedBox(height: 16),
          if (_cargandoDia)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator(color: _green)),
            )
          else if (_errorDia != null)
            _MensajeTarjeta(texto: _errorDia!, esError: true)
          else if (_reporteDia != null) ...[
            _KpisDia(resumen: _reporteDia!.resumen, moneda: _moneda),
            const SizedBox(height: 16),
            _TarjetaTabla(
              child: VentasDiariasTable(filas: _reporteDia!.filas),
            ),
            const SizedBox(height: 20),
            _BotonDescarga(
              titulo: 'Descargar Excel del día',
              subtitulo: 'Registro fila por fila como la hoja de papel',
              icono: LucideIcons.sheet,
              colorFondo: _green,
              colorTexto: Colors.white,
              onTap: _descargandoDia ? null : () => _descargarDia('EXCEL'),
            ),
            const SizedBox(height: 12),
            _BotonDescarga(
              titulo: 'Descargar PDF del día',
              subtitulo: 'Mismo registro en formato documento',
              icono: LucideIcons.fileText,
              colorFondo: Colors.white,
              colorTexto: _greenDark,
              bordeVerde: true,
              onTap: _descargandoDia ? null : () => _descargarDia('PDF'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabResumen() {
    return RefreshIndicator(
      onRefresh: _cargarReporteMensual,
      color: _green,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          _FilaSelectorMes(
            etiqueta: _formatMesAnio(_mesSeleccionado),
            onElegir: _elegirMes,
            onMesActual: _irAMesActual,
          ),
          const SizedBox(height: 16),
          if (_cargandoMes)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator(color: _green)),
            )
          else if (_errorMes != null)
            _MensajeTarjeta(texto: _errorMes!, esError: true)
          else if (_reporteMensual != null) ...[
            _KpisMes(resumen: _reporteMensual!.resumen, moneda: _moneda),
            const SizedBox(height: 16),
            _SeccionTarjeta(
              titulo: 'Ventas por día',
              icono: LucideIcons.calendarDays,
              child: VentasPorDiaMesTable(filas: _reporteMensual!.ventasPorDia),
            ),
            const SizedBox(height: 16),
            _SeccionTarjeta(
              titulo: 'Top productos del mes',
              icono: LucideIcons.trophy,
              child: TopProductosMesList(productos: _reporteMensual!.topProductos),
            ),
            const SizedBox(height: 20),
            _BotonDescarga(
              titulo: 'Descargar PDF del mes',
              subtitulo: 'Resumen con totales, desglose diario y ranking',
              icono: LucideIcons.fileText,
              colorFondo: _green,
              colorTexto: Colors.white,
              onTap: _descargandoMes ? null : () => _descargarMensual('PDF'),
            ),
            const SizedBox(height: 12),
            _BotonDescarga(
              titulo: 'Descargar Excel del mes',
              subtitulo: 'Hojas: Resumen, Por día, Top productos',
              icono: LucideIcons.sheet,
              colorFondo: Colors.white,
              colorTexto: _greenDark,
              bordeVerde: true,
              onTap: _descargandoMes ? null : () => _descargarMensual('EXCEL'),
            ),
          ],
        ],
      ),
    );
  }
}

class _KpisDia extends StatelessWidget {
  final ResumenDiaVentas resumen;
  final NumberFormat moneda;

  const _KpisDia({required this.resumen, required this.moneda});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _KpiChip(icon: LucideIcons.shoppingBag, label: '${resumen.totalVentas} ventas'),
              _KpiChip(icon: LucideIcons.banknote, label: 'Bs. ${moneda.format(resumen.totalIngresosBs)}'),
              _KpiChip(icon: LucideIcons.userPlus, label: '${resumen.conteoNuevos} N'),
              _KpiChip(icon: LucideIcons.users, label: '${resumen.conteoReferidos} R'),
            ],
          ),
          if (resumen.rankingProductos.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Top productos del día', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
            const SizedBox(height: 6),
            ...resumen.rankingProductos.take(5).map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(r.nombre, style: TextStyle(fontSize: 13, color: Colors.grey.shade700))),
                    Text('${r.cantidad}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _KpisMes extends StatelessWidget {
  final ResumenMesKpi resumen;
  final NumberFormat moneda;

  const _KpisMes({required this.resumen, required this.moneda});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _KpiChip(icon: LucideIcons.shoppingBag, label: '${resumen.totalVentas} ventas'),
          _KpiChip(icon: LucideIcons.banknote, label: 'Bs. ${moneda.format(resumen.totalIngresosBs)} ingresos'),
        ],
      ),
    );
  }
}

class _KpiChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _KpiChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF5A9A32)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}

class _FilaSelectorMes extends StatelessWidget {
  final String etiqueta;
  final VoidCallback onElegir;
  final VoidCallback onMesActual;

  const _FilaSelectorMes({
    required this.etiqueta,
    required this.onElegir,
    required this.onMesActual,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: onElegir,
              borderRadius: BorderRadius.circular(14),
              child: Ink(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.calendarRange, color: Color(0xFF5A9A32)),
                    const SizedBox(width: 10),
                    Text('Mes: $etiqueta', style: const TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Icon(Icons.expand_more_rounded, color: Colors.grey.shade500),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        TextButton(
          onPressed: onMesActual,
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.primaryColor,
            backgroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('Actual', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _FilaSelectorFecha extends StatelessWidget {
  final String etiqueta;
  final VoidCallback onElegir;
  final VoidCallback onHoy;

  const _FilaSelectorFecha({
    required this.etiqueta,
    required this.onElegir,
    required this.onHoy,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: onElegir,
              borderRadius: BorderRadius.circular(14),
              child: Ink(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.calendarDays, color: Color(0xFF5A9A32)),
                    const SizedBox(width: 10),
                    Text('Fecha: $etiqueta', style: const TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Icon(Icons.expand_more_rounded, color: Colors.grey.shade500),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        TextButton(
          onPressed: onHoy,
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.primaryColor,
            backgroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('Hoy', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _SeccionTarjeta extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final Widget child;

  const _SeccionTarjeta({
    required this.titulo,
    required this.icono,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Icon(icono, size: 20, color: const Color(0xFF5A9A32)),
                const SizedBox(width: 8),
                Text(
                  titulo,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Colors.grey.shade900,
                  ),
                ),
              ],
            ),
          ),
          child,
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _TarjetaTabla extends StatelessWidget {
  final Widget child;

  const _TarjetaTabla({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _OverlayCarga extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.25),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppTheme.primaryColor, strokeWidth: 3),
              SizedBox(height: 16),
              Text(
                'Generando archivo…',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
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
