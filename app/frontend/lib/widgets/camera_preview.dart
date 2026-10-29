import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/camera_service.dart';

class CameraPreviewWidget extends StatelessWidget {
  final CameraService cameraService;
  final Widget? overlay;
  final BoxFit fit;

  const CameraPreviewWidget({
    super.key,
    required this.cameraService,
    this.overlay,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (!cameraService.isInitialized ||
        cameraService.controller?.value.isInitialized != true) {
      return const Center(child: CircularProgressIndicator());
    }

    return CameraPreview(cameraService.controller!, child: overlay);
  }
}
