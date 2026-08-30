import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/core/utils/app_logger.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../data/datasources/remote/membresia_remote_data_source.dart';
import '../../../../data/datasources/remote/club_remote_data_source.dart';
import '../../../../data/datasources/remote/pre_socio_remote_data_source.dart';
import '../../../../domain/entities/club_membership.dart';
import '../../../../presentation/widgets/member_picker_field.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';
import 'package:flutter_app_saludable/core/utils/input_formatters.dart';

class HostMemberRegistrationScreen extends StatefulWidget {
  final String qrPayload;
  final int clubId;
  final int? preSocioId;
  final int? prefilledReferralId;

  const HostMemberRegistrationScreen({
    super.key,
    required this.qrPayload,
    required this.clubId,
    this.preSocioId,
    this.prefilledReferralId,
  });

  @override
  State<HostMemberRegistrationScreen> createState() =>
      _HostMemberRegistrationScreenState();
}

class _HostMemberRegistrationScreenState
    extends State<HostMemberRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _conocioCtrl = TextEditingController();

  bool _isLoading = false;
  bool _isLoadingMembers = true;
  List<ClubMembership> _members = [];
  ClubMembership? _selectedReferral;
  bool? _esClientePreferenteODistribuidor;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final clubDataSource =
          Provider.of<ClubRemoteDataSource>(context, listen: false);
      final members = await clubDataSource.getClubMembers(widget.clubId);
      if (mounted) {
        setState(() {
          _members = members;
          _isLoadingMembers = false;
          if (widget.prefilledReferralId != null) {
            final match = members
                .where((m) => m.id == widget.prefilledReferralId)
                .toList();
            if (match.isNotEmpty) _selectedReferral = match.first;
          }
        });
      }
    } catch (e) {
      logDebug('Error loading members for referral search: $e');
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
                        const Text('ID/Código Detectado:',
                            style: TextStyle(color: Colors.grey)),
                        Text(displayId,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text('Información Adicional',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text('Referido por (Opcional)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              if (widget.prefilledReferralId != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    const Icon(Icons.lock_outline,
                        size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    const Text(
                        'Referido pre-asignado desde la ficha del preSocio.',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ]),
                ),
              if (_isLoadingMembers)
                const LinearProgressIndicator(color: AppTheme.primaryColor)
              else
                MemberPickerField(
                  members: _members,
                  selected: _selectedReferral,
                  onChanged: widget.prefilledReferralId != null
                      ? (_) {}
                      : (value) => setState(() => _selectedReferral = value),
                  enabled: widget.prefilledReferralId == null,
                  enableGlobalSearch: true,
                  onGlobalSearch: (query, page) {
                    final ds = Provider.of<MembresiaRemoteDataSource>(context,
                        listen: false);
                    return ds.buscarMiembrosGlobalPage(
                        query: query, page: page, size: 20);
                  },
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _conocioCtrl,
                maxLength: 255,
                inputFormatters: AppFormatters.largo(255),
                decoration: const InputDecoration(
                  labelText: '¿Cómo conoció el Club? (Opcional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.question_answer_outlined),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 16),
              FormField<bool>(
                validator: (_) {
                  if (_esClientePreferenteODistribuidor == null) {
                    return 'Debe responder esta declaración para continuar';
                  }
                  return null;
                },
                builder: (field) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '¿Usted, su cónyuge o pareja de vida actualmente es cliente preferente o distribuidor independiente de Herbalife?',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<bool>(
                          emptySelectionAllowed: true,
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment<bool>(
                              value: true,
                              label: Text('SÍ'),
                            ),
                            ButtonSegment<bool>(
                              value: false,
                              label: Text('NO'),
                            ),
                          ],
                          selected: _esClientePreferenteODistribuidor == null
                              ? <bool>{}
                              : {_esClientePreferenteODistribuidor!},
                          onSelectionChanged: (selection) {
                            setState(() {
                              _esClientePreferenteODistribuidor =
                                  selection.isEmpty ? null : selection.first;
                            });
                            field.didChange(_esClientePreferenteODistribuidor);
                          },
                        ),
                      ),
                      if (field.hasError) ...[
                        const SizedBox(height: 8),
                        Text(
                          field.errorText!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('CONFIRMAR ACTIVACIÓN',
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_esClientePreferenteODistribuidor == null) {
      return;
    }

    if (_esClientePreferenteODistribuidor == true) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No se puede activar'),
          content: const Text(
            'Un cliente preferente o distribuidor independiente de Herbalife no puede registrarse como socio.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final membresiaDataSource =
          Provider.of<MembresiaRemoteDataSource>(context, listen: false);

      logDebug('Activando socio...');
      logDebug('Payload: ${widget.qrPayload}, ClubID: ${widget.clubId}');

      await membresiaDataSource
          .activarSocio(
        clubId: widget.clubId,
        activationPayload: widget.qrPayload,
        referidoPorMembresiaId: _selectedReferral?.id,
        comoConocio: _conocioCtrl.text,
        esClientePreferenteODistribuidor: _esClientePreferenteODistribuidor!,
      )
          .timeout(const Duration(seconds: 15), onTimeout: () {
        throw Exception('Tiempo de espera agotado. Verifica tu conexión.');
      });

      if (!mounted) return;

      if (widget.preSocioId != null) {
        try {
          final preSocioDs =
              Provider.of<PreSocioRemoteDataSource>(context, listen: false);
          await preSocioDs.actualizarPreSocio(widget.preSocioId!, 'CONVERTIDO');
        } catch (_) {}
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Socio activado exitosamente'),
            backgroundColor: Colors.green),
      );

      context.pop();
    } catch (e) {
      logDebug('Error al activar socio: $e');
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
