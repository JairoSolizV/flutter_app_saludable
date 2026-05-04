import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../data/datasources/remote/membresia_remote_data_source.dart';
import '../../../../data/datasources/remote/club_remote_data_source.dart';
import '../../../../domain/entities/club_membership.dart';
import '../../../../presentation/widgets/member_picker_field.dart';

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
  final _conocioCtrl = TextEditingController();
  
  bool _isLoading = false;
  bool _isLoadingMembers = true;
  List<ClubMembership> _members = [];
  ClubMembership? _selectedReferral;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final clubDataSource = Provider.of<ClubRemoteDataSource>(context, listen: false);
      final members = await clubDataSource.getClubMembers(widget.clubId);
      if (mounted) {
        setState(() {
          _members = members;
          _isLoadingMembers = false;
        });
      }
    } catch (e) {
      print('Error loading members for referral search: $e');
      if (mounted) setState(() => _isLoadingMembers = false);
    }
  }

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

              const Text('Referido por (Opcional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              if (_isLoadingMembers)
                const LinearProgressIndicator(color: Color(0xFF7AC142))
              else
                MemberPickerField(
                  members: _members,
                  selected: _selectedReferral,
                  onChanged: (value) => setState(() => _selectedReferral = value),
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
        referidoPorMembresiaId: _selectedReferral?.id,
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
