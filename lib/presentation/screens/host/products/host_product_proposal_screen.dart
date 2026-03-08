import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../data/datasources/remote/product_remote_data_source.dart';
import '../../../../data/datasources/remote/club_remote_data_source.dart';

class HostProductProposalScreen extends StatefulWidget {
  const HostProductProposalScreen({super.key});

  @override
  State<HostProductProposalScreen> createState() => _HostProductProposalScreenState();
}

class _HostProductProposalScreenState extends State<HostProductProposalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _ingredientesCtrl = TextEditingController();
  final _puntosValorCtrl = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _ingredientesCtrl.dispose();
    _puntosValorCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final puntos = int.tryParse(_puntosValorCtrl.text.trim());
    if (puntos == null || puntos <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa un valor de puntos válido (entero positivo).'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Obtener el club del anfitrión para extraer el hubId
      final clubDataSource = Provider.of<ClubRemoteDataSource>(context, listen: false);
      final club = await clubDataSource.getMyClub();
      
      if (club == null) {
        throw Exception('No se encontró tu club. Verifica que tengas un club asignado como anfitrión.');
      }

      final dataSource = Provider.of<ProductRemoteDataSource>(context, listen: false);

      await dataSource.createProductProposal(
        hubId: club.hubId, // Incluir hubId del club del anfitrión
        nombre: _nombreCtrl.text.trim(),
        descripcion: _descripcionCtrl.text.trim(),
        ingredientes: _ingredientesCtrl.text.trim(),
        puntosValor: puntos,
      );

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Propuesta enviada'),
          content: const Text(
            'Producto enviado a revisión. Una vez el Administrador lo apruebe, '
            'podrás hacerlo visible para tus socios.',
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
          content: Text('Error al enviar la propuesta: ${e.toString().replaceAll('Exception: ', '')}'),
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
        title: const Text('Proponer Producto del Club'),
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
                'Completa los datos del batido/producto que quieres que el Administrador revise '
                'para tu menú propio.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Producto',
                  prefixIcon: Icon(LucideIcons.coffee),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'El nombre es obligatorio' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descripcionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ingredientesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ingredientes (obligatorio)',
                  hintText: 'Ej: Té verde, aloe, proteína, hielo...',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(LucideIcons.list),
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Debes detallar los ingredientes para que el Admin pueda revisarlo'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _puntosValorCtrl,
                decoration: const InputDecoration(
                  labelText: 'Puntos de Valor',
                  hintText: 'Ej: 10',
                  prefixIcon: Icon(LucideIcons.star),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Ingresa los puntos de valor' : null,
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
                  label: Text(
                    _isSubmitting ? 'Enviando...' : 'Enviar a Revisión',
                  ),
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


