import 'package:flutter/material.dart';
import '../models/sign_result.dart';

class PredictionOverlay extends StatelessWidget {
  final SignResult? prediction;
  final bool isProcessing;
  final double top;

  const PredictionOverlay({
    super.key,
    this.prediction,
    this.isProcessing = false,
    this.top = 16,
  });

  @override
  Widget build(BuildContext context) {
    if (prediction == null && !isProcessing) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final label = prediction?.label ?? 'Detecting...';
    final confidence = prediction?.confidence ?? 0.0;
    final confidencePercent = (confidence * 100).toInt();

    return Positioned(
      top: top,
      left: 16,
      right: 16,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surface.withValues(alpha: 0.9),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                isProcessing ? Icons.radar : Icons.check_circle,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Sign: $label',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    if (prediction != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: confidence,
                              backgroundColor:
                                  theme.colorScheme.surfaceContainerHighest,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                theme.colorScheme.primary,
                              ),
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$confidencePercent%',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
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
