import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../data/datasources/remote/membresia_remote_data_source.dart';

class HostLogroCreateScreen extends StatefulWidget {
  const HostLogroCreateScreen({super.key});

  @override
  State<HostLogroCreateScreen> createState() => _HostLogroCreateScreenState();
}

class _HostLogroCreateScreenState extends State<HostLogroCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _metaCantidadCtrl = TextEditingController();
  final _puntosCtrl = TextEditingController();

  String _tipoMetrica = 'ASISTENCIA';
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _metaCantidadCtrl.dispose();
    _puntosCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isInicio}) async {
    final now = DateTime.now();
    final initial = isInicio ? (_fechaInicio ?? now) : (_fechaFin ?? now);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );

    if (picked != null) {
      setState(() {
        if (isInicio) {
          _fechaInicio = picked;
          if (_fechaFin != null && _fechaFin!.isBefore(_fechaInicio!)) {
            _fechaFin = _fechaInicio;
          }
        } else {
          _fechaFin = picked;
        }
      });
    }
  }

  String _formatDate(DateTime? d) {
    if (d == null) return 'Seleccionar fecha';
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_fechaInicio == null || _fechaFin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona fecha de inicio y fin del reto/logro.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final meta = int.tryParse(_metaCantidadCtrl.text.trim());
    final puntos = int.tryParse(_puntosCtrl.text.trim());

    if (meta == null || meta <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La meta debe ser un entero positivo.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (puntos == null || puntos <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Los puntos de recompensa deben ser un entero positivo.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final dataSource = Provider.of<MembresiaRemoteDataSource>(context, listen: false);

      String toYMD(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

      final fechaInicio = toYMD(_fechaInicio!);
      final fechaFin = toYMD(_fechaFin!);

      if (kDebugMode) {
        debugPrint('[DEBUG LOGROS] Enviando logro con fechas $fechaInicio - $fechaFin');
      }

      await dataSource.createClubLogro(
        nombre: _nombreCtrl.text.trim(),
        descripcion: _descripcionCtrl.text.trim(),
        fechaInicio: fechaInicio,
        fechaFin: fechaFin,
        tipoMetrica: _tipoMetrica,
        metaCantidad: meta,
        puntosRecompensa: puntos,
      );

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Logro enviado'),
          content: const Text(
            'Logro/Reto enviado al Administrador para su aprobación.\n'
            'Cuando sea aprobado, tus socios podrán comenzar a participar.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al crear logro: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Reto / Logro'),
        backgroundColor: const Color(0xFF7AC142),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Crea retos temporales para incentivar a tus socios (ej. "Ven 5 días seguidos", '
                '"Trae 2 referidos", etc.).',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Logro / Reto',
                  prefixIcon: Icon(LucideIcons.award),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'El nombre es obligatorio' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descripcionCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'La descripción es obligatoria' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(isInicio: true),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Fecha Inicio',
                          border: OutlineInputBorder(),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDate(_fechaInicio),
                              style: TextStyle(
                                color: _fechaInicio == null ? Colors.grey : Colors.black,
                              ),
                            ),
                            const Icon(LucideIcons.calendar),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(isInicio: false),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Fecha Fin',
                          border: OutlineInputBorder(),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDate(_fechaFin),
                              style: TextStyle(
                                color: _fechaFin == null ? Colors.grey : Colors.black,
                              ),
                            ),
                            const Icon(LucideIcons.calendarRange),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Tipo de Métrica',
                  border: OutlineInputBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _tipoMetrica,
                    items: const [
                      DropdownMenuItem(
                        value: 'CONSUMO',
                        child: Text('Consumo (pedidos)'),
                      ),
                      DropdownMenuItem(
                        value: 'ASISTENCIA',
                        child: Text('Asistencia (visitas)'),
                      ),
                      DropdownMenuItem(
                        value: 'REFERIDOS',
                        child: Text('Referidos'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _tipoMetrica = value);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _metaCantidadCtrl,
                decoration: const InputDecoration(
                  labelText: 'Meta (cantidad)',
                  hintText: 'Ej: 5 (asistencias, consumos o referidos)',
                  prefixIcon: Icon(LucideIcons.target),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Ingresa la meta numérica' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _puntosCtrl,
                decoration: const InputDecoration(
                  labelText: 'Puntos de recompensa',
                  hintText: 'Ej: 100',
                  prefixIcon: Icon(LucideIcons.star),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Ingresa los puntos de recompensa'
                    : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(LucideIcons.send),
                  label: Text(_isSubmitting ? 'Enviando...' : 'Enviar al Administrador'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7AC142),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


