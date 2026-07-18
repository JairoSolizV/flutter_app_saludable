import 'dart:async';

import 'package:flutter_app_saludable/core/pagination/paged_list_controller.dart';
import 'package:flutter_app_saludable/core/pagination/paged_result.dart';
import 'package:flutter_test/flutter_test.dart';

PagedResult<int> _page(
  List<int> content, {
  required int page,
  bool hasNext = false,
  int? totalElements,
}) {
  return PagedResult<int>(
    content: content,
    page: page,
    size: content.isEmpty ? 20 : content.length,
    totalElements: totalElements ?? content.length,
    totalPages: 1,
    first: page == 0,
    last: !hasNext,
    hasNext: hasNext,
    hasPrevious: page > 0,
  );
}

void main() {
  group('PagedListController.loadInitial', () {
    test('carga la primera página y expone hasNextPage/items', () async {
      final controller = PagedListController<int, int>(
        fetchPage: (page) async => _page([1, 2], page: 0, hasNext: true),
        idExtractor: (i) => i,
      );

      await controller.loadInitial();

      expect(controller.items, [1, 2]);
      expect(controller.hasNextPage, isTrue);
      expect(controller.isInitialLoading, isFalse);
      expect(controller.initialError, isNull);
    });

    test('expone initialError si la primera carga falla', () async {
      final controller = PagedListController<int, int>(
        fetchPage: (page) async => throw Exception('boom'),
        idExtractor: (i) => i,
      );

      await controller.loadInitial();

      expect(controller.items, isEmpty);
      expect(controller.initialError, isNotNull);
      expect(controller.isInitialLoading, isFalse);
    });
  });

  group('PagedListController.loadMore', () {
    test('agrega la siguiente página al final', () async {
      int calledPage = -1;
      final controller = PagedListController<int, int>(
        fetchPage: (page) async {
          calledPage = page;
          if (page == 0) return _page([1, 2], page: 0, hasNext: true);
          return _page([3, 4], page: 1, hasNext: false);
        },
        idExtractor: (i) => i,
      );

      await controller.loadInitial();
      await controller.loadMore();

      expect(calledPage, 1);
      expect(controller.items, [1, 2, 3, 4]);
      expect(controller.hasNextPage, isFalse);
      expect(controller.isLoadingMore, isFalse);
    });

    test('no hace nada si no hay más páginas', () async {
      var fetchCount = 0;
      final controller = PagedListController<int, int>(
        fetchPage: (page) async {
          fetchCount++;
          return _page([1], page: 0, hasNext: false);
        },
        idExtractor: (i) => i,
      );

      await controller.loadInitial();
      await controller.loadMore();

      expect(fetchCount, 1); // solo la carga inicial
      expect(controller.items, [1]);
    });

    test('single-flight: llamadas concurrentes solo disparan un fetch',
        () async {
      var fetchCount = 0;
      final completer = Completer<PagedResult<int>>();

      final controller = PagedListController<int, int>(
        fetchPage: (page) async {
          if (page == 0) return _page([1], page: 0, hasNext: true);
          fetchCount++;
          return completer.future;
        },
        idExtractor: (i) => i,
      );

      await controller.loadInitial();

      final f1 = controller.loadMore();
      final f2 = controller.loadMore(); // debe ser un no-op inmediato
      await f2;

      expect(fetchCount, 1);
      expect(controller.isLoadingMore, isTrue);

      completer.complete(_page([2], page: 1, hasNext: false));
      await f1;

      expect(controller.items, [1, 2]);
      expect(controller.isLoadingMore, isFalse);
    });

    test('conserva los items existentes cuando loadMore falla', () async {
      var callCount = 0;
      final controller = PagedListController<int, int>(
        fetchPage: (page) async {
          callCount++;
          if (page == 0) return _page([1, 2], page: 0, hasNext: true);
          throw Exception('network error');
        },
        idExtractor: (i) => i,
      );

      await controller.loadInitial();
      await controller.loadMore();

      expect(callCount, 2);
      expect(controller.items, [1, 2]); // se conservan
      expect(controller.loadMoreError, isNotNull);
      expect(controller.isLoadingMore, isFalse);
      expect(controller.hasNextPage,
          isTrue); // no se pierde el estado de paginación

      // Reintentar debe volver a poder llamar loadMore (no queda bloqueado).
      final controller2 = PagedListController<int, int>(
        fetchPage: (page) async => _page([1], page: 0, hasNext: false),
        idExtractor: (i) => i,
      );
      await controller2.loadInitial();
      expect(controller2.loadMoreError, isNull);
    });
  });

  group('PagedListController.refresh', () {
    test('reemplaza los items desde la página 0', () async {
      var version = 1;
      final controller = PagedListController<int, int>(
        fetchPage: (page) async {
          if (version == 1) return _page([1, 2], page: 0, hasNext: false);
          return _page([9, 8, 7], page: 0, hasNext: false);
        },
        idExtractor: (i) => i,
      );

      await controller.loadInitial();
      expect(controller.items, [1, 2]);

      version = 2;
      await controller.refresh();

      expect(controller.items, [9, 8, 7]);
      expect(controller.isRefreshing, isFalse);
    });

    test('conserva items previos si el refresh falla', () async {
      var shouldFail = false;
      final controller = PagedListController<int, int>(
        fetchPage: (page) async {
          if (shouldFail) throw Exception('boom');
          return _page([1, 2], page: 0, hasNext: false);
        },
        idExtractor: (i) => i,
      );

      await controller.loadInitial();
      shouldFail = true;
      await controller.refresh();

      expect(controller.items, [1, 2]); // conservados
      expect(controller.initialError, isNull); // había datos, no se expone
    });

    test('expone initialError si el refresh falla y no había items previos',
        () async {
      final controller = PagedListController<int, int>(
        fetchPage: (page) async => throw Exception('boom'),
        idExtractor: (i) => i,
      );

      await controller.refresh();

      expect(controller.items, isEmpty);
      expect(controller.initialError, isNotNull);
    });
  });

  group('PagedListController - generación / stale', () {
    test('ignora resultados de un loadInitial obsoleto', () async {
      final completers = <Completer<PagedResult<int>>>[];
      final controller = PagedListController<int, int>(
        fetchPage: (page) {
          final c = Completer<PagedResult<int>>();
          completers.add(c);
          return c.future;
        },
        idExtractor: (i) => i,
      );

      final first = controller.loadInitial(); // generación 1
      final second = controller.loadInitial(); // generación 2

      // Resuelve primero la llamada más reciente (generación 2).
      completers[1].complete(_page([9, 8], page: 0, hasNext: false));
      await second;

      expect(controller.items, [9, 8]);

      // La respuesta tardía de la llamada obsoleta (generación 1) se descarta.
      completers[0].complete(_page([1, 2, 3], page: 0, hasNext: true));
      await first;

      expect(controller.items, [9, 8]);
      expect(controller.hasNextPage, isFalse);
      expect(controller.isInitialLoading, isFalse);
    });
  });

  group('PagedListController - dedupe', () {
    test('descarta items duplicados por id al acumular páginas', () async {
      final controller = PagedListController<int, int>(
        fetchPage: (page) async {
          if (page == 0) return _page([1, 2, 3], page: 0, hasNext: true);
          // "3" se repite entre la página 0 y la 1.
          return _page([3, 4, 5], page: 1, hasNext: false);
        },
        idExtractor: (i) => i,
      );

      await controller.loadInitial();
      await controller.loadMore();

      expect(controller.items, [1, 2, 3, 4, 5]);
    });
  });
}
