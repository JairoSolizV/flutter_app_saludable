import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/presentation/screens/guest/guest_home_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// PNG 1×1 transparente.
const List<int> _kTransparentImage = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

class _FakeHttpClient implements HttpClient {
  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _FakeHttpClientRequest();

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _FakeHttpClientRequest();

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientRequest implements HttpClientRequest {
  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  Future<HttpClientResponse> close() async => _FakeHttpClientResponse();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpHeaders implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  @override
  int get statusCode => HttpStatus.ok;

  @override
  int get contentLength => _kTransparentImage.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_kTransparentImage]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeHttpClient();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> runGuestHomeTest(
    WidgetTester tester,
    Future<void> Function() body, {
    double width = 390,
  }) async {
    final previousOverrides = HttpOverrides.current;
    HttpOverrides.global = _TestHttpOverrides();
    debugNetworkImageHttpClientProvider = _FakeHttpClient.new;

    try {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const GuestHomeScreen(),
          ),
          GoRoute(
            path: '/register',
            builder: (_, __) => const Scaffold(body: Text('Register')),
          ),
        ],
      );

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: Size(width, 800)),
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await body();
    } finally {
      // Debe resetearse ANTES de _verifyInvariants del binding.
      debugNetworkImageHttpClientProvider = null;
      HttpOverrides.global = previousOverrides;
    }
  }

  testWidgets('GuestHome muestra Bienvenido y Santa Cruz', (tester) async {
    await runGuestHomeTest(tester, () async {
      expect(find.text('Bienvenido'), findsOneWidget);
      expect(find.text('Hola, Invitado'), findsNothing);
      expect(find.text('Santa Cruz'), findsOneWidget);
    });
  });

  testWidgets('GuestHome ya no muestra secciones hardcodeadas', (tester) async {
    await runGuestHomeTest(tester, () async {
      expect(find.text('Consejos Diarios'), findsNothing);
      expect(find.text('5 Beneficios del Té Verde'), findsNothing);
      expect(find.text('Próximos Eventos'), findsNothing);
      expect(find.text('Día de Entrenamiento Fit'), findsNothing);
    });
  });

  testWidgets('GuestHome conserva Hero y Crear Cuenta', (tester) async {
    await runGuestHomeTest(tester, () async {
      expect(find.text('Crear Cuenta'), findsOneWidget);
      expect(find.textContaining('Descubre tu'), findsOneWidget);
    });
  });

  testWidgets('GuestHome no produce overflow en ancho angosto', (tester) async {
    FlutterErrorDetails? overflow;
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      final msg = details.toString();
      if (msg.contains('A RenderFlex overflowed') ||
          msg.contains('overflowed by')) {
        overflow = details;
      }
      previous?.call(details);
    };

    try {
      await runGuestHomeTest(tester, () async {
        expect(overflow, isNull);
        expect(find.text('Bienvenido'), findsOneWidget);
        expect(find.text('Crear Cuenta'), findsOneWidget);
        expect(find.text('Próximos Eventos'), findsNothing);
      }, width: 320);
    } finally {
      FlutterError.onError = previous;
    }
  });
}
