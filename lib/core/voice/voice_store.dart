import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

import 'voice_meta.dart';

/// Audio files in app-private storage: `voice/<conversation>/<message>.m4a`.
///
/// A file only gets its final name once its SHA-256 has been verified, so
/// "the file exists" always means "the audio is complete and intact".
class VoiceStore {
  VoiceStore(Directory appStorage) : _root = Directory(p.join(appStorage.path, 'voice'));

  final Directory _root;

  File audioFile(String conversationId, String messageId) =>
      File(p.join(_root.path, conversationId, '$messageId.m4a'));

  File _partFile(String conversationId, String messageId) =>
      File(p.join(_root.path, conversationId, '$messageId.part'));

  bool hasAudio(String conversationId, String messageId) =>
      audioFile(conversationId, messageId).existsSync();

  /// Moves a finished recording into the store and measures it.
  Future<({int size, String sha256})> adopt(
    String recordingPath,
    String conversationId,
    String messageId,
  ) async {
    final target = audioFile(conversationId, messageId);
    await target.parent.create(recursive: true);
    final source = File(recordingPath);
    try {
      await source.rename(target.path);
    } on FileSystemException {
      // Rename fails across volumes.
      await source.copy(target.path);
      await source.delete();
    }
    final bytes = await target.readAsBytes();
    return (size: bytes.length, sha256: crypto.sha256.convert(bytes).toString());
  }

  /// How much of an incoming file has arrived so far.
  Future<int> partialLength(String conversationId, String messageId) async {
    final part = _partFile(conversationId, messageId);
    return await part.exists() ? part.length() : 0;
  }

  Future<void> appendPartial(String conversationId, String messageId, Uint8List bytes) async {
    final part = _partFile(conversationId, messageId);
    await part.parent.create(recursive: true);
    await part.writeAsBytes(bytes, mode: FileMode.append, flush: true);
  }

  Future<void> discardPartial(String conversationId, String messageId) async {
    final part = _partFile(conversationId, messageId);
    if (await part.exists()) await part.delete();
  }

  /// Promotes a fully received file if it matches [meta]. Returns false, and
  /// leaves no file behind, if it doesn't.
  Future<bool> completePartial(String conversationId, String messageId, VoiceMeta meta) async {
    final part = _partFile(conversationId, messageId);
    final bytes = await part.readAsBytes();
    if (bytes.length != meta.sizeBytes || crypto.sha256.convert(bytes).toString() != meta.sha256) {
      await part.delete();
      return false;
    }
    await part.rename(audioFile(conversationId, messageId).path);
    return true;
  }

  /// Up to [length] bytes from [offset], or null if the file is gone.
  Future<Uint8List?> read(String conversationId, String messageId, int offset, int length) async {
    final file = audioFile(conversationId, messageId);
    if (!await file.exists()) return null;
    final handle = await file.open();
    try {
      await handle.setPosition(offset);
      return await handle.read(length);
    } finally {
      await handle.close();
    }
  }

  Future<void> deleteMessage(String conversationId, String messageId) async {
    final file = audioFile(conversationId, messageId);
    if (await file.exists()) await file.delete();
  }

  Future<void> deleteConversation(String conversationId) async {
    final dir = Directory(p.join(_root.path, conversationId));
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}
