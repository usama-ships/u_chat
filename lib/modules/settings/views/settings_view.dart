import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/bluetooth/models/ble_availability.dart';
import '../../../core/constants/app_constants.dart';
import '../controllers/settings_controller.dart';

class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Identity'),
          Obx(() => ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Display name'),
                subtitle: Text(controller.displayName.value),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => _editName(context),
              )),
          ListTile(
            leading: const Icon(Icons.fingerprint),
            title: const Text('Device ID'),
            subtitle: SelectableText(
              controller.deviceId,
              style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
            ),
            trailing: IconButton(
              tooltip: 'Copy',
              icon: const Icon(Icons.copy),
              onPressed: controller.copyDeviceId,
            ),
          ),
          const _SectionHeader('Bluetooth'),
          const _BluetoothStatusTiles(),
          const _SectionHeader('Privacy & security'),
          Obx(() => SwitchListTile(
                secondary: const Icon(Icons.person_add_alt),
                title: const Text('Accept new devices'),
                subtitle: const Text(
                  'Allow phones you have never chatted with to connect. Turn off to allow '
                  'only existing contacts.',
                ),
                value: controller.acceptUnknownDevices.value,
                onChanged: controller.setAcceptUnknownDevices,
              )),
          const ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('End-to-end encrypted'),
            subtitle: Text(
              'Every connection uses fresh keys (X25519) and every message is encrypted and '
              'tamper-proof (AES-256-GCM). Each phone proves its identity with a digital '
              'signature (Ed25519).',
            ),
          ),
          const ListTile(
            leading: Icon(Icons.verified_outlined),
            title: Text('Verify your contacts'),
            subtitle: Text(
              'Open a contact and compare the safety number with them in person. Matching '
              'numbers mean nobody is impersonating them.',
            ),
          ),
          const ListTile(
            leading: Icon(Icons.cloud_off_outlined),
            title: Text('Fully offline, stored only here'),
            subtitle: Text(
              '${AppConstants.appName} talks to nearby phones over Bluetooth only. No servers, '
              'no accounts, no internet. Chats live in app-private storage protected by '
              "Android's device encryption and are excluded from backups.",
            ),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('About'),
            subtitle: Text('${AppConstants.appName} 1.0.0 · protocol v2'),
          ),
          if (kDebugMode) ...[
            const _SectionHeader('Debug'),
            ListTile(
              leading: const Icon(Icons.bug_report_outlined),
              title: const Text('Create test conversation'),
              subtitle: const Text('Local only, to try the chat UI. Messages stay pending.'),
              onTap: controller.createDebugConversation,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _editName(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => _EditNameDialog(
        initial: controller.displayName.value,
        onSave: controller.updateDisplayName,
      ),
    );
  }
}

class _BluetoothStatusTiles extends GetView<SettingsController> {
  const _BluetoothStatusTiles();

  @override
  Widget build(BuildContext context) {
    final bt = controller.bluetooth;
    return Obx(() {
      final (IconData icon, String status) = switch (bt.availability.value) {
        BleAvailability.unknown => (Icons.bluetooth, 'Checking…'),
        BleAvailability.unsupported => (Icons.bluetooth_disabled, 'Not supported on this phone'),
        BleAvailability.unauthorized => (Icons.lock_outline, 'Permission not granted'),
        BleAvailability.poweredOff => (Icons.bluetooth_disabled, 'Bluetooth is off'),
        BleAvailability.ready => (Icons.bluetooth_connected, 'Ready'),
      };
      final String visibility;
      if (!bt.advertisingSupported.value) {
        visibility = "This phone can't advertise. Others can't find it, but it can find them.";
      } else if (bt.isAdvertising.value) {
        visibility = 'Visible to nearby U Chat users while the app is open';
      } else if (bt.advertisingError.value != null) {
        visibility = bt.advertisingError.value!;
      } else {
        visibility = 'Not visible';
      }
      return Column(
        children: [
          ListTile(
            leading: Icon(icon),
            title: const Text('Status'),
            subtitle: Text(status),
            trailing: bt.availability.value == BleAvailability.unauthorized
                ? TextButton(
                    onPressed: controller.fixBluetoothPermission,
                    child: Text(bt.permissionDenied.value ? 'Settings' : 'Allow'),
                  )
                : null,
          ),
          ListTile(
            leading: Icon(bt.isAdvertising.value ? Icons.visibility : Icons.visibility_off_outlined),
            title: const Text('Visibility'),
            subtitle: Text(visibility),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Permissions'),
            subtitle: Text(
              'Uses "Nearby devices" (Android 12+) or Location (Android 11 and older, '
              'required by Android for Bluetooth scanning). Location is never read.',
            ),
          ),
        ],
      );
    });
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
      ),
    );
  }
}

class _EditNameDialog extends StatefulWidget {
  const _EditNameDialog({required this.initial, required this.onSave});

  final String initial;
  final Future<String?> Function(String) onSave;

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  late final TextEditingController _text = TextEditingController(text: widget.initial);
  String? _error;
  bool _saving = false;

  Future<void> _submit() async {
    setState(() => _saving = true);
    final error = await widget.onSave(_text.text);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _error = error;
        _saving = false;
      });
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Display name'),
      content: TextField(
        controller: _text,
        autofocus: true,
        maxLength: AppConstants.maxDisplayNameLength,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(errorText: _error),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _submit, child: const Text('Save')),
      ],
    );
  }
}
