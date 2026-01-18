import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import '../../domain/entities/product.dart';

// Pantallas placeholder para configurar navegación inicial
import '../../presentation/screens/splash_screen.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/register_screen.dart'; // Add import
import '../../presentation/screens/screen_selector.dart';
import '../../presentation/screens/guest/guest_home_screen.dart';
import '../../presentation/screens/guest/guest_flavor_catalog.dart';
import '../../presentation/screens/guest/guest_map_screen.dart';
import '../../presentation/screens/guest/guest_main_screen.dart';
import '../../presentation/screens/guest/guest_club_detail_screen.dart'; // Nuevo
import '../../presentation/screens/member/basic_user_home_screen.dart'; // Basic User
import '../../presentation/screens/member/basic_user_profile_screen.dart'; // Basic User Profile
import '../../presentation/screens/member/basic_user_edit_profile_screen.dart'; // Basic User Edit Profile
import '../../data/datasources/remote/club_remote_data_source.dart'; // Modelo Club

import '../../presentation/screens/member/basic_user_main_screen.dart'; // Basic User Shell
import '../../presentation/screens/member/member_home_screen.dart';
import '../../presentation/screens/member/member_main_screen.dart';
import '../../presentation/screens/member/member_orders_list_screen.dart';
import '../../presentation/screens/member/member_create_order_screen.dart';
import '../../presentation/screens/member/member_profile_screen.dart';
import '../../presentation/screens/host/host_main_screen.dart';
import '../../presentation/screens/host/host_dashboard_screen.dart';
import '../../presentation/screens/host/host_orders_list_screen.dart';
import '../../presentation/screens/host/host_scan_screen.dart';
import '../../presentation/screens/host/products/host_product_list_screen.dart';
import '../../presentation/screens/host/products/host_edit_product_screen.dart';
import '../../presentation/screens/host/members/host_members_list_screen.dart';
import '../../presentation/screens/host/host_profile_screen.dart';



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
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
      ]
    ),
    // Rutas de Usuario Básico con Shell
    ShellRoute(
      builder: (context, state, child) {
        return BasicUserMainScreen(child: child);
      },
      routes: [
         GoRoute(
          path: '/basic-home',
          builder: (context, state) => const BasicUserHomeScreen(),
        ),
        GoRoute(
          path: '/basic-map',
          builder: (context, state) => const GuestMapScreen(),
        ),
        GoRoute(
          path: '/basic-profile',
          builder: (context, state) => const BasicUserProfileScreen(),
          routes: [
            GoRoute(
              path: 'edit',
              builder: (context, state) => const BasicUserEditProfileScreen(),
            ),
          ]
        ),
      ]
    ),
    // Rutas de Miembro con Shell
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
        GoRoute(
          path: '/host-scan',
          builder: (context, state) => const HostScanScreen(),
        ),
        GoRoute(
          path: '/host-members',
          builder: (context, state) => const HostMembersListScreen(),
        ),
        GoRoute(
          path: '/host-profile',
          builder: (context, state) => const HostProfileScreen(),
        ),
        GoRoute(
          path: '/host/products',
          builder: (context, state) => const HostProductListScreen(),
          routes: [
            GoRoute(
              path: 'new',
              builder: (context, state) {
                final clubId = state.extra as int;
                return HostEditProductScreen(clubId: clubId);
              },
            ),
            GoRoute(
              path: 'edit',
              builder: (context, state) {
                final extras = state.extra as Map<String, dynamic>;
                final clubId = extras['clubId'] as int;
                final product = extras['product'] as Product?;
                return HostEditProductScreen(clubId: clubId, product: product);
              },
            ),
          ],
        ),
      ],
    ),
    // Ruta de Detalle de Club (Fuera de Shell para pantalla completa)
    GoRoute(
      path: '/club-detail',
      builder: (context, state) {
        final club = state.extra as Club;
        return GuestClubDetailScreen(club: club);
      },
    ),
  ],
);
