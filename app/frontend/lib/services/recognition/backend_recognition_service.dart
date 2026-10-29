import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;
import 'package:tinigsenyas/models/sign_result.dart';
import '../settings_service.dart';
import 'recognition_service.dart';

class BackendRecognitionService implements RecognitionService {
  BackendRecognitionService({required this._settings, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 30),
              sendTimeout: const Duration(seconds: 10),
            ),
          );

  final _predictionsController = StreamController<SignResult>.broadcast();
  final _progressController = StreamController<RecognitionProgress>.broadcast();
  final SettingsService _settings;
  final Dio _dio;
  bool _isInitialized = false;
  bool _isRunning = false;
  int _frameCount = 0;
  String? _serverUrl;
  String? _sessionId;
  String _accessToken = '';

  @override
  bool get isModelReady => _isInitialized;

  @override
  Future<void> initialize() async {
    final serverUrl = _settings.ttsServerUrl.trim().replaceFirst(
      RegExp(r'/+$'),
      '',
    );
    if (serverUrl.isEmpty) {
      throw StateError(
        'Configure the backend server URL in Settings to use FSL recognition.',
      );
    }

    final response = await _dio.get<Map<String, dynamic>>(
      '$serverUrl/api/v1/recognition/status',
    );
    final status = response.data;
    if (response.statusCode != 200 ||
        status?['ready'] != true ||
        status?['sequence_length'] != 60 ||
        status?['class_count'] is! int) {
      throw StateError('The backend FSL recognition model is not ready.');
    }

    _serverUrl = serverUrl;
    _accessToken = await _settings.getTtsServerToken();
    _isInitialized = true;
  }

  @override
  Future<void> start() async {
    if (!_isInitialized) {
      throw StateError(
        'Recognition service must be initialized before starting.',
      );
    }
    _sessionId = _createSessionId();
    _frameCount = 0;
    _isRunning = true;
  }

  @override
  Future<void> stop() async {
    _isRunning = false;
    final sessionId = _sessionId;
    _sessionId = null;
    if (sessionId == null || _serverUrl == null) return;
    try {
      await _dio.delete<void>(
        '$_serverUrl/api/v1/recognition/session',
        options: Options(
          headers: {
            'X-Session-ID': sessionId,
            if (_accessToken.isNotEmpty)
              'Authorization': 'Bearer $_accessToken',
          },
        ),
      );
    } catch (error) {
      debugPrint('Could not clear recognition session: $error');
    }
  }

  @override
  Future<void> processFrame(CameraImage image) async {
    if (!_isInitialized) {
      throw StateError(
        'Recognition service must be initialized before processing frames.',
      );
    }
    if (!_isRunning || !isModelReady) return;
    _frameCount++;
    if (_frameCount % 3 != 0) return;

    await _sendJpegFrame(_encodeJpeg(image));
  }

  @override
  Future<void> processJpegFrame(Uint8List bytes) async {
    if (!_isInitialized) {
      throw StateError(
        'Recognition service must be initialized before processing frames.',
      );
    }
    if (!_isRunning || !isModelReady) return;
    await _sendJpegFrame(bytes);
  }

  Future<void> _sendJpegFrame(Uint8List bytes) async {
    final sessionId = _sessionId!;
    final response = await _dio.post<Map<String, dynamic>>(
      '$_serverUrl/api/v1/recognition/frame',
      data: bytes,
      options: Options(
        contentType: 'image/jpeg',
        headers: {
          'X-Session-ID': sessionId,
          if (_accessToken.isNotEmpty) 'Authorization': 'Bearer $_accessToken',
        },
        responseType: ResponseType.json,
      ),
    );
    final data = response.data;
    final status = data?['status'];
    final framesCollected = data?['frames_collected'];
    if (status is! String || framesCollected is! int) {
      throw StateError(
        'The recognition server returned an invalid frame status.',
      );
    }

    final label = data?['label'];
    final confidence = data?['confidence'];
    final handLandmarks = _parseHandLandmarks(data?['hand_landmarks']);
    final frameWidth = data?['frame_width'];
    final frameHeight = data?['frame_height'];
    if (frameWidth is! int || frameHeight is! int) {
      throw StateError(
        'The recognition server returned invalid frame dimensions.',
      );
    }
    _progressController.add(
      RecognitionProgress(
        status: status,
        framesCollected: framesCollected,
        sequenceLength: 60,
        handLandmarks: handLandmarks,
        frameWidth: frameWidth,
        frameHeight: frameHeight,
        label: label is String ? label : null,
        confidence: confidence is num ? confidence.toDouble() : null,
      ),
    );
    if (data?['status'] == 'recognized' &&
        label is String &&
        confidence is num) {
      _predictionsController.add(
        SignResult(
          label: label,
          confidence: confidence.toDouble(),
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  List<List<Offset>> _parseHandLandmarks(Object? value) {
    if (value is! List) {
      throw StateError(
        'The recognition server returned invalid hand landmarks.',
      );
    }
    return value
        .map((hand) {
          if (hand is! List || hand.length != 21) {
            throw StateError(
              'The recognition server returned an invalid hand skeleton.',
            );
          }
          return hand
              .map((point) {
                if (point is! List ||
                    point.length != 2 ||
                    point[0] is! num ||
                    point[1] is! num) {
                  throw StateError(
                    'The recognition server returned an invalid hand landmark.',
                  );
                }
                return Offset(
                  (point[0] as num).toDouble(),
                  (point[1] as num).toDouble(),
                );
              })
              .toList(growable: false);
        })
        .toList(growable: false);
  }

  Uint8List _encodeJpeg(CameraImage cameraImage) {
    final width = cameraImage.width;
    final height = cameraImage.height;
    final output = image.Image(width: width, height: height);
    final planes = cameraImage.planes;

    switch (cameraImage.format.group) {
      case ImageFormatGroup.bgra8888:
        final plane = planes.first;
        final bytes = plane.bytes;
        for (var y = 0; y < height; y++) {
          for (var x = 0; x < width; x++) {
            final offset = y * plane.bytesPerRow + x * 4;
            output.setPixelRgb(
              x,
              y,
              bytes[offset + 2],
              bytes[offset + 1],
              bytes[offset],
            );
          }
        }
        break;
      case ImageFormatGroup.yuv420:
        if (planes.length < 3) {
          throw UnsupportedError('YUV420 frames must have three image planes.');
        }
        final yPlane = planes[0];
        final uPlane = planes[1];
        final vPlane = planes[2];
        for (var y = 0; y < height; y++) {
          for (var x = 0; x < width; x++) {
            final yIndex = y * yPlane.bytesPerRow + x * yPlane.bytesPerPixel!;
            final uvX = x ~/ 2;
            final uvY = y ~/ 2;
            final uIndex =
                uvY * uPlane.bytesPerRow + uvX * uPlane.bytesPerPixel!;
            final vIndex =
                uvY * vPlane.bytesPerRow + uvX * vPlane.bytesPerPixel!;
            final luma = yPlane.bytes[yIndex].toDouble();
            final u = uPlane.bytes[uIndex].toDouble() - 128;
            final v = vPlane.bytes[vIndex].toDouble() - 128;
            output.setPixelRgb(
              x,
              y,
              (luma + 1.402 * v).round().clamp(0, 255),
              (luma - 0.344136 * u - 0.714136 * v).round().clamp(0, 255),
              (luma + 1.772 * u).round().clamp(0, 255),
            );
          }
        }
        break;
      case ImageFormatGroup.nv21:
        final plane = planes.first;
        final bytes = plane.bytes;
        final chromaStart = plane.bytesPerRow * height;
        for (var y = 0; y < height; y++) {
          for (var x = 0; x < width; x++) {
            final yIndex = y * plane.bytesPerRow + x;
            final uvIndex =
                chromaStart + (y ~/ 2) * plane.bytesPerRow + (x & ~1);
            final luma = bytes[yIndex].toDouble();
            final v = bytes[uvIndex].toDouble() - 128;
            final u = bytes[uvIndex + 1].toDouble() - 128;
            output.setPixelRgb(
              x,
              y,
              (luma + 1.402 * v).round().clamp(0, 255),
              (luma - 0.344136 * u - 0.714136 * v).round().clamp(0, 255),
              (luma + 1.772 * u).round().clamp(0, 255),
            );
          }
        }
        break;
      case ImageFormatGroup.jpeg:
        return Uint8List.fromList(planes.first.bytes);
      case ImageFormatGroup.unknown:
        throw UnsupportedError(
          'The camera returned an unsupported image format.',
        );
    }

    final resized = width >= height && width > 640
        ? image.copyResize(output, width: 640)
        : height > width && height > 640
        ? image.copyResize(output, height: 640)
        : output;
    return Uint8List.fromList(image.encodeJpg(resized, quality: 75));
  }

  @override
  Stream<SignResult> get predictions => _predictionsController.stream;

  @override
  Stream<RecognitionProgress> get progress => _progressController.stream;

  String _createSessionId() {
    final random = Random.secure();
    return List<int>.generate(
      16,
      (_) => random.nextInt(256),
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  @override
  void dispose() {
    _isInitialized = false;
    unawaited(_disposeAsync());
    _predictionsController.close();
    _progressController.close();
  }

  Future<void> _disposeAsync() async {
    await stop();
    _dio.close();
  }
}
