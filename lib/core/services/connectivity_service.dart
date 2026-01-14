import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionChangeController = StreamController<bool>.broadcast();

  Stream<bool> get connectionStream => _connectionChangeController.stream;

  ConnectivityService() {
    // Escuchar cambios de conectividad (Version legacy puede ser Stream<ConnectivityResult>)
    _connectivity.onConnectivityChanged.listen(_connectionChange);
    // Chequeo inicial
    checkConnection();
  }

  Future<bool> checkConnection() async {
    // Si la versión instalada devuelve ConnectivityResult (singular) o List<ConnectivityResult>, debemos manejarlo.
    // El error sugería que `_connectionChange` esperaba List pero el stream daba singular.
    // Vamos a usar `await _connectivity.checkConnectivity()` y ver qué tipo retorna dinámicamente si pudiéramos, 
    // pero en compilación estática debemos acertar.
    // El error `The argument type 'void Function(List<ConnectivityResult>)' ... 'void Function(ConnectivityResult)?'`
    // CONFIRMA que el Stream emite `ConnectivityResult` (singular).
    
    var result = await _connectivity.checkConnectivity();
    bool hasConnection = result != ConnectivityResult.none;
    return hasConnection;
  }

  void _connectionChange(dynamic result) { // Usamos dynamic para acomodar ambas versiones por si acaso, pero casteamos.
    // En versión vieja result es ConnectivityResult.
    bool hasConnection;
    if (result is List) {
       hasConnection = !result.contains(ConnectivityResult.none);
    } else {
       hasConnection = result != ConnectivityResult.none;
    }
    _connectionChangeController.add(hasConnection);
  }
  
  void dispose() {
    _connectionChangeController.close();
  }
}
