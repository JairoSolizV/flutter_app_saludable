import 'package:flutter/foundation.dart';

import 'paged_result.dart';

/// Obtiene la página [page] (0-indexed) de resultados.
typedef PageFetcher<T> = Future<PagedResult<T>> Function(int page);

/// Extrae el identificador único de [item], usado para deduplicar.
typedef IdExtractor<T, K> = K Function(T item);

/// Controlador genérico de listas paginadas con scroll infinito y
/// pull-to-refresh, pensado para pantallas que hoy usan `setState` manual
/// (no requiere `Provider`; basta con `addListener`/`removeListener`).
///
/// Responsabilidades:
/// - Evita aplicar resultados de llamadas obsoletas (token de generación).
/// - Evita llamadas concurrentes de `loadMore` (single-flight).
/// - Deduplica items por [IdExtractor] al acumular páginas.
/// - No usa delays artificiales: cada operación resuelve tan pronto como
///   responde [fetchPage].
class PagedListController<T, K> extends ChangeNotifier {
  PagedListController({
    required PageFetcher<T> fetchPage,
    required IdExtractor<T, K> idExtractor,
  })  : _fetchPage = fetchPage,
        _idExtractor = idExtractor;

  PageFetcher<T> _fetchPage;
  final IdExtractor<T, K> _idExtractor;

  final List<T> _items = [];
  final Set<K> _ids = {};

  int _nextPage = 0;
  int _generation = 0;
  bool _isInitialLoading = false;
  bool _isRefreshing = false;
  bool _isLoadingMore = false;
  bool _hasNextPage = true;
  Object? _initialError;
  Object? _loadMoreError;
  int? _totalElements;

  List<T> get items => List.unmodifiable(_items);
  bool get isInitialLoading => _isInitialLoading;
  bool get isRefreshing => _isRefreshing;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasNextPage => _hasNextPage;
  Object? get initialError => _initialError;
  Object? get loadMoreError => _loadMoreError;
  int? get totalElements => _totalElements;
  bool get isEmpty => _items.isEmpty;

  /// Reemplaza la función de fetch (p. ej. cambio de filtro/query). El
  /// llamador debe invocar [loadInitial] o [refresh] después para aplicarla.
  void updateFetcher(PageFetcher<T> fetchPage) {
    _fetchPage = fetchPage;
  }

  void _addDeduped(Iterable<T> newItems) {
    for (final item in newItems) {
      final id = _idExtractor(item);
      if (_ids.add(id)) {
        _items.add(item);
      }
    }
  }

  /// Carga (o recarga desde cero) la primera página. Descarta cualquier
  /// carga en curso previa mediante el token de generación: si esta llamada
  /// es la más reciente, sus resultados siempre prevalecen.
  Future<void> loadInitial() async {
    final generation = ++_generation;
    _items.clear();
    _ids.clear();
    _nextPage = 0;
    _hasNextPage = true;
    _initialError = null;
    _loadMoreError = null;
    _isInitialLoading = true;
    notifyListeners();

    try {
      final result = await _fetchPage(0);
      if (generation != _generation) return; // respuesta obsoleta
      _addDeduped(result.content);
      _nextPage = result.page + 1;
      _hasNextPage = result.hasNext;
      _totalElements = result.totalElements;
      _initialError = null;
    } catch (e) {
      if (generation != _generation) return;
      _initialError = e;
    } finally {
      if (generation == _generation) {
        _isInitialLoading = false;
        notifyListeners();
      }
    }
  }

  /// Recarga la página 0 conservando los items visibles hasta que la nueva
  /// respuesta llegue (evita parpadeo en pull-to-refresh). Si falla y ya
  /// había items cargados, estos se conservan y el error queda accesible
  /// mediante la excepción relanzada al llamador.
  Future<void> refresh() async {
    final generation = ++_generation;
    _isRefreshing = true;
    notifyListeners();

    try {
      final result = await _fetchPage(0);
      if (generation != _generation) return;
      _items.clear();
      _ids.clear();
      _addDeduped(result.content);
      _nextPage = result.page + 1;
      _hasNextPage = result.hasNext;
      _totalElements = result.totalElements;
      _initialError = null;
      _loadMoreError = null;
    } catch (e) {
      if (generation != _generation) return;
      // Conserva los items existentes; solo se expone el error si la lista
      // quedó vacía (no hay nada útil que mostrar salvo el error).
      if (_items.isEmpty) {
        _initialError = e;
      }
    } finally {
      if (generation == _generation) {
        _isRefreshing = false;
        notifyListeners();
      }
    }
  }

  /// Carga la siguiente página y la agrega al final. Single-flight: si ya
  /// hay una carga en curso (inicial, refresh o loadMore) o no hay más
  /// páginas, no hace nada.
  Future<void> loadMore() async {
    if (_isLoadingMore || _isInitialLoading || _isRefreshing) return;
    if (!_hasNextPage) return;

    final generation = _generation;
    _isLoadingMore = true;
    _loadMoreError = null;
    notifyListeners();

    try {
      final result = await _fetchPage(_nextPage);
      if (generation != _generation) return;
      _addDeduped(result.content);
      _nextPage = result.page + 1;
      _hasNextPage = result.hasNext;
      _totalElements = result.totalElements;
    } catch (e) {
      if (generation != _generation) return;
      _loadMoreError = e;
    } finally {
      if (generation == _generation) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }
}
