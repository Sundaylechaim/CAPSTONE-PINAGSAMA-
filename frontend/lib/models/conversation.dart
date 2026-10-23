class Conversation {
  final int? id;
  final String text;
  final double confidence;
  final String source;
  final DateTime timestamp;
  final int isSynced;

  const Conversation({
    this.id,
    required this.text,
    required this.confidence,
    required this.source,
    required this.timestamp,
    this.isSynced = 0,
  });

  Conversation copyWith({
    int? id,
    String? text,
    double? confidence,
    String? source,
    DateTime? timestamp,
    int? isSynced,
  }) {
    return Conversation(
      id: id ?? this.id,
      text: text ?? this.text,
      confidence: confidence ?? this.confidence,
      source: source ?? this.source,
      timestamp: timestamp ?? this.timestamp,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        'confidence': confidence,
        'source': source,
        'timestamp': timestamp.toIso8601String(),
        'is_synced': isSynced,
      };

  factory Conversation.fromMap(Map<String, dynamic> map) => Conversation(
        id: map['id'] as int?,
        text: map['text'] as String,
        confidence: (map['confidence'] as num).toDouble(),
        source: map['source'] as String,
        timestamp: DateTime.parse(map['timestamp'] as String),
        isSynced: map['is_synced'] as int? ?? 0,
      );

  @override
  String toString() => 'Conversation(id: $id, text: $text, confidence: $confidence, source: $source, timestamp: $timestamp)';
}