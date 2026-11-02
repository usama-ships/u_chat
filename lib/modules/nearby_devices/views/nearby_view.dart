import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/bluetooth/models/ble_availability.dart';
import '../controllers/nearby_controller.dart';
import '../widgets/device_tile.dart';

class NearbyView extends GetView<NearbyController> {
  const NearbyView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby devices'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Obx(() => controller.bluetooth.isScanning.value
              ? const LinearProgressIndicator(minHeight: 3)
              : const SizedBox(height: 3)),
        ),
      ),
      body: Obx(() => switch (controller.availability) {
            BleAvailability.unknown => const Center(child: CircularProgressIndicator()),
            BleAvailability.unsupported => const _StatusMessage(
                icon: Icons.bluetooth_disabled,
                title: 'Bluetooth Low Energy not supported',
                body: 'This phone has no Bluetooth Low Energy, which U Chat needs.',
              ),
            BleAvailability.poweredOff => const _StatusMessage(
                icon: Icons.bluetooth_disabled,
                title: 'Bluetooth is off',
                body: 'Turn on Bluetooth from the quick settings panel. '
                    'Scanning starts automatically.',
              ),
            BleAvailability.unauthorized => _StatusMessage(
                icon: Icons.lock_outline,
                title: 'Permission needed',
                body: 'U Chat needs the "Nearby devices" permission to find and talk to '
                    'phones around you. It never uses your location.',
                action: Obx(() => FilledButton(
                      onPressed: controller.grantPermission,
                      child: Text(controller.bluetooth.permissionDenied.value
                          ? 'Open app settings'
                          : 'Allow'),
                    )),
              ),
            BleAvailability.ready => const _ReadyBody(),
          }),
    );
  }
}

class _ReadyBody extends GetView<NearbyController> {
  const _ReadyBody();

  @override
  Widget build(BuildContext context) {
    final bt = controller.bluetooth;
    return Column(
      children: [
        Obx(() {
          if (!bt.advertisingSupported.value) {
            return const _Banner(
              icon: Icons.visibility_off_outlined,
              text: "This phone can't advertise over Bluetooth. You can find others, "
                  "but they can't find you.",
            );
          }
          final error = bt.advertisingError.value;
          if (error != null) return _Banner(icon: Icons.error_outline, text: error);
          return const SizedBox.shrink();
        }),
        Expanded(
          child: Obx(() {
            final devices = controller.devices;
            final scanError = bt.scanError.value;
            if (devices.isEmpty) {
              if (scanError != null) {
                return _StatusMessage(
                  icon: Icons.error_outline,
                  title: 'Scan failed',
                  body: scanError,
                  action: FilledButton(onPressed: controller.rescan, child: const Text('Try again')),
                );
              }
              return bt.isScanning.value
                  ? const _StatusMessage(
                      icon: Icons.bluetooth_searching,
                      title: 'Looking for nearby U Chat users…',
                      body: 'Make sure U Chat is open on the other phone, with Bluetooth on. '
                          'On Android 11 or older, Location must also be switched on.',
                    )
                  : _StatusMessage(
                      icon: Icons.bluetooth,
                      title: 'No devices found',
                      body: 'Scanning stopped to save battery.',
                      action: FilledButton(onPressed: controller.rescan, child: const Text('Scan again')),
                    );
            }
            return ListView.separated(
              itemCount: devices.length + 1,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
              itemBuilder: (_, index) {
                if (index == devices.length) {
                  return Obx(() => bt.isScanning.value
                      ? const SizedBox(height: 24)
                      : Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: OutlinedButton.icon(
                              onPressed: controller.rescan,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Scan again'),
                            ),
                          ),
                        ));
                }
                final device = devices[index];
                return Obx(() => DeviceTile(
                      device: device,
                      isKnown: controller.isKnown(device),
                      linkState: controller.linkStateOf(device),
                      onAction: () => controller.connectAndOpenChat(device),
                    ));
              },
            );
          }),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: scheme.onSecondaryContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text, style: TextStyle(color: scheme.onSecondaryContainer, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.icon, required this.title, required this.body, this.action});

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}
