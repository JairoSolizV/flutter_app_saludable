/// Respuesta paginada genérica devuelta directamente por el backend
/// (sin envoltorio `ApiResponse`), con la forma:
/// ```json
/// {
///   "content": [...],
///   "page": 0,
///   "size": 20,
///   "totalElements": 0,
///   "totalPages": 0,
///   "first": true,
///   "last": true,
///   "hasNext": false,
///   "hasPrevious": false
/// }
/// ```
class PagedResult<T> {
  const PagedResult({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.first,
    required this.last,
    required this.hasNext,
    required this.hasPrevious,
  });

  final List<T> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool first;
  final bool last;
  final bool hasNext;
  final bool hasPrevious;

  /// Parsea el body de la respuesta del backend.
  ///
  /// Lanza [FormatException] si [json] no contiene un `content` de tipo
  /// `List`, en vez de propagar un error de tipo confuso más adelante.
  factory PagedResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> item) fromJsonT,
  ) {
    final dynamic rawContent = json['content'];
    if (rawContent is! List) {
      throw FormatException(
        "PagedResult.fromJson: se esperaba 'content' como List, "
        'recibido ${rawContent.runtimeType}',
      );
    }

    final content = rawContent.map((dynamic item) {
      if (item is! Map) {
        throw FormatException(
          'PagedResult.fromJson: elemento de content no es un Map, '
          'recibido ${item.runtimeType}',
        );
      }
      return fromJsonT(Map<String, dynamic>.from(item));
    }).toList();

    return PagedResult<T>(
      content: content,
      page: _asInt(json['page'], 0),
      size: _asInt(json['size'], content.length),
      totalElements: _asInt(json['totalElements'], content.length),
      totalPages: _asInt(json['totalPages'], content.isEmpty ? 0 : 1),
      first: _asBool(json['first'], _asInt(json['page'], 0) == 0),
      last: _asBool(json['last'], !_asBool(json['hasNext'], false)),
      hasNext: _asBool(json['hasNext'], false),
      hasPrevious: _asBool(json['hasPrevious'], false),
    );
  }

  /// Página vacía útil como estado inicial o de error controlado.
  factory PagedResult.empty({int page = 0, int size = 20}) => PagedResult<T>(
        content: const [],
        page: page,
        size: size,
        totalElements: 0,
        totalPages: 0,
        first: page == 0,
        last: true,
        hasNext: false,
        hasPrevious: page > 0,
      );

  static int _asInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static bool _asBool(dynamic value, bool fallback) {
    if (value is bool) return value;
    return fallback;
  }
}
