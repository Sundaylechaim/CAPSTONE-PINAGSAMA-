import 'package:flutter_test/flutter_test.dart';
import 'package:tinigsenyas/services/speech_transcript_session.dart';

void main() {
  group('SpeechTranscriptSession', () {
    test('commits a final result only once', () {
      final session = SpeechTranscriptSession();

      expect(session.addResult('hello there', isFinal: false), isNull);
      expect(session.addResult('hello there', isFinal: true), 'hello there');
      expect(session.addResult('hello there', isFinal: true), isNull);
      expect(session.finish(), isNull);
    });

    test('finishes partial words only once when listening stops', () {
      final session = SpeechTranscriptSession();

      session.addResult('good morning', isFinal: false);

      expect(session.finish(), 'good morning');
      expect(session.finish(), isNull);
    });

    test('allows the same phrase in a new listening session', () {
      final session = SpeechTranscriptSession();

      expect(session.addResult('yes', isFinal: true), 'yes');
      session.reset();
      expect(session.addResult('yes', isFinal: true), 'yes');
    });

    test('discards partial words after a recognition error', () {
      final session = SpeechTranscriptSession();

      session.addResult('unfinished phrase', isFinal: false);
      session.cancel();

      expect(session.finish(), isNull);
    });
  });
}
