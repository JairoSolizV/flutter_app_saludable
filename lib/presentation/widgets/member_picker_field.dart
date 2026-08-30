import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/pagination/paged_result.dart';
import '../../domain/entities/club_membership.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';
import 'package:flutter_app_saludable/core/utils/input_formatters.dart';

class MemberPickerField extends StatelessWidget {
  final List<ClubMembership> members;
  final ClubMembership? selected;
  final ValueChanged<ClubMembership?> onChanged;
  final bool enabled;
  final bool enableGlobalSearch;

  /// Búsqueda global paginada: recibe `query` y `page` (0-indexed) y debe
  /// devolver la [PagedResult] correspondiente (p. ej. desde
  /// `buscarMiembrosGlobalPage`).
  final Future<PagedResult<ClubMembership>> Function(String query, int page)?
      onGlobalSearch;

  const MemberPickerField({
    super.key,
    required this.members,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
    this.enableGlobalSearch = false,
    this.onGlobalSearch,
  });

  Future<void> _openPicker(BuildContext context) async {
    final result = await showModalBottomSheet<ClubMembership?>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _MemberPickerSheet(
        members: members,
        initial: selected,
        enableGlobalSearch: enableGlobalSearch,
        onGlobalSearch: onGlobalSearch,
      ),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = selected != null;
    return InkWell(
      onTap: (!enabled || (members.isEmpty && !enableGlobalSearch))
          ? null
          : () => _openPicker(context),
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
          hintText: (members.isEmpty && !enableGlobalSearch)
              ? 'No hay socios en este club'
              : 'Selecciona el socio que lo refirió',
        ),
        child: Text(
          hasSelection
              ? '${selected!.usuarioNombre} (${selected!.numeroSocio})'
              : ((members.isEmpty && !enableGlobalSearch)
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
  final bool enableGlobalSearch;
  final Future<PagedResult<ClubMembership>> Function(String query, int page)?
      onGlobalSearch;

  const _MemberPickerSheet({
    required this.members,
    required this.initial,
    this.enableGlobalSearch = false,
    this.onGlobalSearch,
  });

  @override
  State<_MemberPickerSheet> createState() => _MemberPickerSheetState();
}

class _MemberPickerSheetState extends State<_MemberPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _resultsScrollController = ScrollController();
  late List<ClubMembership> _filtered;
  List<ClubMembership> _globalResults = [];
  bool _isSearchingGlobal = false;
  bool _isLoadingMoreGlobal = false;
  int _globalPage = 0;
  bool _globalHasNext = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _filtered = List.of(widget.members);
    _searchCtrl.addListener(_onSearchChanged);
    _resultsScrollController.addListener(_onResultsScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _resultsScrollController.removeListener(_onResultsScroll);
    _resultsScrollController.dispose();
    super.dispose();
  }

  void _onResultsScroll() {
    if (!widget.enableGlobalSearch || widget.onGlobalSearch == null) return;
    if (!_resultsScrollController.hasClients) return;
    final position = _resultsScrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      _loadMoreGlobal();
    }
  }

  void _onSearchChanged() {
    final query = _searchCtrl.text.trim();
    final lowerQuery = query.toLowerCase();

    setState(() {
      if (query.isEmpty) {
        _filtered = List.of(widget.members);
        _globalResults = [];
        _globalPage = 0;
        _globalHasNext = false;
        return;
      }

      _filtered = widget.members
          .where((m) =>
              m.usuarioNombre.toLowerCase().contains(lowerQuery) ||
              m.numeroSocio.toLowerCase().contains(lowerQuery))
          .toList();
    });

    if (widget.enableGlobalSearch && widget.onGlobalSearch != null) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 400), () {
        _performGlobalSearch(query);
      });
    }
  }

  Future<void> _performGlobalSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _globalResults = [];
        _globalPage = 0;
        _globalHasNext = false;
      });
      return;
    }

    setState(() => _isSearchingGlobal = true);

    try {
      final result = await widget.onGlobalSearch!(query, 0);
      if (mounted) {
        setState(() {
          _globalResults = result.content;
          _globalPage = result.page;
          _globalHasNext = result.hasNext;
          _isSearchingGlobal = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSearchingGlobal = false);
      }
    }
  }

  Future<void> _loadMoreGlobal() async {
    if (_isLoadingMoreGlobal || !_globalHasNext) return;
    final query = _searchCtrl.text.trim();
    if (query.isEmpty || widget.onGlobalSearch == null) return;

    setState(() => _isLoadingMoreGlobal = true);
    try {
      final result = await widget.onGlobalSearch!(query, _globalPage + 1);
      if (!mounted) return;
      setState(() {
        final existingIds = _globalResults.map((m) => m.id).toSet();
        _globalResults = [
          ..._globalResults,
          ...result.content.where((m) => !existingIds.contains(m.id)),
        ];
        _globalPage = result.page;
        _globalHasNext = result.hasNext;
        _isLoadingMoreGlobal = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingMoreGlobal = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final showGlobalSection =
        widget.enableGlobalSearch && _searchCtrl.text.trim().isNotEmpty;

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
            Text(
              widget.enableGlobalSearch
                  ? 'Buscar socio referente'
                  : 'Seleccionar referido',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (widget.enableGlobalSearch)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Busca en todos los clubes',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                maxLength: 100,
                inputFormatters: AppFormatters.largo(100),
                decoration: InputDecoration(
                  counterText: '',
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
              child: _searchCtrl.text.trim().isEmpty
                  ? _buildLocalList()
                  : _buildSearchResults(showGlobalSection),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalList() {
    if (widget.members.isEmpty) {
      return const Center(
        child: Text(
          'No hay socios en este club',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    return ListView.separated(
      itemCount: _filtered.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) => _buildMemberTile(_filtered[index]),
    );
  }

  Widget _buildSearchResults(bool showGlobalSection) {
    final hasLocalResults = _filtered.isNotEmpty;
    final hasGlobalResults = _globalResults.isNotEmpty;
    final noResults =
        !hasLocalResults && !hasGlobalResults && !_isSearchingGlobal;

    if (noResults) {
      return const Center(
        child: Text(
          'No se encontraron socios',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView(
      controller: _resultsScrollController,
      children: [
        if (hasLocalResults) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'En este club',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          ..._filtered.map((m) => _buildMemberTile(m)),
          if (showGlobalSection && (hasGlobalResults || _isSearchingGlobal))
            const Divider(height: 24),
        ],
        if (showGlobalSection) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Text(
              'Todos los clubes',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
          ),
          if (_isSearchingGlobal)
            const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(color: AppTheme.primaryColor),
            ),
          ..._globalResults.map((m) => _buildMemberTile(m, isGlobal: true)),
          if (_isLoadingMoreGlobal)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.primaryColor),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildMemberTile(ClubMembership m, {bool isGlobal = false}) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isGlobal
            ? Colors.blueGrey.withOpacity(0.15)
            : AppTheme.primaryColor,
        child: Text(
          m.usuarioNombre.isNotEmpty ? m.usuarioNombre[0].toUpperCase() : '?',
          style: TextStyle(
            color: isGlobal ? Colors.blueGrey : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(m.usuarioNombre),
      subtitle: Text(
        'Socio: ${m.numeroSocio}'
        '${m.nivelNombre.isNotEmpty ? ' · ${m.nivelNombre}' : ''}'
        '${isGlobal && m.clubNombre.isNotEmpty ? ' · ${m.clubNombre}' : ''}',
      ),
      trailing: widget.initial?.id == m.id
          ? const Icon(Icons.check_circle, color: AppTheme.primaryColor)
          : null,
      onTap: () => Navigator.of(context).pop(m),
    );
  }
}
