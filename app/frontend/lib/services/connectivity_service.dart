import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

enum ConnectivityStatus { online, offline, checking, unknown }

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final _statusController = StreamController<ConnectivityStatus>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  ConnectivityStatus _currentStatus = ConnectivityStatus.checking;
  String? _lastError;
  bool _isDisposed = false;

  ConnectivityStatus get currentStatus => _currentStatus;
  String? get lastError => _lastError;
  Stream<ConnectivityStatus> get statusStream => _statusController.stream;

  ConnectivityService() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
      onError: (Object error, StackTrace stackTrace) {
        _setStatus(ConnectivityStatus.unknown, error);
      },
    );
    checkConnectivity();
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final hasConnection = results.any(
      (result) => result != ConnectivityResult.none,
    );
    final newStatus = hasConnection
        ? ConnectivityStatus.online
        : ConnectivityStatus.offline;
    _setStatus(newStatus);
  }

  Future<void> checkConnectivity() async {
    _setStatus(ConnectivityStatus.checking);
    try {
      final results = await _connectivity.checkConnectivity();
      final hasConnection = results.any(
        (result) => result != ConnectivityResult.none,
      );
      _setStatus(
        hasConnection ? ConnectivityStatus.online : ConnectivityStatus.offline,
      );
    } catch (error) {
      _setStatus(ConnectivityStatus.unknown, error);
    }
  }

  void _setStatus(ConnectivityStatus status, [Object? error]) {
    if (_isDisposed) return;
    _currentStatus = status;
    _lastError = error?.toString();
    if (!_statusController.isClosed) _statusController.add(status);
  }

  void dispose() {
    _isDisposed = true;
    _connectivitySubscription?.cancel();
    _statusController.close();
  }
}
