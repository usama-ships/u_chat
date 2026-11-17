import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// A finished recording, still in a temporary file.
class VoiceRecording {
  const VoiceRecording({required this.path, required this.durationMs, required this.levels});

  final String path;
  final int durationMs;

  /// Loudness over time, 0 to 1.
  final List<double> levels;
}

/// Microphone access, behind an interface so screens can be tested without one.
abstract interface class VoiceRecorder {
  /// Asks Android for the microphone if needed. False if refused.
  Future<bool> ensurePermission();

  /// Live loudness, 0 to 1, while recording.
  Stream<double> get levels;

  Future<void> start();

  /// Stops and returns the recording, or null if nothing usable was captured.
  Future<VoiceRecording?> stop();

  /// Stops and throws the recording away.
  Future<void> cancel();

  Future<void> dispose();
}

class DeviceVoiceRecorder implements VoiceRecorder {
  /// AAC at 24 kbps mono: clear for speech, about 3 KB per second, and
  /// recordable and playable on every Android version the app supports.
  static const _config = RecordConfig(
    encoder: AudioEncoder.aacLc,
    bitRate: 24000,
    sampleRate: 16000,
    numChannels: 1,
    noiseSuppress: true,
    autoGain: true,
  );

  /// Readings at or below this count as silence.
  static const _floorDb = -45.0;

  final _recorder = AudioRecorder();
  final _levels = StreamController<double>.broadcast();
  final _captured = <double>[];
  final _clock = Stopwatch();
  StreamSubscription<Amplitude>? _amplitude;

  @override
  Stream<double> get levels => _levels.stream;

  @override
  Future<bool> ensurePermission() => _recorder.hasPermission();

  @override
  Future<void> start() async {
    final dir = await getTemporaryDirectory();
    final path = p.join(dir.path, 'voice-${DateTime.now().microsecondsSinceEpoch}.m4a');
    _captured.clear();
    _amplitude = _recorder.onAmplitudeChanged(const Duration(milliseconds: 80)).listen((amplitude) {
      final level = ((amplitude.current - _floorDb) / -_floorDb).clamp(0.0, 1.0);
      // A curve lifts quiet speech, so the waveform doesn't look flat.
      final shaped = math.pow(level, 1.6).toDouble();
      _captured.add(shaped);
      _levels.add(shaped);
    });
    await _recorder.start(_config, path: path);
    _clock
      ..reset()
      ..start();
  }

  @override
  Future<VoiceRecording?> stop() async {
    _clock.stop();
    await _amplitude?.cancel();
    final path = await _recorder.stop();
    if (path == null || !File(path).existsSync()) return null;
    return VoiceRecording(
      path: path,
      durationMs: _clock.elapsedMilliseconds,
      levels: List.of(_captured),
    );
  }

  @override
  Future<void> cancel() async {
    _clock.stop();
    await _amplitude?.cancel();
    try {
      await _recorder.cancel();
    } catch (e) {
      debugPrint('Cancelling recording failed: $e');
    }
  }

  @override
  Future<void> dispose() async {
    await _amplitude?.cancel();
    await _levels.close();
    await _recorder.dispose();
  }
}
