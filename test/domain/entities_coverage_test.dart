import 'package:flutter_app_saludable/domain/entities/arbol_referidos.dart';
import 'package:flutter_app_saludable/domain/entities/attendance.dart';
import 'package:flutter_app_saludable/domain/entities/club_membership.dart';
import 'package:flutter_app_saludable/domain/entities/combo.dart';
import 'package:flutter_app_saludable/domain/entities/evento.dart';
import 'package:flutter_app_saludable/domain/entities/order_entity.dart';
import 'package:flutter_app_saludable/domain/entities/product.dart';
import 'package:flutter_app_saludable/domain/entities/sabor.dart';
import 'package:flutter_app_saludable/domain/entities/support_ticket.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Product', () {
    test('fromMap con claves en inglés y valores int', () {
      final p = Product.fromMap({
        'id': 5,
        'name': 'Batido',
        'description': 'Rico',
        'price': 12,
        'puntosValor': 3,
        'category': 'Bebidas',
        'imagenUrl': 'foto.png',
        'hubId': 7,
        'clubCreadorId': 2,
        'tipo': 'LOCAL',
        'estadoAprobacion': 'PENDIENTE',
        'active': 1,
        'disponible': 1,
      });

      expect(p.id, '5');
      expect(p.name, 'Batido');
      expect(p.price, 12.0);
      expect(p.puntosValor, 3);
      expect(p.imageUrl, 'foto.png');
      expect(p.hubId, 7);
      expect(p.clubCreadorId, 2);
      expect(p.tipo, 'LOCAL');
      expect(p.estadoAprobacion, 'PENDIENTE');
      expect(p.active, isTrue);
      expect(p.available, isTrue);
    });

    test('fromMap con claves en español y sin disponible usa defaults', () {
      final p = Product.fromMap({
        'id': '9',
        'nombre': 'Té',
        'descripcion': 'Caliente',
      });

      expect(p.id, '9');
      expect(p.name, 'Té');
      expect(p.description, 'Caliente');
      expect(p.category, 'General');
      expect(p.tipo, 'GLOBAL');
      expect(p.estadoAprobacion, 'APROBADO');
      expect(p.active, isFalse);
      expect(p.available, isFalse);
      expect(p.hubId, isNull);
      expect(p.clubCreadorId, isNull);
    });

    test('fromMap resuelve clubCreadorId por variantes de clave', () {
      final p = Product.fromMap({
        'id': 1,
        'name': 'X',
        'description': '',
        'club_id': '42',
      });
      expect(p.clubCreadorId, 42);
    });

    test('toMap serializa booleanos como 0/1 y roundtrip preserva datos', () {
      final original = Product(
        id: '11',
        name: 'Aloe',
        description: 'Fresco',
        puntosValor: 4,
        hubId: 3,
        clubCreadorId: 1,
        tipo: 'LOCAL',
        estadoAprobacion: 'APROBADO',
        active: true,
        available: true,
      );

      final map = original.toMap();
      expect(map['active'], 1);
      expect(map['disponible'], 1);

      final roundTrip = Product.fromMap(map);
      expect(roundTrip.id, original.id);
      expect(roundTrip.name, original.name);
      expect(roundTrip.puntosValor, original.puntosValor);
      expect(roundTrip.hubId, original.hubId);
      expect(roundTrip.tipo, original.tipo);
      expect(roundTrip.active, isTrue);
      expect(roundTrip.available, isTrue);
    });
  });

  group('ComboItem', () {
    test('fromMap/toMap roundtrip con todos los campos', () {
      final item = ComboItem.fromMap({
        'id': 1,
        'productoId': 10,
        'productoNombre': 'Batido',
        'productoImagenUrl': 'img.png',
        'puntosValorProducto': 5,
        'saborId': 2,
        'saborNombre': 'Fresa',
        'cantidad': 3,
      });

      expect(item.id, 1);
      expect(item.productoId, 10);
      expect(item.cantidad, 3);
      expect(item.saborNombre, 'Fresa');

      final map = item.toMap();
      expect(map['productoId'], 10);
      expect(map['cantidad'], 3);
      expect(map['saborNombre'], 'Fresa');
    });

    test('fromMap con productoId como String y cantidad default', () {
      final item = ComboItem.fromMap({
        'productoId': '20',
        'productoNombre': 'Té',
      });
      expect(item.productoId, 20);
      expect(item.cantidad, 1);
      expect(item.id, isNull);
      expect(item.saborId, isNull);
    });

    test('toMap omite campos opcionales nulos', () {
      final item = ComboItem(productoId: 1, productoNombre: 'X');
      final map = item.toMap();
      expect(map.containsKey('id'), isFalse);
      expect(map.containsKey('saborId'), isFalse);
      expect(map.containsKey('saborNombre'), isFalse);
      expect(map['cantidad'], 1);
    });
  });

  group('Combo', () {
    test('fromMap con items anidados', () {
      final combo = Combo.fromMap({
        'id': 7,
        'clubId': 3,
        'clubNombre': 'Club Norte',
        'nombre': 'Combo Familiar',
        'descripcion': 'Para 2',
        'puntosValor': 15,
        'activo': true,
        'items': [
          {'productoId': 1, 'productoNombre': 'Batido', 'cantidad': 2},
          {'productoId': 2, 'productoNombre': 'Te', 'cantidad': 1},
        ],
      });

      expect(combo.id, 7);
      expect(combo.clubId, 3);
      expect(combo.nombre, 'Combo Familiar');
      expect(combo.activo, isTrue);
      expect(combo.items, hasLength(2));
      expect(combo.items.first.productoNombre, 'Batido');
    });

    test('fromMap sin items retorna lista vacía y activo false por defecto', () {
      final combo = Combo.fromMap({
        'id': 1,
        'clubId': 1,
        'nombre': 'Vacío',
      });
      expect(combo.items, isEmpty);
      expect(combo.activo, isFalse);
    });

    test('toMap incluye items serializados', () {
      final combo = Combo(
        clubId: 1,
        nombre: 'Combo',
        items: [ComboItem(productoId: 1, productoNombre: 'Batido', cantidad: 2)],
      );
      final map = combo.toMap();
      expect(map['items'], hasLength(1));
      expect((map['items'] as List).first['productoId'], 1);
    });

    test('copyWith reemplaza solo los campos indicados', () {
      final combo = Combo(id: 1, clubId: 1, nombre: 'Original', puntosValor: 5);
      final copy = combo.copyWith(nombre: 'Actualizado', activo: false);
      expect(copy.nombre, 'Actualizado');
      expect(copy.activo, isFalse);
      expect(copy.id, 1);
      expect(copy.puntosValor, 5);
    });
  });

  group('ClubMembership', () {
    test('fromJson con todos los campos', () {
      final m = ClubMembership.fromJson({
        'id': 1,
        'usuarioId': 10,
        'usuarioNombre': 'Ana',
        'clubId': 2,
        'clubNombre': 'Club Sur',
        'nivelId': 1,
        'nivelNombre': 'Oro',
        'numeroSocio': 'S-001',
        'puntosAcumulados': 100,
        'fechaRegistro': '2024-01-01',
        'estado': 'ACTIVO',
      });

      expect(m.id, 1);
      expect(m.usuarioNombre, 'Ana');
      expect(m.clubNombre, 'Club Sur');
      expect(m.puntosAcumulados, 100);
      expect(m.estado, 'ACTIVO');
    });

    test('fromJson aplica defaults con campos faltantes', () {
      final m = ClubMembership.fromJson({
        'id': 5,
        'usuarioId': 1,
        'clubId': 1,
      });
      expect(m.usuarioNombre, 'Sin Nombre');
      expect(m.clubNombre, '');
      expect(m.nivelId, 0);
      expect(m.nivelNombre, 'Socio');
      expect(m.numeroSocio, '');
      expect(m.puntosAcumulados, 0);
      expect(m.estado, 'ACTIVO');
    });
  });

  group('SupportTicket', () {
    test('fromMap/toMap roundtrip', () {
      final ticket = SupportTicket.fromMap({
        'id': 1,
        'usuarioId': 3,
        'tipoSolicitud': 'Queja',
        'asunto': 'Problema',
        'mensaje': 'Detalle del problema',
        'estado': 'abierto',
        'fechaCreacion': '2024-05-01T10:00:00.000',
        'respuestaAdmin': 'En revisión',
      });

      expect(ticket.userId, 3);
      expect(ticket.estado, 'ABIERTO');
      expect(ticket.respuestaAdmin, 'En revisión');

      final map = ticket.toMap();
      expect(map['usuarioId'], 3);
      expect(map['estado'], 'ABIERTO');

      final roundTrip = SupportTicket.fromMap(map);
      expect(roundTrip.asunto, ticket.asunto);
      expect(roundTrip.mensaje, ticket.mensaje);
    });

    test('fromMap con snake_case y sin fecha usa valores por defecto', () {
      final ticket = SupportTicket.fromMap({
        'id': 2,
        'usuario_id': 9,
        'tipo_solicitud': 'Consulta',
        'asunto': 'Duda',
        'mensaje': 'Mensaje',
      });
      expect(ticket.userId, 9);
      expect(ticket.tipoSolicitud, 'Consulta');
      expect(ticket.estado, 'ABIERTO');
      expect(ticket.respuestaAdmin, isNull);
    });
  });

  group('Attendance', () {
    test('fromJson con datos completos', () {
      final a = Attendance.fromJson({
        'id': 1,
        'membresiaId': 4,
        'membresiaNumeroSocio': 'S-004',
        'clubId': 2,
        'clubNombre': 'Club Este',
        'fechaHora': '2024-01-01T08:00:00',
        'fechaDia': '2024-01-01',
        'estado': 'PRESENTE',
      });

      expect(a.membresiaId, 4);
      expect(a.clubNombre, 'Club Este');
      expect(a.estado, 'PRESENTE');
    });

    test('fromJson con mapa vacío aplica defaults', () {
      final a = Attendance.fromJson({});
      expect(a.id, 0);
      expect(a.membresiaNumeroSocio, '');
      expect(a.estado, '');
    });
  });

  group('Sabor', () {
    test('fromMap interpreta disponible en distintos formatos', () {
      expect(Sabor.fromMap({'id': 1, 'nombre': 'Fresa', 'disponible': true}).disponible, isTrue);
      expect(Sabor.fromMap({'id': 1, 'nombre': 'Fresa', 'disponible': 1}).disponible, isTrue);
      expect(Sabor.fromMap({'id': 1, 'nombre': 'Fresa', 'disponible': '1'}).disponible, isTrue);
      expect(Sabor.fromMap({'id': 1, 'nombre': 'Fresa', 'disponible': 'true'}).disponible, isTrue);
      expect(Sabor.fromMap({'id': 1, 'nombre': 'Fresa', 'disponible': false}).disponible, isFalse);
      expect(Sabor.fromMap({'id': 1, 'nombre': 'Fresa'}).disponible, isFalse);
    });

    test('fromMap con id como String', () {
      final s = Sabor.fromMap({'id': '3', 'nombre': 'Vainilla'});
      expect(s.id, 3);
    });

    test('toMap roundtrip', () {
      final s = Sabor(id: 2, nombre: 'Mango', disponible: true);
      final map = s.toMap();
      final roundTrip = Sabor.fromMap(map);
      expect(roundTrip.id, s.id);
      expect(roundTrip.nombre, s.nombre);
      expect(roundTrip.disponible, s.disponible);
    });
  });

  group('Evento', () {
    test('fromJson con fecha ISO completa', () {
      final e = Evento.fromJson({
        'id': 1,
        'hubId': 1,
        'nombre': 'Torneo',
        'fechaEvento': '2024-06-01T15:30:00Z',
        'descripcion': 'Descripción',
      });
      expect(e.nombre, 'Torneo');
      expect(e.fechaEvento.year, 2024);
      expect(e.fechaEvento.month, 6);
    });

    test('fromJson con fecha solo YYYY-MM-DD', () {
      final e = Evento.fromJson({
        'id': 2,
        'nombre': 'Evento fecha simple',
        'fechaEvento': '2024-03-15',
        'descripcion': '',
      });
      expect(e.fechaEvento.year, 2024);
      expect(e.fechaEvento.month, 3);
      expect(e.fechaEvento.day, 15);
    });

    test('fromJson usa clave "fecha" si "fechaEvento" no existe', () {
      final e = Evento.fromJson({
        'id': 3,
        'nombre': 'Alt',
        'fecha': '2024-07-01',
        'descripcion': '',
      });
      expect(e.fechaEvento.year, 2024);
      expect(e.fechaEvento.month, 7);
    });

    test('fromJson sin fecha usa DateTime.now() sin lanzar', () {
      final before = DateTime.now();
      final e = Evento.fromJson({'id': 4, 'nombre': 'SinFecha', 'descripcion': ''});
      expect(e.fechaEvento.isAfter(before.subtract(const Duration(minutes: 1))), isTrue);
    });

    test('fromJson con timestamp numérico', () {
      final ts = DateTime(2024, 1, 1).millisecondsSinceEpoch;
      final e = Evento.fromJson({
        'id': 5,
        'nombre': 'Timestamp',
        'fechaEvento': ts,
        'descripcion': '',
      });
      expect(e.fechaEvento.year, 2024);
    });
  });

  group('OrderEntity/OrderItem', () {
    test('OrderEntity toMap/fromMap roundtrip', () {
      final createdAt = DateTime(2024, 5, 1, 10, 0);
      final order = OrderEntity(
        id: 'o1',
        userId: 'u1',
        clubId: 3,
        membresiaId: 7,
        tipoConsumo: 'EN_LUGAR',
        observaciones: 'Sin azúcar',
        status: 'pending',
        createdAt: createdAt,
        isSynced: true,
        tiempoEstimadoMinutos: 10,
      );

      final map = order.toMap();
      expect(map['is_synced'], 1);
      expect(map['user_id'], 'u1');

      final roundTrip = OrderEntity.fromMap(map);
      expect(roundTrip.id, 'o1');
      expect(roundTrip.userId, 'u1');
      expect(roundTrip.clubId, 3);
      expect(roundTrip.isSynced, isTrue);
      expect(roundTrip.createdAt, createdAt);
      expect(roundTrip.items, isEmpty);
    });

    test('OrderEntity.fromMap acepta items explícitos', () {
      final map = OrderEntity(
        id: 'o2',
        userId: 'u2',
        status: 'pending',
        createdAt: DateTime(2024, 1, 1),
      ).toMap();

      final item = OrderItem(orderId: 'o2', productId: 'p1', quantity: 2);
      final order = OrderEntity.fromMap(map, items: [item]);
      expect(order.items, hasLength(1));
      expect(order.items.first.productId, 'p1');
    });

    test('OrderItem toMap/fromMap básico', () {
      final item = OrderItem(
        orderId: 'o1',
        productId: 'p1',
        quantity: 3,
        note: 'Extra hielo',
      );
      final map = item.toMap();
      expect(map['quantity'], 3);
      expect(map['note'], 'Extra hielo');

      final roundTrip = OrderItem.fromMap({
        'id': 1,
        'order_id': 'o1',
        'product_id': 'p1',
        'quantity': 3,
        'note': 'Extra hielo',
      }, productName: 'Batido');
      expect(roundTrip.id, '1');
      expect(roundTrip.productName, 'Batido');
      expect(roundTrip.quantity, 3);
    });

    test('OrderItem.fromMap sin note usa cadena vacía', () {
      final item = OrderItem.fromMap({
        'order_id': 'o1',
        'product_id': 'p1',
        'quantity': 1,
      });
      expect(item.note, '');
    });
  });

  group('ArbolReferidos', () {
    test('fromJson sin referidos retorna lista vacía', () {
      final arbol = ArbolReferidos.fromJson({
        'membresiaId': 1,
        'numeroSocio': 'S-1',
        'nombreCompleto': 'Ana',
        'puntosAcumulados': 10,
        'estado': 'ACTIVO',
      });
      expect(arbol.referidos, isEmpty);
      expect(arbol.clubNombre, isNull);
    });

    test('fromJson con referidos anidados recursivos', () {
      final arbol = ArbolReferidos.fromJson({
        'membresiaId': 1,
        'numeroSocio': 'S-1',
        'nombreCompleto': 'Ana',
        'puntosAcumulados': 10,
        'estado': 'ACTIVO',
        'clubNombre': 'Club Centro',
        'referidos': [
          {
            'membresiaId': 2,
            'numeroSocio': 'S-2',
            'nombreCompleto': 'Beto',
            'puntosAcumulados': 5,
            'estado': 'ACTIVO',
            'referidos': [
              {
                'membresiaId': 3,
                'numeroSocio': 'S-3',
                'nombreCompleto': 'Carla',
                'puntosAcumulados': 2,
                'estado': 'ACTIVO',
              }
            ],
          }
        ],
      });

      expect(arbol.referidos, hasLength(1));
      expect(arbol.referidos.first.nombreCompleto, 'Beto');
      expect(arbol.referidos.first.referidos, hasLength(1));
      expect(arbol.referidos.first.referidos.first.nombreCompleto, 'Carla');
    });
  });
}
