import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../data/datasources/remote/logro_remote_data_source.dart';
import '../../../../domain/entities/logro.dart';

class HostLogroCreateScreen extends StatefulWidget {
  const HostLogroCreateScreen({super.key});

  @override
  State<HostLogroCreateScreen> createState() => _HostLogroCreateScreenState();
}

class _HostLogroCreateScreenState extends State<HostLogroCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _puntosCtrl = TextEditingController();

  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  bool _isSubmitting = false;

  final List<RequisitoLogro> _requisitos = [];
  
  // Variables temporales para el modal de añadir requisito
  String _tempTipoMetrica = 'CONSUMO';
  final _tempCantidadCtrl = TextEditingController();

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _puntosCtrl.dispose();
    _tempCantidadCtrl.dispose();
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

  void _addRequisito() {
    _tempCantidadCtrl.clear();
    _tempTipoMetrica = 'CONSUMO';
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Añadir Requisito'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _tempTipoMetrica,
                    decoration: const InputDecoration(labelText: 'Métrica', border: OutlineInputBorder()),
                    items: const [
                       DropdownMenuItem(value: 'CONSUMO', child: Text('Consumo (pedidos)')),
                       DropdownMenuItem(value: 'ASISTENCIA', child: Text('Asistencia (visitas)')),
                       DropdownMenuItem(value: 'REFERIDOS', child: Text('Referidos')),
                    ],
                    onChanged: (v) {
                       if (v != null) setModalState(() => _tempTipoMetrica = v);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _tempCantidadCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Cantidad Meta', border: OutlineInputBorder()),
                  )
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () {
                    final int val = int.tryParse(_tempCantidadCtrl.text) ?? 0;
                    if (val > 0) {
                      setState(() {
                         _requisitos.add(RequisitoLogro(tipoMetrica: _tempTipoMetrica, cantidadEsperada: val));
                      });
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Añadir'),
                )
              ],
            );
          }
        );
      }
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_fechaInicio == null || _fechaFin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona fecha de inicio y fin.'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_requisitos.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes añadir al menos un requisito al reto.'), backgroundColor: Colors.red),
      );
      return;
    }

    final puntos = int.tryParse(_puntosCtrl.text.trim());
    if (puntos == null || puntos <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Los puntos de recompensa deben ser un entero positivo.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final logroDataSource = Provider.of<LogroRemoteDataSource>(context, listen: false);

      final logro = Logro(
        id: 0,
        nombre: _nombreCtrl.text.trim(),
        descripcion: _descripcionCtrl.text.trim(),
        puntosRecompensa: puntos,
        fechaInicio: _fechaInicio,
        fechaFin: _fechaFin,
        requisitos: _requisitos,
      );

      await logroDataSource.createLogro(logro);

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Logro enviado'),
          content: const Text(
            'El Reto se ha enviado al Administrador para su aprobación.\n'
            'Tus socios podrán participar cuando sea aprobado.',
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
                'Crea retos temporales para incentivar a tus socios (ej. "Ven 5 días seguidos" + "Trae 2 referidos").',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Reto',
                  prefixIcon: Icon(LucideIcons.award),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'El nombre es obligatorio' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descripcionCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descripción detallada',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'La descripción es obligatoria' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(isInicio: true),
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Fecha Inicio', border: OutlineInputBorder()),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatDate(_fechaInicio), style: TextStyle(color: _fechaInicio == null ? Colors.grey : Colors.black)),
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
                        decoration: const InputDecoration(labelText: 'Fecha Fin', border: OutlineInputBorder()),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatDate(_fechaFin), style: TextStyle(color: _fechaFin == null ? Colors.grey : Colors.black)),
                            const Icon(LucideIcons.calendarRange),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   const Text("Requisitos del Reto", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                   IconButton(
                     onPressed: _addRequisito,
                     color: const Color(0xFF7AC142),
                     icon: const Icon(LucideIcons.plusCircle),
                   )
                ],
              ),
              const Divider(),
              if (_requisitos.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: Text("Aún no has añadido métricas/requisitos.", style: TextStyle(color: Colors.grey))),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _requisitos.length,
                  itemBuilder: (context, index) {
                    final req = _requisitos[index];
                    return Card(
                      color: Colors.green[50],
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(LucideIcons.checkSquare, color: Color(0xFF7AC142)),
                        title: Text("${req.cantidadEsperada} x ${req.tipoMetrica}"),
                        trailing: IconButton(
                           icon: const Icon(LucideIcons.trash2, color: Colors.red),
                           onPressed: () {
                              setState(() {
                                _requisitos.removeAt(index);
                              });
                           },
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _puntosCtrl,
                decoration: const InputDecoration(
                  labelText: 'Puntos de recompensa final',
                  hintText: 'Ej: 150',
                  prefixIcon: Icon(LucideIcons.star),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa los puntos de recompensa' : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                      : const Icon(LucideIcons.send),
                  label: Text(_isSubmitting ? 'Enviando...' : 'Pedir Aprobación de Reto'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7AC142),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
