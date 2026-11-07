import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_motion.dart';
import '../../../app/widgets/buttons.dart';
import '../../../app/widgets/glass.dart';
import '../../../app/widgets/motion.dart';
import '../../../app/widgets/overlays.dart';
import '../../../app/widgets/peer_avatar.dart';
import '../../../app/widgets/pressable.dart';
import '../../../app/widgets/responsive.dart';
import '../../../app/widgets/silver_backdrop.dart';
import '../../../core/bluetooth/models/ble_availability.dart';
import '../../../core/constants/app_constants.dart';
import '../controllers/settings_controller.dart';

class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final gutter = Responsive.gutter(context);
    final stagger = Stagger(step: const Duration(milliseconds: 70));

    final sections = <Widget>[
      _ProfileCard(onEdit: () => _editName(context)),
      const GlassSection(title: 'Bluetooth', children: [_BluetoothStatusTiles()]),
      GlassSection(
        title: 'Privacy & security',
        children: [
          Obx(
            () => GlassSwitchTile(
              icon: Icons.person_add_alt_rounded,
              title: 'Accept new devices',
              subtitle:
                  'Allow phones you have never chatted with to connect. Turn off to allow '
                  'only existing contacts.',
              value: controller.acceptUnknownDevices.value,
              onChanged: controller.setAcceptUnknownDevices,
            ),
          ),
          const GlassTile(
            icon: Icons.lock_outline_rounded,
            title: 'End-to-end encrypted',
            subtitle:
                'Every connection uses fresh keys (X25519) and every message is encrypted '
                'and tamper-proof (AES-256-GCM). Each phone proves its identity with a digital '
                'signature (Ed25519).',
          ),
          const GlassTile(
            icon: Icons.verified_outlined,
            title: 'Verify your contacts',
            subtitle:
                'Open a contact and compare the safety number with them in person. '
                'Matching numbers mean nobody is impersonating them.',
          ),
          const GlassTile(
            icon: Icons.cloud_off_outlined,
            title: 'Fully offline, stored only here',
            subtitle:
                '${AppConstants.appName} talks to nearby phones over Bluetooth only. No '
                'servers, no accounts, no internet. Chats live in app-private storage protected '
                "by Android's device encryption and are excluded from backups.",
          ),
        ],
      ),
      const GlassSection(
        title: 'About',
        children: [
          GlassTile(
            icon: Icons.info_outline_rounded,
            title: AppConstants.appName,
            subtitle: 'Version 1.0.0 · protocol v2',
          ),
        ],
      ),
      if (kDebugMode)
        GlassSection(
          title: 'Debug',
          children: [
            GlassTile(
              icon: Icons.bug_report_outlined,
              title: 'Create test conversation',
              subtitle: 'Local only, to try the chat UI. Messages stay pending.',
              onTap: controller.createDebugConversation,
            ),
          ],
        ),
    ];

    return GlassScaffold(
      appBar: GlassBar.text('Settings'),
      // Builder: the clearance for the glass bar only exists below the Scaffold.
      body: Builder(
        builder: (context) {
          final inset = MediaQuery.paddingOf(context);
          return ListView.separated(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            padding: EdgeInsets.fromLTRB(gutter, inset.top + 16, gutter, inset.bottom + 28),
            itemCount: sections.length,
            separatorBuilder: (_, _) => const SizedBox(height: 24),
            itemBuilder: (_, index) =>
                Entrance(delay: stagger.delayFor(index), child: sections[index]),
          );
        },
      ),
    );
  }

  Future<void> _editName(BuildContext context) {
    return showGlassDialog<void>(
      context,
      (_) => _EditNameDialog(
        initial: controller.displayName.value,
        onSave: controller.updateDisplayName,
      ),
    );
  }
}

/// Who you appear as to other people.
class _ProfileCard extends GetView<SettingsController> {
  const _ProfileCard({required this.onEdit});

  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Pressable(
            onTap: onEdit,
            pressedScale: 0.985,
            semanticLabel: 'Edit display name',
            child: Row(
              children: [
                Obx(
                  () => PeerAvatar(
                    seed: controller.deviceId,
                    name: controller.displayName.value,
                    size: 60,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Obx(
                        () => AnimatedSwitcher(
                          duration: Motion.medium,
                          layoutBuilder: startAlignedLayout,
                          transitionBuilder: fadeLiftTransition,
                          child: Text(
                            controller.displayName.value,
                            key: ValueKey(controller.displayName.value),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text('Your name on nearby phones', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.edit_outlined, size: 20, color: AppColors.silver300),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Divider(),
          Row(
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 4, right: 10),
                child: Icon(Icons.fingerprint_rounded, size: 18, color: AppColors.silver400),
              ),
              Expanded(
                child: SelectableText(
                  controller.deviceId,
                  maxLines: 1,
                  style: theme.textTheme.bodySmall?.copyWith(letterSpacing: 0.4),
                ),
              ),
              IconButton(
                tooltip: 'Copy',
                icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.silver300),
                onPressed: controller.copyDeviceId,
              ),
            ],
          ),
        ],
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
        BleAvailability.unknown => (Icons.bluetooth_rounded, 'Checking…'),
        BleAvailability.unsupported => (
          Icons.bluetooth_disabled_rounded,
          'Not supported on this phone',
        ),
        BleAvailability.unauthorized => (Icons.lock_outline_rounded, 'Permission not granted'),
        BleAvailability.poweredOff => (Icons.bluetooth_disabled_rounded, 'Bluetooth is off'),
        BleAvailability.ready => (Icons.bluetooth_connected_rounded, 'Ready'),
      };
      final ready = bt.availability.value == BleAvailability.ready;
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassTile(
            icon: icon,
            iconColor: ready ? AppColors.bronze400 : AppColors.silver200,
            title: 'Status',
            subtitle: status,
            trailing: bt.availability.value == BleAvailability.unauthorized
                ? GhostButton(
                    label: bt.permissionDenied.value ? 'Settings' : 'Allow',
                    dense: true,
                    onPressed: controller.fixBluetoothPermission,
                  )
                : null,
          ),
          const Divider(indent: 16, endIndent: 16),
          GlassTile(
            icon: bt.isAdvertising.value ? Icons.visibility_rounded : Icons.visibility_off_outlined,
            iconColor: bt.isAdvertising.value ? AppColors.bronze400 : AppColors.silver200,
            title: 'Visibility',
            subtitle: visibility,
          ),
          const Divider(indent: 16, endIndent: 16),
          const GlassTile(
            icon: Icons.info_outline_rounded,
            title: 'Permissions',
            subtitle:
                'Uses "Nearby devices" (Android 12+) or Location (Android 11 and older, '
                'required by Android for Bluetooth scanning). Location is never read.',
          ),
        ],
      );
    });
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
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Display name', style: theme.textTheme.titleLarge),
        const SizedBox(height: 14),
        GlassPanel(
          radius: 16,
          shadow: false,
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 2),
          child: TextField(
            controller: _text,
            autofocus: true,
            maxLength: AppConstants.maxDisplayNameLength,
            textCapitalization: TextCapitalization.words,
            style: theme.textTheme.bodyLarge,
            onSubmitted: (_) => _submit(),
          ),
        ),
        AnimatedSize(
          duration: Motion.medium,
          curve: Motion.ease,
          child: _error == null
              ? const SizedBox(width: double.infinity)
              : ShakeOnce(
                  key: ValueKey(_error),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4),
                    child: Text(
                      _error!,
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.clay),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: GhostButton(
                label: 'Cancel',
                dense: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ChromeButton(
                label: 'Save',
                dense: true,
                glint: false,
                onPressed: _saving ? null : _submit,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
