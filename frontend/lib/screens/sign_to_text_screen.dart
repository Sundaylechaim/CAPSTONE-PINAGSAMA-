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
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      await _cameraService.initialize(direction: CameraLensDirection.front);
      await _recognitionProvider!.initialize();
      await _recognitionProvider!.start();
      _isModelReady = _recognitionProvider!.isModelReady;
      _frameSubscription = _cameraService.frameStream.listen(
        _processFrame,
        onError: (Object error, StackTrace stackTrace) {
          if (mounted) setState(() => _recognitionError = error.toString());
        },
      );
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
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
        actions: const [
          ConnectivityBadge(),
          SizedBox(width: 14),
        ],
      ),
      body: _cameraError != null
          ? _buildErrorState()
          : !_isCameraInitialized
          ? const Center(child: CircularProgressIndicator())
          : _buildCameraView(),
    );
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 56, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text('Camera Error', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              _cameraError!,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
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
