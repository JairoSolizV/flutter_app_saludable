import 'package:flutter_app_saludable/core/api/api_client.dart';
import 'package:flutter_app_saludable/core/auth/secure_token_store.dart';
import 'package:flutter_app_saludable/core/auth/session_expiration_handler.dart';
import 'package:flutter_app_saludable/core/auth/session_owner.dart';
import 'package:flutter_app_saludable/core/auth/session_state_resetter.dart';
import 'package:flutter_app_saludable/core/auth/session_token_migrator.dart';
import 'package:flutter_app_saludable/core/auth/token_store.dart';
import 'package:flutter_app_saludable/core/auth/pending_verification_store.dart';
import 'package:flutter_app_saludable/core/auth/sqlite_pending_verification_store.dart';
import 'package:flutter_app_saludable/core/database/database_helper.dart';
import 'package:flutter_app_saludable/core/services/connectivity_service.dart';
import 'package:flutter_app_saludable/core/services/sync_service.dart';
import 'package:flutter_app_saludable/core/utils/app_logger.dart';
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

/// Dependencias de infraestructura ya construidas en el bootstrap.
///
/// Inmutable: sin setters ni acceso global `AppDependencies.instance`.
/// Ownership de ciclo de vida: quien crea el grafo (entrypoint / tests) llama
/// [dispose] al destruir el árbol raíz.
class AppDependencies {
  const AppDependencies({
    required this.dbHelper,
    required this.userRepository,
    required this.pendingVerificationStore,
    required this.tokenStore,
    required this.sessionOwner,
    required this.sessionStateResetter,
    required this.sessionExpirationHandler,
    required this.apiClient,
    required this.authRemoteDataSource,
    required this.productRemoteDataSource,
    required this.clubRemoteDataSource,
    required this.membresiaRemoteDataSource,
    required this.orderRemoteDataSource,
    required this.qrRemoteDataSource,
    required this.eventoRemoteDataSource,
    required this.supportRemoteDataSource,
    required this.reportRemoteDataSource,
    required this.ventasDiariasReportDataSource,
    required this.resumenMensualReportDataSource,
    required this.preSocioRemoteDataSource,
    required this.comprasRemoteDataSource,
    required this.saborRemoteDataSource,
    required this.comboRemoteDataSource,
    required this.productRepository,
    required this.orderRepository,
    required this.connectivityService,
    required this.syncService,
  });

  final DatabaseHelper dbHelper;
  final LocalUserRepository userRepository;
  final PendingVerificationStore pendingVerificationStore;
  final TokenStore tokenStore;
  final SessionOwner sessionOwner;
  final SessionStateResetter sessionStateResetter;
  final SessionExpirationHandler sessionExpirationHandler;
  final ApiClient apiClient;

  final AuthRemoteDataSource authRemoteDataSource;
  final ProductRemoteDataSource productRemoteDataSource;
  final ClubRemoteDataSource clubRemoteDataSource;
  final MembresiaRemoteDataSource membresiaRemoteDataSource;
  final OrderRemoteDataSource orderRemoteDataSource;
  final QRRemoteDataSource qrRemoteDataSource;
  final EventoRemoteDataSource eventoRemoteDataSource;
  final SupportRemoteDataSource supportRemoteDataSource;
  final ReportRemoteDataSource reportRemoteDataSource;
  final VentasDiariasReportDataSource ventasDiariasReportDataSource;
  final ResumenMensualReportDataSource resumenMensualReportDataSource;
  final PreSocioRemoteDataSource preSocioRemoteDataSource;
  final ComprasRemoteDataSource comprasRemoteDataSource;
  final SaborRemoteDataSource saborRemoteDataSource;
  final ComboRemoteDataSource comboRemoteDataSource;

  final LocalProductRepository productRepository;
  final LocalOrderRepository orderRepository;
  final ConnectivityService connectivityService;
  final SyncService syncService;

  /// Libera recursos de servicios con listeners (conectividad).
  void dispose() {
    syncService.dispose();
    connectivityService.dispose();
  }

  /// Bootstrap de producción / tests de integración.
  ///
  /// Orden:
  /// 1. DatabaseHelper (perfil local + pedidos offline)
  /// 2. LocalUserRepository (migración JWT legacy)
  /// 3. TokenStore.initialize + migración
  /// 4. SessionOwner / Resetter / ExpirationHandler
  /// 5. ApiClient + remote data sources (mismo Dio)
  /// 6. repositorios híbridos + Connectivity + Sync
  static Future<AppDependencies> bootstrap({
    DatabaseHelper? dbHelper,
    TokenStore? tokenStore,
    ConnectivityService? connectivityService,
  }) async {
    final db = dbHelper ?? DatabaseHelper();
    final users = LocalUserRepository(db);
    final pendingVerificationStore = SqlitePendingVerificationStore(db);
    final tokens = tokenStore ?? SecureTokenStore();
    final owner = SessionOwner();
    final resetter = SessionStateResetter();

    try {
      await tokens.initialize();
      await SessionTokenMigrator(
        tokenStore: tokens,
        userRepository: users,
      ).migrateIfNeeded();
    } catch (_) {
      logDebug(
        '[AppDependencies] No se pudo inicializar almacenamiento seguro / migración',
      );
    }

    final sessionHandler = SessionExpirationHandler(tokenStore: tokens);
    final api = ApiClient(
      tokens,
      sessionExpirationHandler: sessionHandler,
    );
    final dio = api.client;

    final authRemote = AuthRemoteDataSourceImpl(dio);
    final productRemote = ProductRemoteDataSourceImpl(dio);
    final clubRemote = ClubRemoteDataSource(dio);
    final membresiaRemote = MembresiaRemoteDataSourceImpl(dio);
    final orderRemote = OrderRemoteDataSourceImpl(dio);
    final qrRemote = QRRemoteDataSourceImpl(dio);
    final eventoRemote = EventoRemoteDataSourceImpl(dio);
    final supportRemote = SupportRemoteDataSourceImpl(dio);
    final reportRemote = ReportRemoteDataSource(dio);
    final ventasRemote = VentasDiariasReportDataSource(dio);
    final resumenRemote = ResumenMensualReportDataSource(dio);
    final preSocioRemote = PreSocioRemoteDataSourceImpl(dio);
    final comprasRemote = ComprasRemoteDataSourceImpl(dio);
    final saborRemote = SaborRemoteDataSource(dio);
    final comboRemote = ComboRemoteDataSource(dio);

    final productRepo = LocalProductRepository(
      db,
      remoteDataSource: productRemote,
    );
    final orderRepo = LocalOrderRepository(db);

    final connectivity = connectivityService ?? ConnectivityService();
    final sync = SyncService(
      orderRepo,
      connectivity,
      orderRemote,
      owner,
      sessionExpirationHandler: sessionHandler,
    );

    return AppDependencies(
      dbHelper: db,
      userRepository: users,
      pendingVerificationStore: pendingVerificationStore,
      tokenStore: tokens,
      sessionOwner: owner,
      sessionStateResetter: resetter,
      sessionExpirationHandler: sessionHandler,
      apiClient: api,
      authRemoteDataSource: authRemote,
      productRemoteDataSource: productRemote,
      clubRemoteDataSource: clubRemote,
      membresiaRemoteDataSource: membresiaRemote,
      orderRemoteDataSource: orderRemote,
      qrRemoteDataSource: qrRemote,
      eventoRemoteDataSource: eventoRemote,
      supportRemoteDataSource: supportRemote,
      reportRemoteDataSource: reportRemote,
      ventasDiariasReportDataSource: ventasRemote,
      resumenMensualReportDataSource: resumenRemote,
      preSocioRemoteDataSource: preSocioRemote,
      comprasRemoteDataSource: comprasRemote,
      saborRemoteDataSource: saborRemote,
      comboRemoteDataSource: comboRemote,
      productRepository: productRepo,
      orderRepository: orderRepo,
      connectivityService: connectivity,
      syncService: sync,
    );
  }
}
