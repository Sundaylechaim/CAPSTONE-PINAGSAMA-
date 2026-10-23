import 'dart:async';
import 'package:camera/camera.dart';
import 'package:tinigsenyas/models/sign_result.dart';
import 'recognition_service.dart';

class MockRecognitionService implements RecognitionService {
  static final _mockSigns = [
    SignResult(label: 'HELLO', confidence: 0.94, timestamp: DateTime.now()),
    SignResult(label: 'THANK YOU', confidence: 0.89, timestamp: DateTime.now()),
    SignResult(label: 'SORRY', confidence: 0.92, timestamp: DateTime.now()),
    SignResult(label: 'YES', confidence: 0.96, timestamp: DateTime.now()),
    SignResult(label: 'NO', confidence: 0.91, timestamp: DateTime.now()),
    SignResult(label: 'PLEASE', confidence: 0.87, timestamp: DateTime.now()),
    SignResult(label: 'GOOD', confidence: 0.93, timestamp: DateTime.now()),
    SignResult(label: 'BAD', confidence: 0.88, timestamp: DateTime.now()),
  ];

  final _predictionsController = StreamController<SignResult>.broadcast();
  Timer? _timer;
  int _currentIndex = 0;
  bool _isRunning = false;

  @override
  bool get isModelReady => true;

  @override
  Future<void> initialize() async {
    // Mock initialization - no-op
  }

  @override
  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_isRunning) return;
      final sign = _mockSigns[_currentIndex].copyWith(
        timestamp: DateTime.now(),
      );
      _predictionsController.add(sign);
      _currentIndex = (_currentIndex + 1) % _mockSigns.length;
    });
  }

  @override
  Future<void> stop() async {
    _isRunning = false;
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future<void> processFrame(CameraImage image) async {
    // Mock doesn't process frames
  }

  @override
  Stream<SignResult> get predictions => _predictionsController.stream;

  @override
  void dispose() {
    stop();
    _predictionsController.close();
  }
}
