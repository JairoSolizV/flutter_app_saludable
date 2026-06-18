import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app_saludable/presentation/widgets/refreshable_scroll_view.dart';

void main() {
  group('RefreshableScrollView', () {
    testWidgets('renderiza el child', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RefreshableScrollView(
              onRefresh: () async {},
              child: const Text('Sin datos'),
            ),
          ),
        ),
      );
      expect(find.text('Sin datos'), findsOneWidget);
    });

    testWidgets('invoca onRefresh al deslizar hacia abajo', (tester) async {
      var called = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RefreshableScrollView(
              onRefresh: () async {
                called = true;
              },
              child: const Text('Sin datos'),
            ),
          ),
        ),
      );

      await tester.fling(find.text('Sin datos'), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      expect(called, isTrue);
    });
  });
}
