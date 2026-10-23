import 'dart:async';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign to Text'),
        actions: [const ConnectivityBadge(), const SizedBox(width: 16)],
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
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text('Camera Error', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              _cameraError!,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _initializeCamera,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraView() {
    final theme = Theme.of(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreviewWidget(
          cameraService: _cameraService,
          overlay: PredictionOverlay(prediction: _currentPrediction, top: 72),
        ),
        Positioned(
          top: 16,
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
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  theme.colorScheme.surface.withValues(alpha: 0.95),
                  theme.colorScheme.surface.withValues(alpha: 0.0),
                ],
              ),
            ),
            child: _buildActionCard(),
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard() {
    final theme = Theme.of(context);
    final hasPrediction = _currentPrediction != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                hasPrediction ? Icons.check_circle : Icons.radar,
                color: hasPrediction
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasPrediction
                      ? 'Recognized: ${_currentPrediction!.label}'
                      : _isModelReady
                      ? 'Position your hands in frame...'
                      : 'FSL recognition model is in training',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: hasPrediction
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (hasPrediction && _isModelReady)
                Text(
                  '${(_currentPrediction!.confidence * 100).toInt()}%',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
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
                  icon: Icons.volume_up,
                  label: 'Speak',
                  onPressed: _speakCurrentPrediction,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                _ActionButton(
                  icon: Icons.save,
                  label: 'Save',
                  onPressed: _saveCurrentPrediction,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(width: 12),
                _ActionButton(
                  icon: Icons.replay,
                  label: 'Repeat',
                  onPressed: _speakCurrentPrediction,
                  color: theme.colorScheme.tertiary,
                ),
              ] else if (!_isModelReady) ...[
                Expanded(
                  child: Text(
                    'Camera preview is ready. Sign recognition will be enabled when the trained model is integrated.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ] else ...[
                _ActionButton(
                  icon: Icons.help_outline,
                  label: 'Guide',
                  onPressed: _showGuide,
                  color: theme.colorScheme.primary,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecognitionStatus() {
    final theme = Theme.of(context);
    final message =
        _recognitionError ??
        (_isModelReady
            ? 'FSL sign recognition is ready'
            : 'The FSL model is still being trained');
    final color = _recognitionError == null
        ? theme.colorScheme.surface.withValues(alpha: 0.92)
        : theme.colorScheme.errorContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            _recognitionError == null
                ? Icons.info_outline
                : Icons.error_outline,
            color: _recognitionError == null
                ? theme.colorScheme.primary
                : theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }

  void _showGuide() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FSL Signing Guide',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _GuideItem('HELLO', 'Wave hand near face'),
                    _GuideItem('THANK YOU', 'Touch chin, move hand forward'),
                    _GuideItem('YES', 'Fist nod up and down'),
                    _GuideItem('NO', 'Index finger side to side'),
                    _GuideItem('PLEASE', 'Flat hand circular on chest'),
                    _GuideItem('SORRY', 'Fist circular on chest'),
                    _GuideItem('GOOD', 'Thumb up from chin'),
                    _GuideItem('BAD', 'Thumb down from chin'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
        IconButton.filled(
          onPressed: onPressed,
          icon: Icon(icon),
          style: IconButton.styleFrom(
            backgroundColor: color.withValues(alpha: 0.1),
            foregroundColor: color,
            fixedSize: const Size(56, 56),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 60,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                sign,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(description)),
        ],
      ),
    );
  }
}
