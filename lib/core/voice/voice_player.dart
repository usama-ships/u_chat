import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';

/// Plays one voice message at a time, for the whole app.
class VoicePlayer extends GetxService {
  static const speeds = [1.0, 1.5, 2.0];

  /// The message loaded in the player, playing or paused.
  final currentId = RxnString();
  final isPlaying = false.obs;
  final position = Duration.zero.obs;
  final speed = 1.0.obs;

  AudioPlayer? _player;
  final _subscriptions = <StreamSubscription<Object?>>[];

  // Created on first use, so screens that never play audio don't need it.
  AudioPlayer get _audio {
    final existing = _player;
    if (existing != null) return existing;
    final player = AudioPlayer();
    _player = player;
    _subscriptions
      ..add(player.positionStream.listen((value) => position.value = value))
      ..add(
        player.playerStateStream.listen((state) {
          if (state.processingState == ProcessingState.completed) {
            unawaited(_rewind());
          } else {
            isPlaying.value = state.playing;
          }
        }),
      );
    return player;
  }

  Future<void> _rewind() async {
    isPlaying.value = false;
    await _audio.pause();
    await _audio.seek(Duration.zero);
    currentId.value = null;
    position.value = Duration.zero;
  }

  /// Plays [path], or pauses if [id] is what's already playing.
  Future<void> toggle(String id, String path) async {
    try {
      if (currentId.value == id) {
        if (isPlaying.value) {
          await _audio.pause();
        } else {
          unawaited(_audio.play());
        }
        return;
      }
      currentId.value = id;
      position.value = Duration.zero;
      await _audio.setFilePath(path);
      await _audio.setSpeed(speed.value);
      unawaited(_audio.play());
    } catch (e) {
      debugPrint('Playing $id failed: $e');
      currentId.value = null;
      isPlaying.value = false;
    }
  }

  Future<void> seek(Duration to) async {
    position.value = to;
    await _audio.seek(to);
  }

  Future<void> cycleSpeed() async {
    final next = speeds[(speeds.indexOf(speed.value) + 1) % speeds.length];
    speed.value = next;
    await _player?.setSpeed(next);
  }

  Future<void> stop() async {
    currentId.value = null;
    isPlaying.value = false;
    position.value = Duration.zero;
    await _player?.stop();
  }

  @override
  void onClose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _player?.dispose();
    super.onClose();
  }
}
