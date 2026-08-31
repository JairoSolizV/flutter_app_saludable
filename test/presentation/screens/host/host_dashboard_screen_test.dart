import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/data/datasources/remote/club_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/order_remote_data_source.dart';
import 'package:flutter_app_saludable/presentation/screens/host/host_dashboard_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Club _testClub() => Club(
      id: 1,
      hubId: 10,
      hubNombre: 'Hub Test',
      anfitrionId: 1,
      anfitrionNombre: 'Ana',
      nombreClub: 'Club Test',
      direccion: 'Dir',
      horario: '8-18',
      lat: 0,
      lng: 0,
      estado: 'ACTIVO',
    );

class _PendingClubDs extends ClubRemoteDataSource {
  _PendingClubDs(this._completer) : super(Dio());

  final Completer<Club?> _completer;

  @override
  Future<Club?> getMyClub() => _completer.future;
}

class _ImmediateClubDs extends ClubRemoteDataSource {
  _ImmediateClubDs(this.club) : super(Dio());

  final Club? club;

  @override
  Future<Club?> getMyClub() async => club;
}

class _TrackingOrderDs implements OrderRemoteDataSource {
  int getOrdersByClubCalls = 0;
  List<Map<String, dynamic>> orders = const [];

  @override
  Future<List<Map<String, dynamic>>> getOrdersByClub(int clubId) async {
    getOrdersByClubCalls++;
    return orders;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _buildDashboard({
  required ClubRemoteDataSource clubDs,
  required OrderRemoteDataSource orderDs,
}) {
  return MultiProvider(
    providers: [
      Provider<ClubRemoteDataSource>.value(value: clubDs),
      Provider<OrderRemoteDataSource>.value(value: orderDs),
    ],
    child: const MaterialApp(home: HostDashboardScreen()),
  );
}

void main() {
  group('HostDashboardScreen._loadOrdersSummary', () {
    testWidgets(
      'dispose durante getMyClub no lanza ni llama getOrdersByClub',
      (tester) async {
        final completer = Completer<Club?>();
        final clubDs = _PendingClubDs(completer);
        final orderDs = _TrackingOrderDs();

        await tester.pumpWidget(_buildDashboard(clubDs: clubDs, orderDs: orderDs));
        await tester.pump();

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();

        completer.complete(_testClub());
        await tester.pumpAndSettle();

        expect(orderDs.getOrdersByClubCalls, 0);
      },
    );

    testWidgets('flujo normal actualiza resumen de pedidos', (tester) async {
      final clubDs = _ImmediateClubDs(_testClub());
      final orderDs = _TrackingOrderDs()
        ..orders = [
          {'estado': 'RECIBIDO'},
          {'estado': 'PREPARANDO'},
          {'estado': 'LISTO'},
          {'estado': 'ENTREGADO'},
        ];

      await tester.pumpWidget(_buildDashboard(clubDs: clubDs, orderDs: orderDs));
      await tester.pumpAndSettle();

      expect(orderDs.getOrdersByClubCalls, 1);
      expect(find.text('Club Test'), findsOneWidget);
      expect(find.text('1 Recibido'), findsOneWidget);
      expect(find.text('1 Preparando'), findsOneWidget);
      expect(find.text('1 Listo'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });
  });
}
