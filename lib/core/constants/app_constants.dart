/// App-wide limits and keys. Payload limits are enforced both when composing
/// and (from Phase 4) when validating data received over Bluetooth.
abstract final class AppConstants {
  static const appName = 'U Chat';

  /// Maximum length of a text message body, in UTF-16 code units.
  static const maxTextLength = 4000;

  /// Maximum length of a user display name.
  static const maxDisplayNameLength = 32;
}
