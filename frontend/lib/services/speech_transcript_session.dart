class SpeechTranscriptSession {
  String _partialWords = '';
  bool _isFinalized = false;

  bool get isFinalized => _isFinalized;

  String? addResult(String words, {required bool isFinal}) {
    if (_isFinalized) return null;
    if (!isFinal) {
      _partialWords = words;
      return null;
    }

    _isFinalized = true;
    _partialWords = '';
    return words.isEmpty ? null : words;
  }

  String? finish() {
    if (_isFinalized) return null;
    _isFinalized = true;
    final words = _partialWords.trim();
    _partialWords = '';
    return words.isEmpty ? null : words;
  }

  void reset() {
    _partialWords = '';
    _isFinalized = false;
  }

  void cancel() {
    _partialWords = '';
    _isFinalized = true;
  }
}
