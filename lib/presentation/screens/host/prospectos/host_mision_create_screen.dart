import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../data/datasources/remote/prospecto_remote_data_source.dart';

class HostMisionCreateScreen extends StatefulWidget {
  final int prospectoId;

  const HostMisionCreateScreen({super.key, required this.prospectoId});

  @override
  State<HostMisionCreateScreen> createState() => _HostMisionCreateScreenState();
}

class _HostMisionCreateScreenState extends State<HostMisionCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _metaCtrl = TextEditingController();
  DateTime? _fechaLimite;
  bool _isLoading = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _metaCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _fechaLimite = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final ds = Provider.of<ProspectoRemoteDataSource>(context, listen: false);
      await ds.crearMision(
        prospectoId: widget.prospectoId,
        nombre: _nombreCtrl.text.trim(),
        descripcion: _descripcionCtrl.text.trim().isEmpty ? null : _descripcionCtrl.text.trim(),
        metaCantidad: int.parse(_metaCtrl.text.trim()),
        fechaLimite: _fechaLimite != null ? DateFormat('yyyy-MM-dd').format(_fechaLimite!) : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Misión creada'), backgroundColor: Colors.green),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva Misión'),
        backgroundColor: const Color(0xFF7AC142),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la misión',
                  hintText: 'Ej: Consumir 3 combos en una semana',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.flag_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'El nombre es requerido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descripcionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Descripción (Opcional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _metaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Meta (cantidad)',
                  hintText: 'Ej: 3',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.track_changes),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'La meta es requerida';
                  final n = int.tryParse(v.trim());
                  if (n == null || n < 1) return 'Ingresa un número entero mayor a 0';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Fecha límite (Opcional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                    suffixIcon: Icon(Icons.arrow_drop_down),
                  ),
                  child: Text(
                    _fechaLimite != null
                        ? DateFormat('dd/MM/yyyy').format(_fechaLimite!)
                        : 'Sin fecha límite',
                    style: TextStyle(color: _fechaLimite != null ? Colors.black87 : Colors.grey[600]),
                  ),
                ),
              ),
              if (_fechaLimite != null)
                TextButton(
                  onPressed: () => setState(() => _fechaLimite = null),
                  child: const Text('Quitar fecha límite', style: TextStyle(color: Colors.red)),
                ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7AC142),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('CREAR MISIÓN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
