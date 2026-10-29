import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/connectivity_service.dart';

class AppModeProvider extends ChangeNotifier {
  final ConnectivityService _connectivityService;
  ConnectivityStatus _status = ConnectivityStatus.checking;
  Timer? _debounceTimer;

  AppModeProvider(this._connectivityService) {
    _status = _connectivityService.currentStatus;
    _connectivityService.statusStream.listen(_onStatusChanged);
  }

  ConnectivityStatus get status => _status;
  bool get isOnline => _status == ConnectivityStatus.online;
  bool get isOffline => _status == ConnectivityStatus.offline;
  bool get isChecking => _status == ConnectivityStatus.checking;

  void _onStatusChanged(ConnectivityStatus newStatus) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (_status != newStatus) {
        _status = newStatus;
        notifyListeners();
      }
    });
  }

  Future<void> checkConnectivity() async {
    await _connectivityService.checkConnectivity();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}