import 'package:flutter/material.dart';
import '../../domain/entities/club_membership.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';

class MemberPickerField extends StatelessWidget {
  final List<ClubMembership> members;
  final ClubMembership? selected;
  final ValueChanged<ClubMembership?> onChanged;
  final bool enabled;

  const MemberPickerField({
    super.key,
    required this.members,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
  });

  Future<void> _openPicker(BuildContext context) async {
    final result = await showModalBottomSheet<ClubMembership?>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _MemberPickerSheet(members: members, initial: selected),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = selected != null;
    return InkWell(
      onTap: (!enabled || members.isEmpty) ? null : () => _openPicker(context),
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.person_search),
          suffixIcon: hasSelection && enabled
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
              : (members.isEmpty
                  ? 'No hay socios en este club'
                  : 'Selecciona el socio que lo refirió'),
          style: TextStyle(
            color: hasSelection ? Colors.black : Colors.grey[600],
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class _MemberPickerSheet extends StatefulWidget {
  final List<ClubMembership> members;
  final ClubMembership? initial;

  const _MemberPickerSheet({required this.members, required this.initial});

  @override
  State<_MemberPickerSheet> createState() => _MemberPickerSheetState();
}

class _MemberPickerSheetState extends State<_MemberPickerSheet> {
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
      _filtered = query.isEmpty
          ? List.of(widget.members)
          : widget.members
              .where((m) =>
                  m.usuarioNombre.toLowerCase().contains(query) ||
                  m.numeroSocio.toLowerCase().contains(query))
              .toList();
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
                  hintText: 'Buscar por nombre o número...',
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
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primaryColor,
                            child: Text(
                              m.usuarioNombre.isNotEmpty
                                  ? m.usuarioNombre[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(m.usuarioNombre),
                          subtitle:
                              Text('Socio: ${m.numeroSocio} · ${m.nivelNombre}'),
                          trailing: widget.initial?.id == m.id
                              ? const Icon(Icons.check_circle,
                                  color: AppTheme.primaryColor)
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
