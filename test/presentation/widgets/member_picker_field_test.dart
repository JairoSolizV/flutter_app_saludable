import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/core/pagination/paged_result.dart';
import 'package:flutter_app_saludable/domain/entities/club_membership.dart';
import 'package:flutter_app_saludable/presentation/widgets/member_picker_field.dart';
import 'package:flutter_test/flutter_test.dart';

ClubMembership _member({
  required int id,
  required String nombre,
  String numeroSocio = 'S-0001',
  String clubNombre = 'Club Norte',
}) {
  return ClubMembership(
    id: id,
    usuarioId: id,
    usuarioNombre: nombre,
    clubId: 1,
    clubNombre: clubNombre,
    nivelId: 1,
    nivelNombre: 'Bronce',
    numeroSocio: numeroSocio,
    puntosAcumulados: 0,
    fechaRegistro: '2024-01-01',
    estado: 'ACTIVO',
  );
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('MemberPickerField', () {
    testWidgets('sin selección muestra hint y sin socios deshabilita el tap',
        (tester) async {
      ClubMembership? selected;
      await tester.pumpWidget(_wrap(MemberPickerField(
        members: const [],
        selected: selected,
        onChanged: (m) => selected = m,
      )));

      expect(find.text('No hay socios en este club'), findsWidgets);

      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();

      // No debe abrirse el bottom sheet porque no hay socios ni búsqueda global.
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('con socios abre el picker y permite seleccionar uno',
        (tester) async {
      ClubMembership? selected;
      final members = [
        _member(id: 1, nombre: 'Ana'),
        _member(id: 2, nombre: 'Beto', numeroSocio: 'S-0002'),
      ];

      await tester.pumpWidget(StatefulBuilder(
        builder: (context, setState) => _wrap(MemberPickerField(
          members: members,
          selected: selected,
          onChanged: (m) => setState(() => selected = m),
        )),
      ));

      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();

      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Beto'), findsOneWidget);

      await tester.tap(find.text('Beto'));
      await tester.pumpAndSettle();

      expect(selected?.id, 2);
      expect(find.textContaining('Beto'), findsOneWidget);
    });

    testWidgets('muestra botón de limpiar cuando hay selección',
        (tester) async {
      final member = _member(id: 1, nombre: 'Ana');
      ClubMembership? selected = member;

      await tester.pumpWidget(StatefulBuilder(
        builder: (context, setState) => _wrap(MemberPickerField(
          members: [member],
          selected: selected,
          onChanged: (m) => setState(() => selected = m),
        )),
      ));

      expect(find.byIcon(Icons.clear), findsOneWidget);

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      expect(selected, isNull);
    });

    testWidgets('deshabilitado no responde al tap', (tester) async {
      final members = [_member(id: 1, nombre: 'Ana')];
      bool tapped = false;

      await tester.pumpWidget(_wrap(MemberPickerField(
        members: members,
        selected: null,
        onChanged: (_) => tapped = true,
        enabled: false,
      )));

      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(tapped, isFalse);
    });

    testWidgets('filtra localmente al escribir en el buscador',
        (tester) async {
      final members = [
        _member(id: 1, nombre: 'Ana'),
        _member(id: 2, nombre: 'Beto'),
      ];

      await tester.pumpWidget(_wrap(MemberPickerField(
        members: members,
        selected: null,
        onChanged: (_) {},
      )));

      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'an');
      await tester.pumpAndSettle();

      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Beto'), findsNothing);
    });

    testWidgets('sin resultados locales ni globales muestra mensaje vacío',
        (tester) async {
      final members = [_member(id: 1, nombre: 'Ana')];

      await tester.pumpWidget(_wrap(MemberPickerField(
        members: members,
        selected: null,
        onChanged: (_) {},
      )));

      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pumpAndSettle();

      expect(find.text('No se encontraron socios'), findsOneWidget);
    });

    testWidgets('con búsqueda global muestra sección "Todos los clubes"',
        (tester) async {
      final members = [_member(id: 1, nombre: 'Ana')];

      Future<PagedResult<ClubMembership>> search(String query, int page) async {
        return PagedResult<ClubMembership>(
          content: [
            _member(id: 100, nombre: 'Global Carla', clubNombre: 'Club Sur'),
          ],
          page: page,
          size: 20,
          totalElements: 1,
          totalPages: 1,
          first: true,
          last: true,
          hasNext: false,
          hasPrevious: false,
        );
      }

      await tester.pumpWidget(_wrap(MemberPickerField(
        members: members,
        selected: null,
        onChanged: (_) {},
        enableGlobalSearch: true,
        onGlobalSearch: search,
      )));

      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'carla');
      // Esperar el debounce de 400ms.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('Todos los clubes'), findsOneWidget);
      expect(find.textContaining('Global Carla'), findsOneWidget);
    });

    testWidgets('búsqueda global que falla no crashea', (tester) async {
      Future<PagedResult<ClubMembership>> failingSearch(
          String query, int page) async {
        throw Exception('network error');
      }

      await tester.pumpWidget(_wrap(MemberPickerField(
        members: const [],
        selected: null,
        onChanged: (_) {},
        enableGlobalSearch: true,
        onGlobalSearch: failingSearch,
      )));

      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'x');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('No se encontraron socios'), findsOneWidget);
    });
  });
}
