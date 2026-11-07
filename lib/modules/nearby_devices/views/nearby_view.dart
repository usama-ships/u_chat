import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_motion.dart';
import '../../../app/widgets/buttons.dart';
import '../../../app/widgets/glass.dart';
import '../../../app/widgets/motion.dart';
import '../../../app/widgets/radar.dart';
import '../../../app/widgets/responsive.dart';
import '../../../app/widgets/silver_backdrop.dart';
import '../../../app/widgets/status_view.dart';
import '../../../core/bluetooth/models/ble_availability.dart';
import '../controllers/nearby_controller.dart';
import '../widgets/device_tile.dart';

class NearbyView extends GetView<NearbyController> {
  const NearbyView({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: GlassBar.text(
        'Nearby',
        bottom: Obx(() => AnimatedOpacity(
              duration: Motion.medium,
              opacity: controller.bluetooth.isScanning.value ? 1 : 0,
              child: const LinearProgressIndicator(
                minHeight: 2,
                color: AppColors.bronze400,
                backgroundColor: Colors.transparent,
              ),
            )),
      ),
      body: Obx(() {
        final Widget content = switch (controller.availability) {
          BleAvailability.unknown => const Center(
              key: ValueKey('unknown'),
              child: BusySpinner(size: 26),
            ),
          BleAvailability.unsupported => const StatusView(
              key: ValueKey('unsupported'),
              icon: Icons.bluetooth_disabled_rounded,
              title: 'Bluetooth Low Energy not supported',
              body: 'This phone has no Bluetooth Low Energy, which U Chat needs.',
            ),
          BleAvailability.poweredOff => const StatusView(
              key: ValueKey('off'),
              icon: Icons.bluetooth_disabled_rounded,
              title: 'Bluetooth is off',
              body: 'Turn on Bluetooth from the quick settings panel. '
                  'Scanning starts automatically.',
            ),
          BleAvailability.unauthorized => StatusView(
              key: const ValueKey('unauthorized'),
              icon: Icons.lock_outline_rounded,
              title: 'Permission needed',
              body: 'U Chat needs the "Nearby devices" permission to find and talk to '
                  'phones around you. It never uses your location.',
              action: Obx(() => ChromeButton(
                    label: controller.bluetooth.permissionDenied.value
                        ? 'Open app settings'
                        : 'Allow',
                    onPressed: controller.grantPermission,
                  )),
            ),
          BleAvailability.ready => const _ReadyBody(key: ValueKey('ready')),
        };
        return AnimatedSwitcher(duration: Motion.medium, child: content);
      }),
    );
  }
}

class _ReadyBody extends GetView<NearbyController> {
  const _ReadyBody({super.key});

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Wide screens and landscape: radar beside the list.
        final sideBySide = constraints.maxWidth >= 720;
        if (sideBySide) {
          return Padding(
            padding: EdgeInsets.only(top: inset.top),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: _RadarHeader(
                        // Leaves room for the caption under the radar.
                        size: math.min(
                          constraints.maxWidth * 0.32,
                          constraints.maxHeight - inset.top - inset.bottom - 76,
                        ),
                      ),
                    ),
                  ),
                ),
                const Expanded(flex: 3, child: _DeviceArea(topPadding: 16)),
              ],
            ),
          );
        }
        final height = constraints.maxHeight - inset.top;
        return Obx(() {
          final hasDevices = controller.devices.isNotEmpty;
          final fraction = hasDevices ? 0.30 : 0.40;
          return Padding(
            padding: EdgeInsets.only(top: inset.top),
            child: Column(
              children: [
                const SizedBox(height: 18),
                _RadarHeader(size: math.min(height * fraction, constraints.maxWidth * 0.72)),
                const SizedBox(height: 6),
                const Expanded(child: _DeviceArea(topPadding: 10)),
              ],
            ),
          );
        });
      },
    );
  }
}

class _RadarHeader extends GetView<NearbyController> {
  const _RadarHeader({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bt = controller.bluetooth;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: Motion.slow,
          curve: Motion.ease,
          width: size,
          height: size,
          child: Obx(() => Radar(
                scanning: bt.isScanning.value,
                blips: [
                  for (final device in controller.devices)
                    RadarBlip(id: device.deviceIdPrefix, strength: radarStrength(device.rssi)),
                ],
              )),
        ),
        const SizedBox(height: 12),
        Obx(() {
          final count = controller.devices.length;
          final label = count > 0
              ? (count == 1 ? '1 person nearby' : '$count people nearby')
              : bt.isScanning.value
                  ? 'Scanning…'
                  : 'Scan stopped';
          return AnimatedSwitcher(
            duration: Motion.medium,
            transitionBuilder: fadeLiftTransition,
            child: Text(
              label,
              key: ValueKey(label),
              style: theme.textTheme.titleMedium?.copyWith(
                color: count > 0 ? AppColors.bronze300 : AppColors.silver200,
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _DeviceArea extends StatefulWidget {
  const _DeviceArea({required this.topPadding});

  final double topPadding;

  @override
  State<_DeviceArea> createState() => _DeviceAreaState();
}

class _DeviceAreaState extends State<_DeviceArea> {
  final controller = Get.find<NearbyController>();
  final _stagger = Stagger();

  @override
  Widget build(BuildContext context) {
    final bt = controller.bluetooth;
    return Column(
      children: [
        Obx(() {
          final String? notice = !bt.advertisingSupported.value
              ? "This phone can't advertise over Bluetooth. You can find others, "
                  "but they can't find you."
              : bt.advertisingError.value;
          return AnimatedSize(
            duration: Motion.medium,
            curve: Motion.ease,
            child: notice == null
                ? const SizedBox(width: double.infinity)
                : _Notice(text: notice),
          );
        }),
        Expanded(
          child: Obx(() {
            final devices = controller.devices;
            final scanError = bt.scanError.value;
            final Widget content;
            if (devices.isEmpty) {
              if (scanError != null) {
                content = _Hint(
                  key: const ValueKey('error'),
                  title: 'Scan failed',
                  body: scanError,
                  action: ChromeButton(label: 'Try again', onPressed: controller.rescan),
                );
              } else if (bt.isScanning.value) {
                content = const _Hint(
                  key: ValueKey('scanning'),
                  title: 'Looking for nearby U Chat users',
                  body: 'Make sure U Chat is open on the other phone, with Bluetooth on. '
                      'On Android 11 or older, Location must also be switched on.',
                );
              } else {
                content = _Hint(
                  key: const ValueKey('stopped'),
                  title: 'No devices found',
                  body: 'Scanning stopped to save battery.',
                  action: ChromeButton(label: 'Scan again', onPressed: controller.rescan),
                );
              }
            } else {
              content = _DeviceList(
                key: const ValueKey('list'),
                stagger: _stagger,
                topPadding: widget.topPadding,
              );
            }
            return AnimatedSwitcher(duration: Motion.medium, child: content);
          }),
        ),
      ],
    );
  }
}

class _DeviceList extends GetView<NearbyController> {
  const _DeviceList({super.key, required this.stagger, required this.topPadding});

  final Stagger stagger;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context);
    final gutter = math.min(Responsive.gutter(context), 24.0);
    final bt = controller.bluetooth;
    final devices = controller.devices;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Responsive.maxContentWidth),
        child: ListView.builder(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: EdgeInsets.fromLTRB(gutter, topPadding, gutter, inset.bottom + 16),
          itemCount: devices.length + 1,
          itemBuilder: (_, index) {
            if (index == devices.length) {
              return Obx(() => AnimatedSwitcher(
                    duration: Motion.medium,
                    transitionBuilder: popTransition,
                    child: bt.isScanning.value
                        ? const SizedBox(height: 24)
                        : Padding(
                            padding: const EdgeInsets.all(8),
                            child: Center(
                              child: GhostButton(
                                label: 'Scan again',
                                icon: Icons.refresh_rounded,
                                dense: true,
                                onPressed: controller.rescan,
                              ),
                            ),
                          ),
                  ));
            }
            final device = devices[index];
            return Padding(
              key: ValueKey(device.deviceIdPrefix),
              padding: const EdgeInsets.only(bottom: 10),
              child: Entrance(
                delay: stagger.delayFor(index),
                child: Obx(() => DeviceTile(
                      device: device,
                      isKnown: controller.isKnown(device),
                      linkState: controller.linkStateOf(device),
                      onAction: () => controller.connectAndOpenChat(device),
                    )),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({super.key, required this.title, required this.body, this.action});

  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 12, 32, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Entrance(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.silver300),
                ),
                if (action != null) ...[const SizedBox(height: 18), action!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: GlassPanel(
        radius: 16,
        shadow: false,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.visibility_off_outlined, size: 18, color: AppColors.silver300),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
          ],
        ),
      ),
    );
  }
}
