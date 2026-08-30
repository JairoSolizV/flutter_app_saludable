import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../data/datasources/remote/club_remote_data_source.dart';
import '../../../../data/datasources/remote/membresia_remote_data_source.dart';
import '../../../../data/datasources/remote/pre_socio_remote_data_source.dart';
import '../../../../domain/entities/club_membership.dart';
import '../../../../presentation/widgets/member_picker_field.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';
import 'package:flutter_app_saludable/core/utils/input_formatters.dart';

class HostPreSocioCreateScreen extends StatefulWidget {
  final int clubId;

  const HostPreSocioCreateScreen({super.key, required this.clubId});

  @override
  State<HostPreSocioCreateScreen> createState() =>
      _HostPreSocioCreateScreenState();
}

class _HostPreSocioCreateScreenState extends State<HostPreSocioCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  ClubMembership? _referente;
  List<ClubMembership> _members = [];
  bool _isLoadingMembers = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    try {
      final ds = Provider.of<ClubRemoteDataSource>(context, listen: false);
      final members = await ds.getClubMembers(widget.clubId);
      if (mounted)
        setState(() {
          _members = members;
          _isLoadingMembers = false;
        });
    } catch (_) {
      if (mounted) setState(() => _isLoadingMembers = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final ds = Provider.of<PreSocioRemoteDataSource>(context, listen: false);
      await ds.crearPreSocio(
        clubId: widget.clubId,
        nombre: _nombreCtrl.text.trim(),
        telefono: _telefonoCtrl.text.trim(),
        referidoPorMembresiaId: _referente?.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Pre-Socio creado'), backgroundColor: Colors.green),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo Pre-Socio'),
        backgroundColor: AppTheme.primaryColor,
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
                maxLength: 255,
                inputFormatters: AppFormatters.letras(255),
                decoration: const InputDecoration(
                  labelText: 'Nombre completo',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                  counterText: '',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'El nombre es requerido'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _telefonoCtrl,
                maxLength: 8,
                inputFormatters: AppFormatters.telefono,
                decoration: const InputDecoration(
                  labelText: 'Teléfono',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone_outlined),
                  counterText: '',
                ),
                keyboardType: TextInputType.phone,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'El teléfono es requerido'
                    : null,
              ),
              const SizedBox(height: 16),
              const Text('Referido por (Opcional)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              _isLoadingMembers
                  ? const LinearProgressIndicator(color: AppTheme.primaryColor)
                  : MemberPickerField(
                      members: _members,
                      selected: _referente,
                      onChanged: (v) => setState(() => _referente = v),
                      enableGlobalSearch: true,
                      onGlobalSearch: (query, page) {
                        final ds = Provider.of<MembresiaRemoteDataSource>(
                            context,
                            listen: false);
                        return ds.buscarMiembrosGlobalPage(
                            query: query, page: page, size: 20);
                      },
                    ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('CREAR FICHA',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
