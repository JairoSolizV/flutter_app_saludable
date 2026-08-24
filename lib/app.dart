import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app_saludable/core/api/api_client.dart';
import 'package:flutter_app_saludable/core/auth/session_expiration_handler.dart';
import 'package:flutter_app_saludable/core/auth/session_owner.dart';
import 'package:flutter_app_saludable/core/auth/session_state_resetter.dart';
import 'package:flutter_app_saludable/core/auth/token_store.dart';
import 'package:flutter_app_saludable/core/database/database_helper.dart';
import 'package:flutter_app_saludable/core/di/app_dependencies.dart';
import 'package:flutter_app_saludable/core/router/app_router.dart';
import 'package:flutter_app_saludable/core/services/connectivity_service.dart';
import 'package:flutter_app_saludable/core/services/sync_service.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';
import 'package:flutter_app_saludable/core/ui/session_feedback.dart';
import 'package:flutter_app_saludable/data/datasources/remote/auth_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/club_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/combo_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/compras_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/evento_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/membresia_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/order_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/pre_socio_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/product_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/qr_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/report_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/resumen_mensual_report_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/sabor_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/support_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/ventas_diarias_report_data_source.dart';
import 'package:flutter_app_saludable/data/repositories/local_order_repository.dart';
import 'package:flutter_app_saludable/data/repositories/local_product_repository.dart';
import 'package:flutter_app_saludable/data/repositories/local_user_repository.dart';
import 'package:flutter_app_saludable/domain/repositories/order_repository.dart';
import 'package:flutter_app_saludable/domain/repositories/product_repository.dart';
import 'package:flutter_app_saludable/domain/repositories/user_repository.dart';
import 'package:flutter_app_saludable/presentation/providers/auth_provider.dart';
import 'package:flutter_app_saludable/presentation/providers/counter_sale_provider.dart';
import 'package:flutter_app_saludable/presentation/providers/order_provider.dart';
import 'package:flutter_app_saludable/presentation/providers/product_provider.dart';
import 'package:flutter_app_saludable/presentation/providers/support_provider.dart';
import 'package:flutter_app_saludable/presentation/providers/user_provider.dart';
import 'package:go_router/go_router.dart';

/// Widget raíz de la app: recibe dependencias por constructor (sin globals).
class NutriLifeApp extends StatefulWidget {
  const NutriLifeApp({
    super.key,
    required this.dependencies,
    this.router,
  });

  final AppDependencies dependencies;

  /// Router inyectable (tests). Por defecto usa [appRouter] único de configuración.
  final GoRouter? router;

  @override
  State<NutriLifeApp> createState() => _NutriLifeAppState();
}

class _NutriLifeAppState extends State<NutriLifeApp> {
  @override
  void dispose() {
    widget.dependencies.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deps = widget.dependencies;
    final resetter = deps.sessionStateResetter;

    return MultiProvider(
      providers: [
        Provider<AppDependencies>.value(value: deps),
        Provider<DatabaseHelper>.value(value: deps.dbHelper),
        Provider<TokenStore>.value(value: deps.tokenStore),
        Provider<SessionOwner>.value(value: deps.sessionOwner),
        Provider<SessionStateResetter>.value(value: resetter),
        Provider<SessionExpirationHandler>.value(
          value: deps.sessionExpirationHandler,
        ),
        Provider<ApiClient>.value(value: deps.apiClient),
        Provider<LocalUserRepository>.value(value: deps.userRepository),
        Provider<UserRepository>.value(value: deps.userRepository),
        Provider<LocalProductRepository>.value(value: deps.productRepository),
        Provider<ProductRepository>.value(value: deps.productRepository),
        Provider<LocalOrderRepository>.value(value: deps.orderRepository),
        Provider<OrderRepository>.value(value: deps.orderRepository),
        Provider<ConnectivityService>.value(
          value: deps.connectivityService,
        ),
        Provider<SyncService>.value(value: deps.syncService),
        Provider<AuthRemoteDataSource>.value(
          value: deps.authRemoteDataSource,
        ),
        Provider<ClubRemoteDataSource>.value(
          value: deps.clubRemoteDataSource,
        ),
        Provider<MembresiaRemoteDataSource>.value(
          value: deps.membresiaRemoteDataSource,
        ),
        Provider<OrderRemoteDataSource>.value(
          value: deps.orderRemoteDataSource,
        ),
        Provider<QRRemoteDataSource>.value(value: deps.qrRemoteDataSource),
        Provider<ProductRemoteDataSource>.value(
          value: deps.productRemoteDataSource,
        ),
        Provider<EventoRemoteDataSource>.value(
          value: deps.eventoRemoteDataSource,
        ),
        Provider<SupportRemoteDataSource>.value(
          value: deps.supportRemoteDataSource,
        ),
        Provider<ReportRemoteDataSource>.value(
          value: deps.reportRemoteDataSource,
        ),
        Provider<VentasDiariasReportDataSource>.value(
          value: deps.ventasDiariasReportDataSource,
        ),
        Provider<ResumenMensualReportDataSource>.value(
          value: deps.resumenMensualReportDataSource,
        ),
        Provider<PreSocioRemoteDataSource>.value(
          value: deps.preSocioRemoteDataSource,
        ),
        Provider<ComprasRemoteDataSource>.value(
          value: deps.comprasRemoteDataSource,
        ),
        Provider<SaborRemoteDataSource>.value(
          value: deps.saborRemoteDataSource,
        ),
        Provider<ComboRemoteDataSource>.value(
          value: deps.comboRemoteDataSource,
        ),
        ChangeNotifierProvider(
          create: (_) {
            final p = ProductProvider(deps.productRepository);
            resetter.register(p);
            return p;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final p = OrderProvider(
              deps.orderRepository,
              deps.connectivityService,
              deps.syncService,
            );
            resetter.register(p);
            return p;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final p = UserProvider(deps.userRepository);
            resetter.register(p);
            return p;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final p = CounterSaleProvider(
              deps.productRemoteDataSource,
              deps.orderRemoteDataSource,
              deps.comboRemoteDataSource,
            );
            resetter.register(p);
            return p;
          },
        ),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            deps.authRemoteDataSource,
            deps.userRepository,
            deps.tokenStore,
            pendingVerificationStore: deps.pendingVerificationStore,
            sessionExpirationHandler: deps.sessionExpirationHandler,
            sessionOwner: deps.sessionOwner,
            sessionStateResetter: resetter,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) {
            final p = SupportProvider(
              deps.supportRemoteDataSource,
              deps.userRepository,
            );
            resetter.register(p);
            return p;
          },
        ),
      ],
      child: SessionBinding(
        child: MainApp(router: widget.router),
      ),
    );
  }
}

/// Enlaza AuthProvider al [SessionExpirationHandler] sin ciclo ApiClient↔Auth.
class SessionBinding extends StatefulWidget {
  const SessionBinding({super.key, required this.child});

  final Widget child;

  @override
  State<SessionBinding> createState() => _SessionBindingState();
}

class _SessionBindingState extends State<SessionBinding> {
  int? _bindGeneration;
  SessionExpirationHandler? _handler;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final handler = context.read<SessionExpirationHandler>();
    _handler = handler;
    _bindGeneration = handler.bind(
      clearLocalSession: () async {
        await auth.clearLocalSessionForExpiration();
      },
      onSessionExpiredUi: () async {
        await navigateToPublicAfterSessionExpiry();
        SessionFeedback.showSessionExpiredMessage();
      },
    );
  }

  @override
  void dispose() {
    final gen = _bindGeneration;
    final handler = _handler;
    if (gen != null && handler != null) {
      handler.unbind(gen);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class MainApp extends StatelessWidget {
  const MainApp({super.key, this.router});

  final GoRouter? router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Expande',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      scaffoldMessengerKey: SessionFeedback.messengerKey,
      routerConfig: router ?? appRouter,
    );
  }
}
