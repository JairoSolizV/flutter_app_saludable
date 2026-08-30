import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/core/utils/app_logger.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../../domain/entities/product.dart';
import '../../../../domain/entities/combo.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../../data/datasources/remote/club_remote_data_source.dart';
import '../../../../data/datasources/remote/combo_remote_data_source.dart';
import '../../../widgets/product_image.dart';
import 'package:flutter_app_saludable/core/errors/error_mapper.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';
import 'package:flutter_app_saludable/presentation/widgets/refreshable_scroll_view.dart';
import 'host_combo_create_screen.dart';

class HostProductListScreen extends StatefulWidget {
  const HostProductListScreen({super.key});

  @override
  State<HostProductListScreen> createState() => _HostProductListScreenState();
}

class _HostProductListScreenState extends State<HostProductListScreen> {
  int? _clubId;
  int? _hubId;
  bool _isLoadingClub = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Combos state
  List<Combo> _combos = [];
  bool _isLoadingCombos = false;
  String? _combosError;

  @override
  void initState() {
    super.initState();
    _loadClubAndProducts();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClubAndProducts() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final clubDataSource = Provider.of<ClubRemoteDataSource>(context, listen: false);
    final currentUser = userProvider.currentUser;

    if (currentUser != null && int.tryParse(currentUser.id) != null) {
      try {
        final club = await clubDataSource.getMyClub();
        if (club != null) {
          _clubId = club.id;
          _hubId = club.hubId;
          if (mounted) {
            // New Logic: Load all Hub products
             Provider.of<ProductProvider>(context, listen: false).loadProducts(hubId: _hubId!, clubId: _clubId!);
            _loadCombos();
          }
        }
      } catch (e) {
        logDebug('Error cargando club: $e');
      }
    }
    
    if (mounted) {
      setState(() {
        _isLoadingClub = false;
      });
    }
  }

  /// Recarga los productos del hub. Usado por pull-to-refresh.
  Future<void> _refreshProducts() async {
    if (_hubId != null && _clubId != null) {
      await Provider.of<ProductProvider>(context, listen: false)
          .loadProducts(hubId: _hubId!, clubId: _clubId!);
    }
  }

  Future<void> _loadCombos() async {
    if (_clubId == null) return;
    setState(() { _isLoadingCombos = true; _combosError = null; });
    try {
      final comboDs = Provider.of<ComboRemoteDataSource>(context, listen: false);
      final result = await comboDs.getCombosByClub(_clubId!);
      if (mounted) setState(() { _combos = result; _isLoadingCombos = false; });
    } catch (e) {
      if (mounted) setState(() { _combosError = e.toString(); _isLoadingCombos = false; });
    }
  }

  Future<void> _toggleCombo(Combo combo) async {
    try {
      final comboDs = Provider.of<ComboRemoteDataSource>(context, listen: false);
      final updated = await comboDs.toggleCombo(_clubId!, combo.id!);
      setState(() {
        final idx = _combos.indexWhere((c) => c.id == combo.id);
        if (idx >= 0) _combos[idx] = updated;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cambiar estado: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteCombo(Combo combo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar combo'),
        content: Text('¿Seguro que deseas eliminar "${combo.nombre}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (!mounted || confirm != true) return;
    try {
      final comboDs = Provider.of<ComboRemoteDataSource>(context, listen: false);
      await comboDs.deleteCombo(_clubId!, combo.id!);
      setState(() { _combos.removeWhere((c) => c.id == combo.id); });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Combo eliminado'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _onToggleClubAvailability(Product product) async {
    if (_clubId == null || _hubId == null) return;
    final provider = Provider.of<ProductProvider>(context, listen: false);
    if (provider.isToggling(product.id)) return;
    try {
      await provider.toggleAvailability(_clubId!, product.id, _hubId!);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ErrorMapper.publicMessage(e,
                fallback: 'No se pudo cambiar la disponibilidad en tu club'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mi Menú (Stock)'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          bottom: const TabBar(
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppTheme.primaryColor,
            tabs: [
              Tab(text: 'Globales'),
              Tab(text: 'Propios'),
              Tab(text: 'Combos'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                 if (_clubId != null && _hubId != null) {
                   Provider.of<ProductProvider>(context, listen: false).loadProducts(hubId: _hubId!, clubId: _clubId!);
                   _loadCombos();
                 }
              },
            )
          ],
        ),
        body: _isLoadingClub 
            ? const Center(child: CircularProgressIndicator())
            : _clubId == null 
                ? const Center(child: Text('No se encontró tu Club.'))
                : Consumer<ProductProvider>(
                    builder: (context, provider, child) {
                      if (provider.isLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (provider.error != null) {
                         return Center(child: Text('Error: ${provider.error}', style: const TextStyle(color: Colors.red)));
                      }

                      // Filtrar productos según la búsqueda
                      final filteredProducts = provider.products.where((product) {
                        if (_searchQuery.isEmpty) return true;
                        return product.name.toLowerCase().contains(_searchQuery) ||
                               product.description.toLowerCase().contains(_searchQuery);
                      }).toList();

                      final globalProducts = filteredProducts.where((p) => p.tipo == 'GLOBAL').toList();
                      final ownProducts = filteredProducts.where((p) => p.tipo == 'LOCAL').toList();

                      return Column(
                        children: [
                          // Barra de búsqueda
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Buscar productos...',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          _searchController.clear();
                                        },
                                      )
                                    : null,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey[100],
                              ),
                            ),
                          ),
                          // Tabs content
                          Expanded(
                            child: TabBarView(
                              children: [
                                _buildProductList(globalProducts, provider, isGlobal: true),
                                _buildProductList(ownProducts, provider, isGlobal: false),
                                _buildComboList(),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
        // El botón de + Nuevo se movió al tab de Propios

      ),
    );
  }

  Widget _buildProductList(List<Product> products, ProductProvider provider, {required bool isGlobal}) {
    return Stack(
      children: [
        if (products.isEmpty)
          RefreshableScrollView(
            onRefresh: _refreshProducts,
            child: Text(
              _searchQuery.isNotEmpty
                  ? 'No se encontraron resultados para "$_searchQuery"'
                  : (isGlobal ? 'No hay productos globales disponibles.' : 'Aún no has creado productos propios.'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          )
        else
          RefreshIndicator(
            onRefresh: _refreshProducts,
            color: AppTheme.primaryColor,
            child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  isThreeLine: true,
                  leading: _buildProductImage(product),
                  title: Text(
                    product.name, 
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: product.available ? Colors.black : Colors.grey,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.description,
                        maxLines: 2, 
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Puntos Volumen: ${product.puntosValor}',
                        style: const TextStyle(fontWeight: FontWeight.w500, color: AppTheme.primaryColor),
                      ),
                      if (!isGlobal && product.estadoAprobacion != 'APROBADO') 
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: product.estadoAprobacion == 'RECHAZADO' ? Colors.red.shade100 : Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            product.estadoAprobacion == 'RECHAZADO' ? 'Rechazado' : 'Pendiente de aprobación',
                            style: TextStyle(
                              fontSize: 12,
                              color: product.estadoAprobacion == 'RECHAZADO' ? Colors.red.shade900 : Colors.orange.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                    ],
                  ),
                  trailing: Semantics(
                    label: 'Disponible en mi club',
                    button: true,
                    child: Switch(
                      key: ValueKey('club-avail-${product.id}'),
                      activeThumbColor: AppTheme.primaryColor,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      value: product.available &&
                          product.estadoAprobacion == 'APROBADO',
                      onChanged: product.estadoAprobacion == 'APROBADO' &&
                              !provider.isToggling(product.id)
                          ? (_) => _onToggleClubAvailability(product)
                          : null,
                    ),
                  ),
                  onTap: _clubId == null
                      ? null
                      : () async {
                          if (provider.isToggling(product.id)) return;
                          final changed = await context.push<bool>(
                            '/host/products/review',
                            extra: {
                              'clubId': _clubId!,
                              'product': product,
                            },
                          );
                          if (changed == true && mounted) {
                            await _refreshProducts();
                          }
                        },
                  onLongPress: () {
                    if (provider.isToggling(product.id)) return;
                  },
                ),
              );
            },
          ),
          ),

        if (!isGlobal)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.extended(
              heroTag: 'addProductFab',
              backgroundColor: AppTheme.primaryColor,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Nuevo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () {
                context.push('/host/products/proposal');
              },
            ),
          ),
      ],
    );
  }

  Widget _buildProductImage(Product product) {
    return ProductImage(
      imageUrl: product.imageUrl.isEmpty ? null : product.imageUrl,
      width: 50,
      height: 50,
    );
  }

  // ===================== Combos Tab =====================

  Widget _buildComboList() {
    return Stack(
      children: [
        if (_isLoadingCombos)
          const Center(child: CircularProgressIndicator())
        else if (_combosError != null)
          RefreshableScrollView(
            onRefresh: _loadCombos,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 8),
                Text('Error: $_combosError', style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _loadCombos,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          )
        else if (_combos.isEmpty)
          RefreshableScrollView(
            onRefresh: _loadCombos,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.fastfood_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 12),
                Text(
                  'Aún no has creado combos.\nPresiona + para crear tu primer combo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
            ),
          )
        else
          RefreshIndicator(
            onRefresh: _loadCombos,
            color: AppTheme.primaryColor,
            child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _combos.length,
            itemBuilder: (context, index) {
              final combo = _combos[index];
              final itemsText = combo.items.map((i) {
                String label = '${i.cantidad}x ${i.productoNombre}';
                if (i.saborNombre != null) label += ' (${i.saborNombre})';
                return label;
              }).join(', ');

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: combo.activo ? AppTheme.primaryColor : Colors.grey,
                    child: const Icon(Icons.fastfood, color: Colors.white),
                  ),
                  title: Text(
                    combo.nombre,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: combo.activo ? Colors.black : Colors.grey,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (combo.descripcion != null && combo.descripcion!.isNotEmpty)
                        Text(combo.descripcion!, maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                        itemsText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Puntos: ${combo.puntosValor}',
                        style: const TextStyle(fontWeight: FontWeight.w500, color: AppTheme.primaryColor),
                      ),
                    ],
                  ),
                  trailing: Switch(
                    activeThumbColor: AppTheme.primaryColor,
                    value: combo.activo,
                    onChanged: (_) => _toggleCombo(combo),
                  ),
                  onTap: () async {
                    final result = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => HostComboCreateScreen(
                          clubId: _clubId!,
                          existingCombo: combo,
                        ),
                      ),
                    );
                    if (result == true) _loadCombos();
                  },
                  onLongPress: () => _deleteCombo(combo),
                ),
              );
            },
          ),
          ),

        // FAB para crear combo
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            heroTag: 'addComboFab',
            backgroundColor: AppTheme.primaryColor,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Nuevo Combo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () async {
              final result = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => HostComboCreateScreen(clubId: _clubId!),
                ),
              );
              if (result == true) _loadCombos();
            },
          ),
        ),
      ],
    );
  }
}
