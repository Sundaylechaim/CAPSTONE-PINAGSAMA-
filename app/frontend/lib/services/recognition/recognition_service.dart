import 'dart:async';
import 'dart:ui';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:tinigsenyas/models/sign_result.dart';

class RecognitionProgress {
  const RecognitionProgress({
    required this.status,
    required this.framesCollected,
    required this.sequenceLength,
    required this.handLandmarks,
    required this.frameWidth,
    required this.frameHeight,
    this.label,
    this.confidence,
  });

  final String status;
  final int framesCollected;
  final int sequenceLength;
  final List<List<Offset>> handLandmarks;
  final int frameWidth;
  final int frameHeight;
  final String? label;
  final double? confidence;
}

abstract class RecognitionService {
  bool get isModelReady;
  Future<void> initialize();
  Future<void> start();
  Future<void> stop();
  Future<void> processFrame(CameraImage image);
  Future<void> processJpegFrame(Uint8List bytes);
  Stream<SignResult> get predictions;
  Stream<RecognitionProgress> get progress;
  void dispose();
}
