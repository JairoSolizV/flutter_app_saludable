import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/product.dart';

// Pantallas placeholder para configurar navegación inicial
import '../../presentation/screens/splash_screen.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/register_screen.dart'; // Add import
import '../../presentation/screens/auth/email_verification_screen.dart'; // Verificación email
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
import '../../presentation/screens/member/member_select_club_screen.dart';
import '../../presentation/screens/member/member_club_products_screen.dart';
import '../../presentation/screens/member/member_profile_screen.dart';
import '../../presentation/screens/member/attendance/member_attendance_screen.dart';
import '../../presentation/screens/member/qrcode/member_qr_scan_screen.dart'; // Added
import '../../presentation/screens/member/request_club_screen.dart'; // Added
import '../../presentation/screens/member/club_selector_screen.dart'; // New
import '../../presentation/screens/member/member_products_screen.dart'; // New
import '../../presentation/screens/host/qrcode/host_qr_display_screen.dart'; // Added
import '../../presentation/screens/host/host_main_screen.dart';
import '../../presentation/screens/host/host_dashboard_screen.dart';
import '../../presentation/screens/host/host_orders_list_screen.dart';
import '../../presentation/screens/host/host_scan_screen.dart';
import '../../presentation/screens/host/products/host_product_list_screen.dart';
import '../../presentation/screens/host/products/host_edit_product_screen.dart';
import '../../presentation/screens/host/products/host_product_proposal_screen.dart';
import '../../presentation/screens/host/members/host_members_list_screen.dart';
import '../../presentation/screens/host/members/host_member_registration_screen.dart';
import '../../presentation/screens/host/host_profile_screen.dart';
import '../../presentation/screens/host/host_reports_screen.dart';
import '../../presentation/screens/events/events_list_screen.dart';
import '../../presentation/screens/common/support_center_screen.dart'; // Nuevo
import '../../presentation/screens/host/members/host_member_detail_screen.dart';
import '../../presentation/screens/host/members/host_register_purchase_screen.dart';
import '../../presentation/screens/host/members/host_referral_tree_screen.dart';
import '../../presentation/screens/host/pre_socios/host_pre_socio_create_screen.dart';
import '../../presentation/screens/host/pre_socios/host_pre_socio_detail_screen.dart';
import '../../presentation/screens/host/pre_socios/host_mision_create_screen.dart';



final appRouter = GoRouter(
  initialLocation: '/', // Splash Screen primero
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    // Solo disponible en builds de depuración (VULN-FL-03)
    if (kDebugMode)
      GoRoute(
        path: '/screen-selector',
        builder: (context, state) => const ScreenSelector(),
      ),
    GoRoute(
      path: '/support',
      builder: (context, state) => const SupportCenterScreen(),
    ),
    // Ruta de verificación de email (fuera de Shell, pantalla completa)
    GoRoute(
      path: '/verify-email',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final extraEmail = extra?['email'] as String?;
        return EmailVerificationScreen(email: extraEmail);
      },
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
                builder: (context, state) => const MemberSelectClubScreen(),
                routes: [
                  GoRoute(
                    path: 'club-products',
                    builder: (context, state) {
                      final extra = state.extra as Map<String, dynamic>;
                      return MemberClubProductsScreen(
                        clubId: extra['clubId'] as int,
                        clubNombre: extra['clubNombre'] as String,
                      );
                    },
                  ),
                ],
              ),
              // Mantener ruta legacy para compatibilidad
              GoRoute(
                path: 'legacy',
                builder: (context, state) => const MemberCreateOrderScreen(),
              ),
            ]
        ),
        GoRoute(
            path: '/member-profile',
            builder: (context, state) => const MemberProfileScreen(),
        ),
        GoRoute(
            path: '/member-attendance',
            builder: (context, state) => MemberAttendanceScreen(),
        ),
        GoRoute(
          path: '/member-qr-scan',
          builder: (context, state) => const MemberQrScanScreen(),
        ),
        GoRoute(
          path: '/member-club-selector',
          builder: (context, state) => const ClubSelectorScreen(),
        ),
        GoRoute(
          path: '/member-request-club',
          builder: (context, state) => const RequestClubScreen(),
        ),
        GoRoute(
          path: '/member-events',
          builder: (context, state) => const EventsListScreen(),
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
             path: '/host-qr-display',
             builder: (context, state) {
               final extra = state.extra as Map<String, dynamic>;
               return HostQrDisplayScreen(
                 clubId: extra['clubId'], 
                 clubName: extra['clubName']
               );
             },
        ),
        GoRoute(
            path: '/host-orders',
            builder: (context, state) => const HostOrdersListScreen(),
        ),
        GoRoute(
          path: '/host-scan',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            return HostScanScreen(
              preSocioId: extra?['preSocioId'] as int?,
              prefilledReferralId: extra?['prefilledReferralId'] as int?,
            );
          },
        ),
        GoRoute(
          path: '/host-members',
          builder: (context, state) => const HostMembersListScreen(),
        ),
        GoRoute(
          path: '/host-register-member',
          builder: (context, state) {
            final extras = state.extra as Map<String, dynamic>;
            return HostMemberRegistrationScreen(
              qrPayload: extras['qrPayload'] as String,
              clubId: extras['clubId'] as int,
              preSocioId: extras['preSocioId'] as int?,
              prefilledReferralId: extras['prefilledReferralId'] as int?,
            );
          },
        ),
        GoRoute(
          path: '/host-profile',
          builder: (context, state) => const HostProfileScreen(),
        ),
        GoRoute(
          path: '/host/reports',
          builder: (context, state) => const HostReportsScreen(),
        ),
        GoRoute(
          path: '/events',
          builder: (context, state) => const EventsListScreen(),
        ),
        GoRoute(
          path: '/host/members/:membresiaId',
          builder: (context, state) {
            final membresiaId = int.parse(state.pathParameters['membresiaId']!);
            final extra = state.extra as Map<String, dynamic>?;
            return HostMemberDetailScreen(
              membresiaId: membresiaId,
              memberName: extra?['memberName'] as String? ?? '',
            );
          },
          routes: [
            GoRoute(
              path: 'purchases/new',
              builder: (context, state) {
                final membresiaId = int.parse(state.pathParameters['membresiaId']!);
                final extra = state.extra as Map<String, dynamic>;
                return HostRegisterPurchaseScreen(
                  membresiaId: membresiaId,
                  clubId: extra['clubId'] as int,
                );
              },
            ),
            GoRoute(
              path: 'referral-tree',
              builder: (context, state) {
                final membresiaId = int.parse(state.pathParameters['membresiaId']!);
                final extra = state.extra as Map<String, dynamic>?;
                return HostReferralTreeScreen(
                  membresiaId: membresiaId,
                  memberName: extra?['memberName'] as String? ?? '',
                );
              },
            ),
          ],
        ),
        GoRoute(
          path: '/host/pre-socios/new',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>;
            return HostPreSocioCreateScreen(clubId: extra['clubId'] as int);
          },
        ),
        GoRoute(
          path: '/host/pre-socios/:preSocioId',
          builder: (context, state) {
            final preSocioId = int.parse(state.pathParameters['preSocioId']!);
            final extra = state.extra as Map<String, dynamic>;
            return HostPreSocioDetailScreen(
              preSocioId: preSocioId,
              clubId: extra['clubId'] as int,
            );
          },
          routes: [
            GoRoute(
              path: 'misiones/new',
              builder: (context, state) {
                final preSocioId = int.parse(state.pathParameters['preSocioId']!);
                return HostMisionCreateScreen(preSocioId: preSocioId);
              },
            ),
          ],
        ),
        GoRoute(
          path: '/host/products',
          builder: (context, state) => const HostProductListScreen(),
          routes: [
            GoRoute(
              path: 'proposal',
              builder: (context, state) => const HostProductProposalScreen(),
            ),
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
    GoRoute(
      path: '/request-club',
      builder: (context, state) => const RequestClubScreen(),
    ),
    // Ruta de Productos por Club para Miembros (Fuera de Shell)
    GoRoute(
      path: '/member/products/:clubId',
      builder: (context, state) {
        final clubId = state.pathParameters['clubId']!;
        final club = state.extra as Club?;
        return MemberProductsScreen(clubId: clubId, club: club);
      },
    ),
  ],
);
