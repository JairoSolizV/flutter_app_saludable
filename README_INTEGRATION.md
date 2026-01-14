# Flutter App Saludable - Guía de Integración

Este proyecto copia la versión `1.0.0+1` diseñada según los mockups. Implementa los roles: Guest, Member, Host y soporta capacidad Offline.

## Arquitectura

- **Framework**: Flutter (M3)
- **Estado**: Provider
- **Navegación**: GoRouter
- **Base de Datos**: Sqflite (SQLite)

## Ejecución

1.  `flutter pub get`
2.  `flutter run`

## Modo Offline (Implementado)
Al iniciar la app, se crea la base de datos local `nutrilife_club.db`. El método `_seedData` en `DatabaseHelper` inserta productos de ejemplo automáticamente.
La pantalla `GuestFlavorCatalog` lee estos productos usando `LocalProductRepository`, por lo que funciona sin internet.

## Próximos Pasos (Backend)
Cuando la API backend esteja lista:
1.  Modificar `ProductRepository` para intentar leer de la API primero.
2.  Implementar `auth_provider` real con endpoints `/login`.
3.  Implementar mecanismo de sincronización para enviar los pedidos guardados en la tabla `orders` (columna `is_synced`).
