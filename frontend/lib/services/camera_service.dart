import 'dart:async';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraService {
  CameraController? _controller;
  CameraDescription? _selectedCamera;
  List<CameraDescription> _cameras = [];
  StreamController<CameraImage>? _frameController;

  CameraController? get controller => _controller;
  bool get isInitialized => _controller?.value.isInitialized ?? false;
  CameraDescription? get selectedCamera => _selectedCamera;
  Stream<CameraImage> get frameStream => _frameController?.stream ?? const Stream.empty();

  Future<void> initialize({CameraLensDirection direction = CameraLensDirection.front}) async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      throw CameraException('Camera permission denied');
    }

    _cameras = await availableCameras();
    if (_cameras.isEmpty) {
      throw CameraException('No cameras available');
    }

    _selectedCamera = _cameras.firstWhere(
      (cam) => cam.lensDirection == direction,
      orElse: () => _cameras.first,
    );

    _controller = CameraController(
      _selectedCamera!,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _controller!.initialize();
    _startFrameStream();
  }

  void _startFrameStream() {
    _frameController?.close();
    _frameController = StreamController<CameraImage>.broadcast();

    _controller!.startImageStream((CameraImage image) {
      if (!_frameController!.isClosed) {
        _frameController!.add(image);
      }
    });
  }

  Future<void> switchCamera() async {
    if (_cameras.length < 2) return;

    final currentIndex = _cameras.indexOf(_selectedCamera!);
    final nextIndex = (currentIndex + 1) % _cameras.length;
    _selectedCamera = _cameras[nextIndex];

    await _controller?.dispose();
    _controller = CameraController(
      _selectedCamera!,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await _controller!.initialize();
    _startFrameStream();
  }

  void dispose() {
    _controller?.stopImageStream();
    _frameController?.close();
    _controller?.dispose();
    _controller = null;
    _frameController = null;
  }
}

class CameraException implements Exception {
  final String message;
  CameraException(this.message);
  @override
  String toString() => 'CameraException: $message';
}