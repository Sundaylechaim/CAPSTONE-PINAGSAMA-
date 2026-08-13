import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechToSignScreen extends StatefulWidget {
  const SpeechToSignScreen({super.key});

  @override
  State<SpeechToSignScreen> createState() => _SpeechToSignScreenState();
}

class _SpeechToSignScreenState extends State<SpeechToSignScreen> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _recognizedWords = "Tap the mic and speak...";
  double _confidenceLevel = 1.0;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) => print('onStatus: $val'),
        onError: (val) => print('onError: $val'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            _recognizedWords = val.recognizedWords;
            if (val.hasConfidenceRating && val.confidence > 0) {
              _confidenceLevel = val.confidence;
            }
          }),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF64B5F6),
        title: const Text('Speech to Sign', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Transcription Display Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFBBDEFB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Text('Recognized Speech:', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 12),
                  Text(
                    _recognizedWords,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  const SizedBox(height: 8),
                  Text('Confidence: ${(_confidenceLevel * 100).toStringAsFixed(1)}%', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // FSL Visual Output Placeholder (Where sign animations/images will go)
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Center(
                  child: Text(
                    'FSL Sign Animations / Images\nwill display here based on speech.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Microphone Toggle Button
            FloatingActionButton.extended(
              onPressed: _listen,
              backgroundColor: _isListening ? Colors.redAccent : const Color(0xFF03A9F4),
              icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
              label: Text(_isListening ? 'Listening...' : 'Tap to Speak'),
            ),
          ],
        ),
      ),
    );
  }
}