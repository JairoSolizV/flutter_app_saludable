import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/database/database_helper.dart';
import 'data/repositories/local_product_repository.dart';
import 'data/repositories/local_order_repository.dart';
import 'presentation/providers/product_provider.dart';
import 'presentation/providers/order_provider.dart';
import 'presentation/providers/user_provider.dart'; // Added
import 'core/services/connectivity_service.dart';
import 'core/services/sync_service.dart';
import 'core/api/api_client.dart';
import 'data/datasources/remote/auth_remote_data_source.dart';
import 'data/datasources/remote/club_remote_data_source.dart'; // Nuevo
import 'data/datasources/remote/product_remote_data_source.dart';
import 'data/datasources/remote/order_remote_data_source.dart';
import 'presentation/providers/auth_provider.dart';
import 'data/repositories/local_user_repository.dart';

// Global instances for dependencies
late final DatabaseHelper dbHelper;
late final LocalUserRepository userRepository;
late final ApiClient apiClient;
late final AuthRemoteDataSource authRemoteDataSource;
late final ProductRemoteDataSource productRemoteDataSource;
late final ClubRemoteDataSource clubRemoteDataSource; // Nuevo
late final OrderRemoteDataSource orderRemoteDataSource;
late final LocalProductRepository productRepository;
late final LocalOrderRepository orderRepository;
late final ConnectivityService connectivityService;
late final SyncService syncService;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
    // 1. Base de Datos
    dbHelper = DatabaseHelper();
    
    // 2. Repositorios Locales (Base)
    userRepository = LocalUserRepository(dbHelper);
    
    // 3. Red y Cliente API
    apiClient = ApiClient(userRepository);
    authRemoteDataSource = AuthRemoteDataSourceImpl(apiClient.client);
    clubRemoteDataSource = ClubRemoteDataSource(apiClient.client); // Inicialización faltante
    productRemoteDataSource = ProductRemoteDataSourceImpl(apiClient.client);
    orderRemoteDataSource = OrderRemoteDataSourceImpl(apiClient.client);
    
    // 4. Repositorios Híbridos
    productRepository = LocalProductRepository(dbHelper, remoteDataSource: productRemoteDataSource);
    orderRepository = LocalOrderRepository(dbHelper);
    
    // 5. Servicios
    connectivityService = ConnectivityService();
    syncService = SyncService(orderRepository, connectivityService, orderRemoteDataSource);

  runApp(const AppState());
}

class AppState extends StatelessWidget {
  const AppState({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ProductProvider(productRepository)..loadProducts(),
        ),
        ChangeNotifierProvider(
          create: (_) => OrderProvider(orderRepository, connectivityService, syncService)..loadOrders('user_1'), // Mock user_1
        ),
        ChangeNotifierProvider(
          create: (_) => UserProvider(userRepository),
        ),
        Provider<ConnectivityService>(
            create: (_) => connectivityService,
            dispose: (_, service) => service.dispose(),
        ),
        Provider<AuthRemoteDataSource>(
            create: (_) => authRemoteDataSource,
        ),
         ChangeNotifierProvider(
          create: (_) => AuthProvider(authRemoteDataSource, userRepository),
        ),
      ],
      child: const MainApp(),
    );
  }
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Nutrilife Club',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
    );
  }
}
