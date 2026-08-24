import 'package:flutter_app_saludable/core/api/api_client.dart';
import 'package:flutter_app_saludable/core/auth/secure_token_store.dart';
import 'package:flutter_app_saludable/core/auth/session_expiration_handler.dart';
import 'package:flutter_app_saludable/core/auth/session_owner.dart';
import 'package:flutter_app_saludable/core/auth/session_state_resetter.dart';
import 'package:flutter_app_saludable/core/di/app_dependencies.dart';
import 'package:flutter_app_saludable/core/services/connectivity_service.dart';
import 'package:flutter_app_saludable/core/services/sync_service.dart';
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
import 'package:flutter_app_saludable/core/auth/sqlite_pending_verification_store.dart';
import 'package:flutter_app_saludable/data/repositories/local_user_repository.dart';

import '../core/auth/in_memory_secure_storage_gateway.dart';
import 'isolated_test_database.dart';

/// Construye [AppDependencies] sin Keychain/red reales.
Future<AppDependencies> buildTestDependencies() async {
  final db = await openIsolatedTestDatabase();
  final users = LocalUserRepository(db);
  final tokens = SecureTokenStore(storage: InMemorySecureStorageGateway());
  await tokens.initialize();

  final owner = SessionOwner();
  final resetter = SessionStateResetter();
  final sessionHandler = SessionExpirationHandler(tokenStore: tokens);
  final api = ApiClient(tokens, sessionExpirationHandler: sessionHandler);
  final dio = api.client;

  final productRemote = ProductRemoteDataSourceImpl(dio);
  final orderRemote = OrderRemoteDataSourceImpl(dio);
  final orderRepo = LocalOrderRepository(db);
  final connectivity = ConnectivityService.forTest(
    checkConnection: () async => false,
  );

  return AppDependencies(
    dbHelper: db,
    userRepository: users,
    pendingVerificationStore: SqlitePendingVerificationStore(db),
    tokenStore: tokens,
    sessionOwner: owner,
    sessionStateResetter: resetter,
    sessionExpirationHandler: sessionHandler,
    apiClient: api,
    authRemoteDataSource: AuthRemoteDataSourceImpl(dio),
    productRemoteDataSource: productRemote,
    clubRemoteDataSource: ClubRemoteDataSource(dio),
    membresiaRemoteDataSource: MembresiaRemoteDataSourceImpl(dio),
    orderRemoteDataSource: orderRemote,
    qrRemoteDataSource: QRRemoteDataSourceImpl(dio),
    eventoRemoteDataSource: EventoRemoteDataSourceImpl(dio),
    supportRemoteDataSource: SupportRemoteDataSourceImpl(dio),
    reportRemoteDataSource: ReportRemoteDataSource(dio),
    ventasDiariasReportDataSource: VentasDiariasReportDataSource(dio),
    resumenMensualReportDataSource: ResumenMensualReportDataSource(dio),
    preSocioRemoteDataSource: PreSocioRemoteDataSourceImpl(dio),
    comprasRemoteDataSource: ComprasRemoteDataSourceImpl(dio),
    saborRemoteDataSource: SaborRemoteDataSource(dio),
    comboRemoteDataSource: ComboRemoteDataSource(dio),
    productRepository:
        LocalProductRepository(db, remoteDataSource: productRemote),
    orderRepository: orderRepo,
    connectivityService: connectivity,
    syncService: SyncService(
      orderRepo,
      connectivity,
      orderRemote,
      owner,
      sessionExpirationHandler: sessionHandler,
    ),
  );
}
