import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionChangeController =
      StreamController<bool>.broadcast();
  final Future<bool> Function()? _checkOverride;
  StreamSubscription? _subscription;
  StreamSubscription? _testStreamSubscription;
  bool _disposed = false;

  Stream<bool> get connectionStream => _connectionChangeController.stream;

  ConnectivityService({Future<bool> Function()? checkOverride})
      : _checkOverride = checkOverride {
    if (_checkOverride != null) return;
    _subscription =
        _connectivity.onConnectivityChanged.listen(_connectionChange);
    checkConnection();
  }

  /// Variante de test/offline que no escucha el plugin nativo.
  ConnectivityService.forTest({
    required Future<bool> Function() checkConnection,
    Stream<bool>? connectionStream,
  }) : _checkOverride = checkConnection {
    if (connectionStream != null) {
      _testStreamSubscription =
          connectionStream.listen(_connectionChangeController.add);
    }
  }

  Future<bool> checkConnection() async {
    final override = _checkOverride;
    if (override != null) {
      return override();
    }

    var result = await _connectivity.checkConnectivity();
    bool hasConnection = result != ConnectivityResult.none;
    return hasConnection;
  }

  void _connectionChange(dynamic result) {
    if (_disposed || _connectionChangeController.isClosed) return;
    bool hasConnection;
    if (result is List) {
      hasConnection = !result.contains(ConnectivityResult.none);
    } else {
      hasConnection = result != ConnectivityResult.none;
    }
    _connectionChangeController.add(hasConnection);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _subscription?.cancel();
    _subscription = null;
    _testStreamSubscription?.cancel();
    _testStreamSubscription = null;
    if (!_connectionChangeController.isClosed) {
      _connectionChangeController.close();
    }
  }
}
