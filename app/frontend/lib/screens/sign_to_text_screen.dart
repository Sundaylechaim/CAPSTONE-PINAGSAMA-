import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import '../providers/recognition_provider.dart';
import '../services/camera_service.dart';
import '../services/tts_service.dart';
import '../services/database_helper.dart';
import '../models/sign_result.dart';
import '../widgets/camera_preview.dart';
import '../widgets/prediction_overlay.dart';
import '../widgets/signing_space_overlay.dart';
import '../widgets/connectivity_badge.dart';

const Color _kAppBlue = Color(0xFF0138FF);
const Color _kAppYellow = Color(0xFFFFC801);

class SignToTextScreen extends StatefulWidget {
  const SignToTextScreen({super.key});

  @override
  State<SignToTextScreen> createState() => _SignToTextScreenState();
}

class _SignToTextScreenState extends State<SignToTextScreen> {
  late CameraService _cameraService;
  late TtsService _ttsService;
  SignResult? _currentPrediction;
  bool _isCheckingPermission = true;
  bool _hasPermission = false;
  bool _isPermanentlyDenied = false;
  bool _isCameraInitialized = false;
  bool _isModelReady = false;
  bool _isProcessingFrame = false;
  String? _cameraError;
  String? _recognitionError;
  RecognitionProvider? _recognitionProvider;
  StreamSubscription<SignResult>? _predictionSubscription;
  StreamSubscription<CameraImage>? _frameSubscription;

  @override
  void initState() {
    super.initState();
    _cameraService = CameraService();
    _ttsService = context.read<TtsService>();
    _recognitionProvider = context.read<RecognitionProvider>();
    _predictionSubscription = _recognitionProvider!.predictions.listen((
      prediction,
    ) {
      if (mounted) {
        setState(() {
          _currentPrediction = prediction;
        });
      }
    });
    _checkPermissionAndStart();
  }

  Future<void> _checkPermissionAndStart() async {
    setState(() => _isCheckingPermission = true);
    final hasPerm = await _cameraService.hasCameraPermission();
    final isPermDenied = await _cameraService.isPermissionPermanentlyDenied();

    if (mounted) {
      setState(() {
        _hasPermission = hasPerm;
        _isPermanentlyDenied = isPermDenied;
        _isCheckingPermission = false;
      });
    }

    if (hasPerm) {
      await _initializeCamera();
    }
  }

  Future<void> _requestPermissionAndStart() async {
    setState(() => _cameraError = null);
    final granted = await _cameraService.requestCameraPermission();
    final isPermDenied = await _cameraService.isPermissionPermanentlyDenied();

    if (mounted) {
      setState(() {
        _hasPermission = granted;
        _isPermanentlyDenied = isPermDenied;
      });
    }

    if (granted) {
      await _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      await _cameraService.initialize(direction: CameraLensDirection.front);
      await _recognitionProvider!.initialize();
      await _recognitionProvider!.start();
      _isModelReady = _recognitionProvider!.isModelReady;

      _restartFrameStream();

      if (mounted) {
        setState(() {
          _hasPermission = true;
          _isCameraInitialized = true;
          _cameraError = null;
        });
      }
    } on CameraPermissionPermanentlyDeniedException catch (e) {
      if (mounted) {
        setState(() {
          _hasPermission = false;
          _isPermanentlyDenied = true;
          _cameraError = e.message;
        });
      }
    } on CameraPermissionDeniedException catch (_) {
      if (mounted) {
        setState(() {
          _hasPermission = false;
          _isPermanentlyDenied = false;
          _cameraError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cameraError = e.toString();
        });
      }
    }
  }

  void _restartFrameStream() {
    _frameSubscription?.cancel();
    _frameSubscription = _cameraService.frameStream.listen(
      _processFrame,
      onError: (Object error, StackTrace stackTrace) {
        if (mounted) setState(() => _recognitionError = error.toString());
      },
    );
  }

  Future<void> _switchCamera() async {
    try {
      await _cameraService.switchCamera();
      _restartFrameStream();
      if (mounted) {
        final currentCam = _cameraService.selectedCamera;
        final name = currentCam != null
            ? CameraService.getCameraDisplayName(currentCam, 0)
            : 'Camera';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Switched to: $name'),
            duration: const Duration(milliseconds: 900),
          ),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not switch camera: $e')),
        );
      }
    }
  }

  void _showCameraPicker() {
    final cameras = _cameraService.availableCamerasList;
    if (cameras.length <= 2) {
      _switchCamera();
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    'Select Camera',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                const Divider(),
                ...cameras.asMap().entries.map((entry) {
                  final index = entry.key;
                  final cam = entry.value;
                  final isSelected = cam == _cameraService.selectedCamera;
                  return ListTile(
                    leading: Icon(
                      cam.lensDirection == CameraLensDirection.front
                          ? Icons.camera_front_rounded
                          : cam.lensDirection == CameraLensDirection.back
                              ? Icons.camera_rear_rounded
                              : Icons.videocam_rounded,
                      color: isSelected ? _kAppBlue : null,
                    ),
                    title: Text(
                      CameraService.getCameraDisplayName(cam, index),
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? _kAppBlue : null,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded, color: _kAppBlue)
                        : null,
                    onTap: () async {
                      Navigator.of(context).pop();
                      await _cameraService.selectCamera(cam);
                      _restartFrameStream();
                      if (mounted) setState(() {});
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _processFrame(CameraImage image) {
    if (_isProcessingFrame || _recognitionProvider == null) return;
    _isProcessingFrame = true;
    _recognitionProvider!
        .processFrame(image)
        .then((_) {
          if (mounted && _recognitionError != null) {
            setState(() => _recognitionError = null);
          }
        })
        .catchError((Object error, StackTrace stackTrace) {
          debugPrint('Sign recognition frame failed: $error');
          if (mounted) setState(() => _recognitionError = error.toString());
        })
        .whenComplete(() => _isProcessingFrame = false);
  }

  Future<void> _speakCurrentPrediction() async {
    if (_currentPrediction != null) {
      try {
        await _ttsService.speak(_currentPrediction!.label);
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not play speech: $error')),
          );
        }
      }
    }
  }

  Future<void> _saveCurrentPrediction() async {
    if (_currentPrediction != null) {
      try {
        await DatabaseHelper.instance.saveRecognizedGesture(
          _currentPrediction!.label,
          _currentPrediction!.confidence,
          source: 'sign',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saved: ${_currentPrediction!.label}'),
              duration: const Duration(milliseconds: 800),
            ),
          );
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not save sign: $error')),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _predictionSubscription?.cancel();
    _frameSubscription?.cancel();
    _cameraService.dispose();
    final recognitionProvider = _recognitionProvider;
    if (recognitionProvider != null) unawaited(recognitionProvider.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0C1220).withValues(alpha: 0.65)
                    : Colors.white.withValues(alpha: 0.70),
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.05),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Sign to Text',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 19,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: _kAppYellow,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        actions: [
          if (_isCameraInitialized && _cameraService.canSwitchCamera)
            IconButton(
              icon: const Icon(Icons.cameraswitch_rounded),
              tooltip: 'Switch Camera',
              onPressed: _showCameraPicker,
            ),
          const ConnectivityBadge(),
          const SizedBox(width: 14),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isCheckingPermission) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_hasPermission) {
      return _buildPermissionRequestView();
    }

    if (_cameraError != null) {
      return _buildErrorState();
    }

    if (!_isCameraInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return _buildCameraView();
  }

  Widget _buildPermissionRequestView() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0C1220).withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.16)
                      : Colors.white.withValues(alpha: 0.80),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _kAppBlue.withValues(alpha: 0.12),
                      border: Border.all(
                        color: _kAppBlue.withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.videocam_rounded,
                      size: 40,
                      color: _kAppBlue,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Camera Access Required',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'TinigSenyas needs your camera permission to recognize hand gestures from left to right and translate Filipino Sign Language (FSL) in real-time.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),
                  _buildFeatureBullet(
                    Icons.pan_tool_rounded,
                    'Recognizes both hands across horizontal signing space',
                  ),
                  const SizedBox(height: 10),
                  _buildFeatureBullet(
                    Icons.cameraswitch_rounded,
                    'Compatible with all cameras: Front, Back & USB Webcams',
                  ),
                  const SizedBox(height: 10),
                  _buildFeatureBullet(
                    Icons.lock_outline_rounded,
                    'Private: Frames are processed locally on your device',
                  ),
                  const SizedBox(height: 28),
                  if (_isPermanentlyDenied) ...[
                    Text(
                      'Camera permission is permanently denied in system settings.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () async => await _cameraService.openSettings(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kAppBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.settings_rounded),
                      label: const Text(
                        'Open App Settings',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _checkPermissionAndStart,
                      child: const Text('I have allowed permission (Check again)'),
                    ),
                  ] else ...[
                    ElevatedButton.icon(
                      onPressed: _requestPermissionAndStart,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kAppBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: const Text(
                        'Allow Camera Access',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureBullet(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _kAppYellow.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: const Color(0xFFD97706)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);
    final isPermIssue = _isPermanentlyDenied ||
        (_cameraError != null && _cameraError!.toLowerCase().contains('permission'));

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 56, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              isPermIssue ? 'Camera Permission Issue' : 'Camera Error',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              _cameraError ?? 'Unable to connect to camera.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (isPermIssue) ...[
              ElevatedButton.icon(
                onPressed: () async => await _cameraService.openSettings(),
                icon: const Icon(Icons.settings_rounded),
                label: const Text('Open System Settings'),
              ),
              const SizedBox(height: 10),
            ],
            ElevatedButton.icon(
              onPressed: _initializeCamera,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry Camera'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraView() {
    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreviewWidget(
          cameraService: _cameraService,
          overlay: PredictionOverlay(prediction: _currentPrediction, top: 72),
        ),
        const SigningSpaceOverlay(),
        Positioned(
          top: 100,
          left: 16,
          right: 16,
          child: _buildRecognitionStatus(),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: _buildActionCard(),
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasPrediction = _currentPrediction != null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF0C1220).withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.90),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.16)
                  : Colors.white.withValues(alpha: 0.80),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: hasPrediction
                          ? _kAppBlue.withValues(alpha: 0.15)
                          : Colors.grey.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      hasPrediction ? Icons.check_circle_rounded : Icons.radar_rounded,
                      color: hasPrediction ? _kAppBlue : Colors.grey,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      hasPrediction
                          ? 'Recognized: ${_currentPrediction!.label}'
                          : _isModelReady
                          ? 'Position hand gestures in frame...'
                          : 'FSL recognition model is in training',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  if (hasPrediction && _isModelReady)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _kAppYellow,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${(_currentPrediction!.confidence * 100).toInt()}%',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (hasPrediction && _isModelReady) ...[
                    _ActionButton(
                      icon: Icons.volume_up_rounded,
                      label: 'Speak',
                      onPressed: _speakCurrentPrediction,
                      color: _kAppBlue,
                    ),
                    const SizedBox(width: 16),
                    _ActionButton(
                      icon: Icons.bookmark_add_rounded,
                      label: 'Save',
                      onPressed: _saveCurrentPrediction,
                      color: _kAppYellow,
                    ),
                    const SizedBox(width: 16),
                    _ActionButton(
                      icon: Icons.replay_rounded,
                      label: 'Repeat',
                      onPressed: _speakCurrentPrediction,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                  ] else if (!_isModelReady) ...[
                    Expanded(
                      child: Text(
                        'Camera preview is ready. Sign recognition will be enabled when the trained model is integrated.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ] else ...[
                    _ActionButton(
                      icon: Icons.menu_book_rounded,
                      label: 'FSL Guide',
                      onPressed: _showGuide,
                      color: _kAppBlue,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecognitionStatus() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final message =
        _recognitionError ??
        (_isModelReady
            ? 'FSL sign recognition is active'
            : 'FSL sign model is in training');

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _recognitionError == null
                ? (isDark ? const Color(0xFF0C1220).withValues(alpha: 0.75) : Colors.white.withValues(alpha: 0.85))
                : Colors.redAccent.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.white60,
            ),
          ),
          child: Row(
            children: [
              Icon(
                _recognitionError == null
                    ? Icons.videocam_rounded
                    : Icons.error_outline_rounded,
                color: _recognitionError == null ? _kAppBlue : Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: _recognitionError == null
                        ? (isDark ? Colors.white : const Color(0xFF0F172A))
                        : Colors.white,
                  ),
                ),
              ),
              if (_cameraService.canSwitchCamera) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: _showCameraPicker,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _kAppBlue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cameraswitch_rounded, size: 14, color: _kAppBlue),
                        SizedBox(width: 4),
                        Text(
                          'Switch',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _kAppBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showGuide() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (context, scrollController) => ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0E1626).withValues(alpha: 0.95)
                      : Colors.white.withValues(alpha: 0.95),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Text(
                          'FSL Signing Guide',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(width: 5),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: _kAppYellow,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        physics: const BouncingScrollPhysics(),
                        children: const [
                          _GuideItem('HELLO', 'Wave hand near face with a friendly smile'),
                          _GuideItem('THANK YOU', 'Touch chin with fingers, move hand forward'),
                          _GuideItem('YES', 'Closed fist nodding up and down'),
                          _GuideItem('NO', 'Index and middle finger snap to thumb'),
                          _GuideItem('PLEASE', 'Open flat palm rubbed circular on chest'),
                          _GuideItem('SORRY', 'Closed fist rubbed circular on chest'),
                          _GuideItem('GOOD', 'Thumb up gesture moving outward from chin'),
                          _GuideItem('BAD', 'Thumb down gesture moving outward from chin'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: 0.4)),
              ),
              child: Center(
                child: Icon(icon, color: color, size: 24),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
        ),
      ],
    );
  }
}

class _GuideItem extends StatelessWidget {
  final String sign;
  final String description;

  const _GuideItem(this.sign, this.description);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF162138) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF233352) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _kAppBlue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              sign,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: _kAppBlue,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              description,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
