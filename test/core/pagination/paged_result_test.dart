import 'package:flutter_app_saludable/core/pagination/paged_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PagedResult.fromJson', () {
    test('parsea una página vacía correctamente', () {
      final json = {
        'content': <dynamic>[],
        'page': 0,
        'size': 20,
        'totalElements': 0,
        'totalPages': 0,
        'first': true,
        'last': true,
        'hasNext': false,
        'hasPrevious': false,
      };

      final result = PagedResult<Map<String, dynamic>>.fromJson(
        json,
        (item) => item,
      );

      expect(result.content, isEmpty);
      expect(result.page, 0);
      expect(result.size, 20);
      expect(result.totalElements, 0);
      expect(result.totalPages, 0);
      expect(result.first, isTrue);
      expect(result.last, isTrue);
      expect(result.hasNext, isFalse);
      expect(result.hasPrevious, isFalse);
    });

    test('parsea metadata y contenido completos vía fromJsonT', () {
      final json = {
        'content': [
          {'id': 1, 'nombre': 'Uno'},
          {'id': 2, 'nombre': 'Dos'},
        ],
        'page': 1,
        'size': 2,
        'totalElements': 7,
        'totalPages': 4,
        'first': false,
        'last': false,
        'hasNext': true,
        'hasPrevious': true,
      };

      final result = PagedResult<_Item>.fromJson(
        json,
        (item) => _Item(item['id'] as int, item['nombre'] as String),
      );

      expect(result.content.map((e) => e.id), [1, 2]);
      expect(result.content.map((e) => e.nombre), ['Uno', 'Dos']);
      expect(result.page, 1);
      expect(result.size, 2);
      expect(result.totalElements, 7);
      expect(result.totalPages, 4);
      expect(result.first, isFalse);
      expect(result.last, isFalse);
      expect(result.hasNext, isTrue);
      expect(result.hasPrevious, isTrue);
    });

    test('lanza FormatException si content no es una List', () {
      final json = <String, dynamic>{
        'content': 'no-es-una-lista',
        'page': 0,
        'size': 20,
      };

      expect(
        () => PagedResult<Map<String, dynamic>>.fromJson(json, (item) => item),
        throwsFormatException,
      );
    });

    test('lanza FormatException si falta content', () {
      final json = <String, dynamic>{'page': 0, 'size': 20};

      expect(
        () => PagedResult<Map<String, dynamic>>.fromJson(json, (item) => item),
        throwsFormatException,
      );
    });

    test('lanza FormatException si un elemento de content no es Map', () {
      final json = <String, dynamic>{
        'content': [1, 2, 3],
        'page': 0,
        'size': 20,
      };

      expect(
        () => PagedResult<Map<String, dynamic>>.fromJson(json, (item) => item),
        throwsFormatException,
      );
    });

    test('usa fallbacks razonables si faltan campos de metadata', () {
      final json = <String, dynamic>{
        'content': [
          {'id': 1},
        ],
      };

      final result = PagedResult<Map<String, dynamic>>.fromJson(
        json,
        (item) => item,
      );

      expect(result.page, 0);
      expect(result.totalElements, 1);
      expect(result.first, isTrue);
      expect(result.hasNext, isFalse);
    });
  });

  group('PagedResult.empty', () {
    test('produce una página vacía consistente', () {
      final result = PagedResult<int>.empty(page: 2, size: 10);

      expect(result.content, isEmpty);
      expect(result.page, 2);
      expect(result.size, 10);
      expect(result.totalElements, 0);
      expect(result.hasNext, isFalse);
      expect(result.hasPrevious, isTrue);
    });
  });
}

class _Item {
  final int id;
  final String nombre;
  _Item(this.id, this.nombre);
}
