import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

// Pantallas placeholder para configurar navegación inicial
import '../../presentation/screens/splash_screen.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/screen_selector.dart';
import '../../presentation/screens/guest/guest_home_screen.dart';
import '../../presentation/screens/guest/guest_flavor_catalog.dart';
import '../../presentation/screens/guest/guest_map_screen.dart';
import '../../presentation/screens/guest/guest_main_screen.dart'; // Nuevo Wrapper

import '../../presentation/screens/member/member_home_screen.dart';
import '../../presentation/screens/member/member_main_screen.dart';
import '../../presentation/screens/member/member_orders_list_screen.dart';
import '../../presentation/screens/member/member_create_order_screen.dart';
import '../../presentation/screens/member/member_profile_screen.dart';
import '../../presentation/screens/host/host_main_screen.dart';
import '../../presentation/screens/host/host_dashboard_screen.dart';
import '../../presentation/screens/host/host_orders_list_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/', // Splash Screen primero
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/screen-selector',
      builder: (context, state) => const ScreenSelector(),
    ),
    // Rutas de Invitado con Shell (BottomNav)
    ShellRoute(
      builder: (context, state, child) {
        return GuestMainScreen(child: child);
      },
      routes: [
         GoRoute(
          path: '/guest-home',
          builder: (context, state) => const GuestHomeScreen(),
        ),
        GoRoute(
          path: '/guest-catalog',
          builder: (context, state) => const GuestFlavorCatalog(),
        ),
        GoRoute(
          path: '/guest-map',
          builder: (context, state) => const GuestMapScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
      ]
    ),
    // Rutas de Miembro con Shell (Barra de Navegación Persistente)
    ShellRoute(
      builder: (context, state, child) {
        return MemberMainScreen(child: child);
      },
      routes: [
        GoRoute(
            path: '/member-home',
            builder: (context, state) => const MemberHomeScreen(),
        ),
        GoRoute(
            path: '/member-orders',
            builder: (context, state) => const MemberOrdersListScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const MemberCreateOrderScreen(),
              ),
            ]
        ),
        GoRoute(
            path: '/member-profile',
            builder: (context, state) => const MemberProfileScreen(),
        ),
      ],
    ),
    // Rutas de Anfitrión con Shell
    ShellRoute(
      builder: (context, state, child) {
        return HostMainScreen(child: child);
      },
      routes: [
        GoRoute(
            path: '/host-dashboard',
            builder: (context, state) => const HostDashboardScreen(),
        ),
        GoRoute(
            path: '/host-orders',
            builder: (context, state) => const HostOrdersListScreen(),
        ),
      ],
    ),
  ],
);
