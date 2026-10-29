class SignResult {
  final String label;
  final double confidence;
  final DateTime timestamp;
  final String source;

  const SignResult({
    required this.label,
    required this.confidence,
    required this.timestamp,
    this.source = 'sign',
  });

  SignResult copyWith({
    String? label,
    double? confidence,
    DateTime? timestamp,
    String? source,
  }) {
    return SignResult(
      label: label ?? this.label,
      confidence: confidence ?? this.confidence,
      timestamp: timestamp ?? this.timestamp,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'confidence': confidence,
        'timestamp': timestamp.toIso8601String(),
        'source': source,
      };

  factory SignResult.fromJson(Map<String, dynamic> json) => SignResult(
        label: json['label'] as String,
        confidence: (json['confidence'] as num).toDouble(),
        timestamp: DateTime.parse(json['timestamp'] as String),
        source: json['source'] as String? ?? 'sign',
      );

  @override
  String toString() => 'SignResult(label: $label, confidence: $confidence, timestamp: $timestamp)';
}