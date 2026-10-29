import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import '../models/sign_result.dart';
import '../services/recognition/recognition_service.dart';
import '../services/recognition/mock_recognition_service.dart';
import '../services/recognition/backend_recognition_service.dart';
import '../services/settings_service.dart';

RecognitionService createRecognitionService({
  bool useMock = false,
  SettingsService? settings,
}) {
  if (useMock) return MockRecognitionService();
  if (settings == null) {
    throw ArgumentError('SettingsService is required for backend recognition.');
  }
  return BackendRecognitionService(settings: settings);
}

class RecognitionProvider extends ChangeNotifier {
  RecognitionProvider({bool useMock = false, SettingsService? settings})
    : _service = createRecognitionService(useMock: useMock, settings: settings);

  final RecognitionService _service;
  RecognitionService get service => _service;
  bool get isModelReady => _service.isModelReady;
  Stream<RecognitionProgress> get progress => _service.progress;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;
    await _service.initialize();
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> start() async {
    await _service.start();
  }

  Future<void> stop() async {
    await _service.stop();
  }

  Future<void> processFrame(CameraImage image) async {
    await _service.processFrame(image);
  }

  Future<void> processJpegFrame(Uint8List bytes) async {
    await _service.processJpegFrame(bytes);
  }

  Stream<SignResult> get predictions => _service.predictions;

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
