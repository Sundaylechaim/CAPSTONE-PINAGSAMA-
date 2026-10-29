import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';

class OfflineEnglishTtsService {
  static const archiveUrl =
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/'
      'tts-models/kokoro-int8-multi-lang-v1_1.tar.bz2';
  static const archiveSize = 147031220;
  static const archiveSha256 =
      'a1e94694776049035c4f2c6529f003aaece993c76aae9a78995831c3c4dcafc6';
  static const voices = {
    'af_maple': (speakerId: 0, label: 'Maple · Female · US'),
    'af_sol': (speakerId: 1, label: 'Sol · Female · US'),
    'bf_vale': (speakerId: 2, label: 'Vale · Female · UK'),
  };

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(minutes: 30),
    ),
  );
  OfflineTts? _engine;
  String? _loadedDirectory;

  Future<bool> isInstalled() async {
    final directory = await _modelDirectory();
    return _hasRequiredFiles(directory);
  }

  Future<void> install({
    required void Function(int received, int total) onProgress,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError(
        'The offline English voice is only available in the mobile app.',
      );
    }
    if (await isInstalled()) return;

    final supportDirectory = await getApplicationSupportDirectory();
    final archivePath = p.join(
      supportDirectory.path,
      'kokoro-int8-multi-lang-v1_1.tar.bz2.part',
    );
    final stagingPath = p.join(supportDirectory.path, 'kokoro-en-v1_1.staging');
    final targetPath = p.join(supportDirectory.path, 'kokoro-en-v1_1');
    final archiveFile = File(archivePath);
    final stagingDirectory = Directory(stagingPath);

    try {
      await _dio.download(
        archiveUrl,
        archivePath,
        onReceiveProgress: onProgress,
        deleteOnError: true,
      );
      if (await archiveFile.length() != archiveSize) {
        throw StateError(
          'The downloaded English voice pack has an invalid size.',
        );
      }
      final digest = await sha256.bind(archiveFile.openRead()).first;
      if (digest.toString() != archiveSha256) {
        throw StateError(
          'The downloaded English voice pack failed verification.',
        );
      }

      if (await stagingDirectory.exists()) {
        await stagingDirectory.delete(recursive: true);
      }
      await stagingDirectory.create(recursive: true);
      await Isolate.run(() => _extractVoicePack(archivePath, stagingPath));
      if (!await _hasRequiredFiles(stagingPath)) {
        throw StateError(
          'The English voice pack is incomplete after extraction.',
        );
      }

      _engine?.free();
      _engine = null;
      _loadedDirectory = null;
      final existingDirectory = Directory(targetPath);
      if (await existingDirectory.exists()) {
        await existingDirectory.delete(recursive: true);
      }
      await stagingDirectory.rename(targetPath);
    } finally {
      if (await archiveFile.exists()) {
        await archiveFile.delete();
      }
      if (await stagingDirectory.exists()) {
        await stagingDirectory.delete(recursive: true);
      }
    }
  }

  GeneratedAudio generate({
    required String text,
    required String voice,
    required double speed,
  }) {
    final voiceDetails = voices[voice];
    if (voiceDetails == null) {
      throw ArgumentError.value(voice, 'voice', 'Unsupported English voice.');
    }
    final directory = _loadedDirectory;
    if (_engine == null || directory == null) {
      throw StateError('The offline English voice has not been initialized.');
    }
    return _engine!.generate(
      text: text,
      sid: voiceDetails.speakerId,
      speed: speed,
    );
  }

  Future<void> initialize() async {
    final directory = await _modelDirectory();
    if (!await _hasRequiredFiles(directory)) {
      throw StateError(
        'Download an offline English voice in Settings before using it.',
      );
    }
    if (_engine != null && _loadedDirectory == directory) return;

    _engine?.free();
    initBindings();
    _engine = OfflineTts(
      OfflineTtsConfig(
        model: OfflineTtsModelConfig(
          numThreads: 2,
          debug: false,
          kokoro: OfflineTtsKokoroModelConfig(
            model: p.join(directory, 'model.int8.onnx'),
            voices: p.join(directory, 'voices.bin'),
            tokens: p.join(directory, 'tokens.txt'),
            dataDir: p.join(directory, 'espeak-ng-data'),
            lexicon:
                '${p.join(directory, 'lexicon-us-en.txt')},'
                '${p.join(directory, 'lexicon-zh.txt')}',
            lang: 'a',
          ),
        ),
      ),
    );
    _loadedDirectory = directory;
  }

  void dispose() {
    _engine?.free();
    _engine = null;
    _loadedDirectory = null;
  }

  Future<String> _modelDirectory() async {
    final supportDirectory = await getApplicationSupportDirectory();
    return p.join(supportDirectory.path, 'kokoro-en-v1_1');
  }

  static Future<bool> _hasRequiredFiles(String directory) async {
    const requiredFiles = [
      'model.int8.onnx',
      'voices.bin',
      'tokens.txt',
      'lexicon-us-en.txt',
      'lexicon-zh.txt',
    ];
    for (final fileName in requiredFiles) {
      if (!await File(p.join(directory, fileName)).exists()) return false;
    }
    return Directory(p.join(directory, 'espeak-ng-data')).exists();
  }
}

void _extractVoicePack(String archivePath, String destinationPath) {
  final archiveInput = InputFileStream(archivePath);
  try {
    final tarInput = BZip2Decoder().decodeLazy(archiveInput, verify: true);
    TarDecoder().decodeStream(
      tarInput,
      verify: true,
      storeData: true,
      keepEntries: false,
      callback: (entry) {
        if (entry.isSymbolicLink) {
          throw const FormatException(
            'Symbolic links are not allowed in voice packs.',
          );
        }
        final relativePath = _voicePackRelativePath(entry.name);
        if (relativePath == null) {
          return;
        }
        final outputPath = p.joinAll([
          destinationPath,
          ...p.posix.split(relativePath),
        ]);
        if (entry.isDirectory) {
          Directory(outputPath).createSync(recursive: true);
          return;
        }

        final outputDirectory = Directory(p.dirname(outputPath));
        outputDirectory.createSync(recursive: true);
        final output = OutputFileStream(outputPath);
        try {
          entry.writeContent(output);
        } finally {
          output.closeSync();
        }
      },
    );
  } finally {
    archiveInput.closeSync();
  }
}

String? _voicePackRelativePath(String archivePath) {
  final normalized = p.posix.normalize(archivePath);
  if (normalized.startsWith('/') || normalized == '..') {
    throw const FormatException('Invalid path in English voice pack.');
  }
  final segments = p.posix
      .split(normalized)
      .where((segment) => segment.isNotEmpty && segment != '.')
      .toList();
  if (segments.isEmpty || segments.contains('..')) {
    throw const FormatException('Invalid path in English voice pack.');
  }
  if (const {
    'kokoro-int8-multi-lang-v1_1',
    'kokoro-multi-lang-v1_1',
  }.contains(segments.first)) {
    segments.removeAt(0);
  }
  if (segments.isEmpty) return null;

  final relativePath = p.posix.joinAll(segments);
  if (const {
        'model.int8.onnx',
        'model.onnx',
        'voices.bin',
        'tokens.txt',
        'lexicon-us-en.txt',
        'lexicon-zh.txt',
        'LICENSE',
      }.contains(relativePath) ||
      relativePath.startsWith('espeak-ng-data/')) {
    return relativePath;
  }
  return null;
}
