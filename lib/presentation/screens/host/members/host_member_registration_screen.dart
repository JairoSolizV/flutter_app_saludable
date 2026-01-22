import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../data/datasources/remote/membresia_remote_data_source.dart';
import '../../../../data/datasources/remote/club_remote_data_source.dart';
import '../../../providers/user_provider.dart';

class HostMemberRegistrationScreen extends StatefulWidget {
  final String qrPayload; // Changed from int userId
  final int clubId;

  const HostMemberRegistrationScreen({
    super.key,
    required this.qrPayload,
    required this.clubId,
  });

  @override
  State<HostMemberRegistrationScreen> createState() => _HostMemberRegistrationScreenState();
}

class _HostMemberRegistrationScreenState extends State<HostMemberRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _referidoCtrl = TextEditingController();
  final _conocioCtrl = TextEditingController();
  
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    // Try to parse ID for display purposes if possible
    String displayId = widget.qrPayload;
    if (widget.qrPayload.startsWith('ACTIVATE:')) {
      displayId = widget.qrPayload.split(':')[1];
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Nuevo Socio'),
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
               Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade100),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_add, color: Colors.green, size: 30),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ID/Código Detectado:', style: TextStyle(color: Colors.grey)),
                        Text(displayId, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              const Text('Información Adicional', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              TextFormField(
                controller: _referidoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Referido Por (Opcional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.people_outline),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _conocioCtrl,
                decoration: const InputDecoration(
                  labelText: '¿Cómo conoció el Club? (Opcional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.question_answer_outlined),
                ),
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
                    : const Text('CONFIRMAR ACTIVACIÓN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final membresiaDataSource = Provider.of<MembresiaRemoteDataSource>(context, listen: false);

      print('Activando socio...');
      print('Payload: ${widget.qrPayload}, ClubID: ${widget.clubId}');

      await membresiaDataSource.activarSocio(
        clubId: widget.clubId,
        activationPayload: widget.qrPayload,
        referidoPor: _referidoCtrl.text,
        comoConocio: _conocioCtrl.text,
      ).timeout(const Duration(seconds: 15), onTimeout: () {
        throw Exception('Tiempo de espera agotado. Verifica tu conexión.');
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Socio activado exitosamente'), backgroundColor: Colors.green),
      );
      
      context.pop(); 

    } catch (e) {
      print('Error al activar socio: $e');
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error de Activación'),
          content: SingleChildScrollView(
            child: Text(e.toString().replaceAll('Exception: ', '')),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            )
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
