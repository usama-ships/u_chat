import '../../core/constants/app_constants.dart';
import '../../core/database/daos/settings_dao.dart';
import '../../core/security/identity_service.dart';

/// Local user preferences. Currently: the display name shared with peers.
class SettingsRepository {
  SettingsRepository(this._dao, this._identity);

  static const _displayNameKey = 'display_name';
  static const _acceptUnknownKey = 'accept_unknown_devices';

  /// Whether devices we have never talked to may connect. Default: yes.
  Future<bool> getAcceptUnknownDevices() async =>
      (await _dao.getValue(_acceptUnknownKey)) != 'false';

  Stream<bool> watchAcceptUnknownDevices() =>
      _dao.watchValue(_acceptUnknownKey).map((v) => v != 'false');

  Future<void> setAcceptUnknownDevices(bool accept) =>
      _dao.setValue(_acceptUnknownKey, accept ? 'true' : 'false');

  final SettingsDao _dao;
  final IdentityService _identity;

  String get defaultDisplayName =>
      'User ${_identity.deviceId.substring(0, 4).toUpperCase()}';

  /// Writes defaults on first launch.
  Future<void> ensureDefaults() async {
    if (await _dao.getValue(_displayNameKey) == null) {
      await _dao.setValue(_displayNameKey, defaultDisplayName);
    }
  }

  Future<String> getDisplayName() async =>
      (await _dao.getValue(_displayNameKey)) ?? defaultDisplayName;

  Stream<String> watchDisplayName() =>
      _dao.watchValue(_displayNameKey).map((v) => v ?? defaultDisplayName);

  /// Throws [ArgumentError] if [name] is invalid (see [validateDisplayName]).
  Future<void> setDisplayName(String name) async {
    final error = validateDisplayName(name);
    if (error != null) throw ArgumentError(error);
    await _dao.setValue(_displayNameKey, name.trim());
  }

  /// Returns a user-facing error, or null if valid.
  static String? validateDisplayName(String raw) {
    final name = raw.trim();
    if (name.isEmpty) return 'Name cannot be empty';
    if (name.length > AppConstants.maxDisplayNameLength) {
      return 'Name must be at most ${AppConstants.maxDisplayNameLength} characters';
    }
    if (RegExp(r'[\x00-\x1F\x7F]').hasMatch(name)) return 'Name contains invalid characters';
    return null;
  }
}
