import 'dart:convert';

/// What a voice message row stores in `content`, and what crosses the link in
/// the `message` frame. The audio itself travels separately, in chunks.
///
/// ```json
/// {"d":12400,"s":37200,"h":"<sha-256 hex>","w":"<one hex byte per bar>"}
/// ```
class VoiceMeta {
  const VoiceMeta({
    required this.durationMs,
    required this.sizeBytes,
    required this.sha256,
    required this.waveform,
  });

  /// Recording stops at [maxRecordingMs]; the slack covers encoder rounding.
  static const maxRecordingMs = 2 * 60 * 1000;
  static const _maxDurationMs = maxRecordingMs + 2000;

  /// About 2.5x what two minutes really takes, so a bad peer can't fill the disk.
  static const maxBytes = 1024 * 1024;

  /// Bars in a waveform.
  static const waveformBars = 48;

  static final _sha256Pattern = RegExp(r'^[0-9a-f]{64}$');
  static final _hexPattern = RegExp(r'^([0-9a-f]{2})*$');

  final int durationMs;
  final int sizeBytes;
  final String sha256;

  /// Bar heights, 0 to 255.
  final List<int> waveform;

  String encode() => jsonEncode({
    'd': durationMs,
    's': sizeBytes,
    'h': sha256,
    'w': waveform.map((v) => v.toRadixString(16).padLeft(2, '0')).join(),
  });

  /// Throws [FormatException] for anything malformed.
  static VoiceMeta decode(String content) {
    final Object? json;
    try {
      json = jsonDecode(content);
    } catch (_) {
      throw const FormatException('voice metadata is not JSON');
    }
    if (json is! Map<String, Object?>) throw const FormatException('bad voice metadata');

    final duration = json['d'];
    final size = json['s'];
    final hash = json['h'];
    final wave = json['w'];
    if (duration is! int || duration <= 0 || duration > _maxDurationMs) {
      throw const FormatException('bad voice duration');
    }
    if (size is! int || size <= 0 || size > maxBytes) {
      throw const FormatException('bad voice size');
    }
    if (hash is! String || !_sha256Pattern.hasMatch(hash)) {
      throw const FormatException('bad voice hash');
    }
    if (wave is! String || wave.length > waveformBars * 2 || !_hexPattern.hasMatch(wave)) {
      throw const FormatException('bad voice waveform');
    }
    return VoiceMeta(
      durationMs: duration,
      sizeBytes: size,
      sha256: hash,
      waveform: [
        for (var i = 0; i < wave.length; i += 2) int.parse(wave.substring(i, i + 2), radix: 16),
      ],
    );
  }

  /// Shown in the conversation list.
  String get previewLabel => 'Voice message · ${formatVoiceDuration(durationMs)}';

  /// Squeezes loudness samples (0 to 1) into [waveformBars] bars, keeping the
  /// peak of each slice so short syllables stay visible.
  static List<int> barsFrom(List<double> levels) {
    if (levels.isEmpty) return List.filled(waveformBars, 0);
    return List.generate(waveformBars, (bar) {
      final start = bar * levels.length ~/ waveformBars;
      final end = ((bar + 1) * levels.length / waveformBars).ceil().clamp(start + 1, levels.length);
      var peak = 0.0;
      for (var i = start; i < end && i < levels.length; i++) {
        if (levels[i] > peak) peak = levels[i];
      }
      return (peak.clamp(0.0, 1.0) * 255).round();
    });
  }
}

/// `0:07`, `1:42`.
String formatVoiceDuration(int ms) {
  final seconds = (ms / 1000).round();
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}
