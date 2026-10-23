import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/tts_service.dart';
import '../services/database_helper.dart';
import '../services/speech_transcript_session.dart';
import '../widgets/connectivity_badge.dart';

class SpeechToTextScreen extends StatefulWidget {
  const SpeechToTextScreen({super.key});

  @override
  State<SpeechToTextScreen> createState() => _SpeechToTextScreenState();
}

class _SpeechToTextScreenState extends State<SpeechToTextScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final SpeechTranscriptSession _transcriptSession = SpeechTranscriptSession();
  bool _isListening = false;
  String _currentWords = '';
  final List<String> _messages = [];
  bool _speechAvailable = false;
  String? _speechError;
  bool _isStarting = false;
  bool _isStopping = false;
  int _activeSessionId = 0;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
      );
      if (mounted) {
        setState(() {
          _speechAvailable = available;
          if (!available) {
            _speechError =
                'Speech recognition is not available on this device.';
          }
        });
      }
    } catch (error) {
      if (mounted) setState(() => _speechError = error.toString());
    }
  }

  void _onSpeechStatus(String status) {
    if (status != 'done' && status != 'notListening') return;
    if (!mounted) return;
    setState(() {
      _finalizeCurrentWords();
      _isListening = false;
    });
  }

  void _finalizeCurrentWords() {
    final words = _transcriptSession.finish();
    if (words != null) _messages.add(words);
    _currentWords = '';
  }

  void _onSpeechError(dynamic error) {
    if (!mounted) return;
    setState(() {
      _speechError = error.toString();
      _currentWords = '';
      _transcriptSession.cancel();
    });
    unawaited(_stopListening(_activeSessionId, finalizePartial: false));
  }

  Future<void> _toggleListen() async {
    if (!_isListening) {
      if (_isStarting || _isStopping) return;
      if (!_speechAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _speechError ?? 'Speech recognition unavailable on this device',
            ),
          ),
        );
        return;
      }

      setState(() {
        _isStarting = true;
        _isListening = true;
        _currentWords = 'Listening...';
        _speechError = null;
        _transcriptSession.reset();
        _activeSessionId++;
      });
      final sessionId = _activeSessionId;

      try {
        await _speech.listen(
          listenOptions: stt.SpeechListenOptions(
            partialResults: true,
            listenMode: stt.ListenMode.dictation,
            pauseFor: Duration(seconds: 3),
            cancelOnError: true,
          ),
          onResult: (result) {
            if (!mounted ||
                sessionId != _activeSessionId ||
                _transcriptSession.isFinalized) {
              return;
            }
            final words = result.recognizedWords.trim();
            final finalWords = _transcriptSession.addResult(
              words,
              isFinal: result.finalResult,
            );
            setState(() {
              _currentWords = result.finalResult ? '' : words;
              if (finalWords != null) _messages.add(finalWords);
            });
            if (result.finalResult) {
              unawaited(_stopAfterFinalResult(sessionId));
            }
          },
        );
      } catch (error) {
        if (mounted) {
          setState(() {
            _speechError = error.toString();
            _isListening = false;
            _currentWords = '';
          });
        }
      } finally {
        if (mounted && sessionId == _activeSessionId) {
          setState(() => _isStarting = false);
        }
      }
    } else {
      await _stopListening(_activeSessionId);
    }
  }

  Future<void> _stopAfterFinalResult(int sessionId) async {
    await _stopListening(sessionId, finalizePartial: false);
  }

  Future<void> _stopListening(
    int sessionId, {
    bool finalizePartial = true,
  }) async {
    if (_isStopping || sessionId != _activeSessionId) return;
    setState(() => _isStopping = true);
    try {
      await _speech.stop();
    } catch (error) {
      if (mounted) setState(() => _speechError = error.toString());
    } finally {
      if (mounted && sessionId == _activeSessionId) {
        setState(() {
          if (finalizePartial) _finalizeCurrentWords();
          _isListening = false;
          _isStopping = false;
        });
      }
    }
  }

  Future<void> _speakMessage(String message) async {
    try {
      await context.read<TtsService>().speak(message);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not play speech: $error')),
        );
      }
    }
  }

  Future<void> _saveMessage(String message) async {
    try {
      await DatabaseHelper.instance.saveRecognizedGesture(
        message,
        0,
        source: 'speech',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved to History!'),
            duration: Duration(milliseconds: 800),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save message: $error')),
        );
      }
    }
  }

  @override
  void dispose() {
    unawaited(_speech.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Speech to Text'),
        actions: [const ConnectivityBadge(), const SizedBox(width: 16)],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            if (_speechError != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _speechError!,
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                    if (!_speechAvailable)
                      TextButton(
                        onPressed: _initSpeech,
                        child: const Text('Retry'),
                      ),
                  ],
                ),
              ),
            // Chat Messages
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: _messages.isEmpty && _currentWords.isEmpty
                    ? Center(
                        child: Text(
                          'No messages yet.\nTap the mic below and start speaking!',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView(
                        children: [
                          ..._messages.map(
                            (msg) => _buildMessageBubble(msg, isFinal: true),
                          ),
                          if (_isListening && _currentWords.isNotEmpty)
                            _buildMessageBubble(_currentWords, isFinal: false),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // Microphone Button
            FloatingActionButton.extended(
              onPressed: _speechAvailable && !_isStarting && !_isStopping
                  ? _toggleListen
                  : null,
              backgroundColor: _isListening
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
              foregroundColor: _isListening
                  ? theme.colorScheme.onError
                  : theme.colorScheme.onPrimary,
              icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
              label: Text(
                _isStarting
                    ? 'Starting...'
                    : _isStopping
                    ? 'Finishing...'
                    : _isListening
                    ? 'Stop listening'
                    : 'Tap to Speak',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(String message, {required bool isFinal}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isFinal
                    ? theme.colorScheme.primary
                    : theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      message,
                      style: TextStyle(
                        color: isFinal
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onPrimaryContainer,
                        fontSize: 16,
                        fontWeight: isFinal
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontStyle: isFinal
                            ? FontStyle.normal
                            : FontStyle.italic,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isFinal) ...[
                    IconButton(
                      icon: Icon(
                        Icons.volume_up,
                        size: 18,
                        color: isFinal
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onPrimaryContainer,
                      ),
                      onPressed: () => _speakMessage(message),
                      tooltip: 'Speak',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.save,
                        size: 18,
                        color: isFinal
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onPrimaryContainer,
                      ),
                      onPressed: () => _saveMessage(message),
                      tooltip: 'Save to History',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
