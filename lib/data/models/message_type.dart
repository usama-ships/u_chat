/// Kind of message payload. Stored by name, so adding a kind needs no migration.
enum MessageType {
  text,

  /// `content` holds a `VoiceMeta`; the audio lives in a file.
  voice,
}
