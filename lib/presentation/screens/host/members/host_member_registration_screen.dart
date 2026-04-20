import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../data/datasources/remote/membresia_remote_data_source.dart';
import '../../../../data/datasources/remote/club_remote_data_source.dart';
import '../../../../domain/entities/club_membership.dart';

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
                _ReferralDropdownField(
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

class _ReferralDropdownField extends StatelessWidget {
  final List<ClubMembership> members;
  final ClubMembership? selected;
  final ValueChanged<ClubMembership?> onChanged;

  const _ReferralDropdownField({
    required this.members,
    required this.selected,
    required this.onChanged,
  });

  Future<void> _openPicker(BuildContext context) async {
    final result = await showModalBottomSheet<ClubMembership?>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ReferralPickerSheet(members: members, initial: selected),
    );
    if (result != null) {
      onChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = selected != null;
    return InkWell(
      onTap: members.isEmpty ? null : () => _openPicker(context),
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.person_search),
          suffixIcon: hasSelection
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => onChanged(null),
                )
              : const Icon(Icons.arrow_drop_down),
          hintText: members.isEmpty
              ? 'No hay socios en este club'
              : 'Selecciona el socio que lo refirió',
        ),
        child: Text(
          hasSelection
              ? '${selected!.usuarioNombre} (${selected!.numeroSocio})'
              : (members.isEmpty ? 'No hay socios en este club' : 'Selecciona el socio que lo refirió'),
          style: TextStyle(
            color: hasSelection ? Colors.black : Colors.grey[600],
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class _ReferralPickerSheet extends StatefulWidget {
  final List<ClubMembership> members;
  final ClubMembership? initial;

  const _ReferralPickerSheet({required this.members, required this.initial});

  @override
  State<_ReferralPickerSheet> createState() => _ReferralPickerSheetState();
}

class _ReferralPickerSheetState extends State<_ReferralPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  late List<ClubMembership> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = List.of(widget.members);
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filtered = List.of(widget.members);
      } else {
        _filtered = widget.members.where((m) {
          return m.usuarioNombre.toLowerCase().contains(query) ||
              m.numeroSocio.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: SizedBox(
        height: mediaQuery.size.height * 0.75,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Seleccionar referido',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre o número de socio...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => _searchCtrl.clear(),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'No se encontraron socios',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final m = _filtered[index];
                        final isSelected = widget.initial?.id == m.id;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF7AC142),
                            child: Text(
                              m.usuarioNombre.isNotEmpty
                                  ? m.usuarioNombre[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(m.usuarioNombre),
                          subtitle: Text('Socio: ${m.numeroSocio} · ${m.nivelNombre}'),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle, color: Color(0xFF7AC142))
                              : null,
                          onTap: () => Navigator.of(context).pop(m),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
