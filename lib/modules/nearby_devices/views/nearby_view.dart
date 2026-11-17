import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_motion.dart';
import '../../../app/widgets/app_scaffold.dart';
import '../../../app/widgets/buttons.dart';
import '../../../app/widgets/motion.dart';
import '../../../app/widgets/peer_avatar.dart';
import '../../../app/widgets/radar.dart';
import '../../../app/widgets/responsive.dart';
import '../../../app/widgets/status_view.dart';
import '../../../app/widgets/surfaces.dart';
import '../../../core/bluetooth/models/ble_availability.dart';
import '../controllers/nearby_controller.dart';
import '../widgets/device_tile.dart';

class NearbyView extends GetView<NearbyController> {
  const NearbyView({super.key});

  @override
  Widget build(BuildContext context) {
    final bt = controller.bluetooth;
    return AppScaffold(
      appBar: TopBar.text(
        'Nearby',
        actions: [
          Obx(() {
            final show = bt.availability.value == BleAvailability.ready && !bt.isScanning.value;
            return AnimatedScale(
              duration: Motion.medium,
              curve: Motion.pop,
              scale: show ? 1 : 0,
              child: RoundIconButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Scan again',
                onPressed: show ? controller.rescan : null,
              ),
            );
          }),
        ],
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
            body: 'This phone has no Bluetooth Low Energy, which Blue Chat needs.',
          ),
          BleAvailability.poweredOff => const StatusView(
            key: ValueKey('off'),
            icon: Icons.bluetooth_disabled_rounded,
            title: 'Bluetooth is off',
            body:
                'Turn on Bluetooth from the quick settings panel. '
                'Scanning starts automatically.',
          ),
          BleAvailability.unauthorized => StatusView(
            key: const ValueKey('unauthorized'),
            icon: Icons.lock_outline_rounded,
            title: 'Permission needed',
            body:
                'Blue Chat needs the "Nearby devices" permission to find and talk to '
                'phones around you. It never uses your location.',
            action: Obx(
              () => PrimaryButton(
                label: bt.permissionDenied.value ? 'Open app settings' : 'Allow',
                onPressed: controller.grantPermission,
              ),
            ),
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
        if (constraints.maxWidth >= 720) {
          return Padding(
            padding: EdgeInsets.only(top: inset.top),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: _RadarHeader(
                        // Leaves room for the status bar under the radar.
                        size: math.min(
                          constraints.maxWidth * 0.30,
                          constraints.maxHeight - inset.top - inset.bottom - 110,
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
          final fraction = controller.devices.isNotEmpty ? 0.28 : 0.36;
          return Padding(
            padding: EdgeInsets.only(top: inset.top),
            child: Column(
              children: [
                const SizedBox(height: 22),
                _RadarHeader(size: math.min(height * fraction, constraints.maxWidth * 0.68)),
                const SizedBox(height: 4),
                const Expanded(child: _DeviceArea(topPadding: 12)),
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
    final bt = controller.bluetooth;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: Motion.slow,
          curve: Motion.ease,
          width: math.max(size, 120),
          height: math.max(size, 120),
          child: Obx(
            () => Radar(
              scanning: bt.isScanning.value,
              blips: [
                for (final device in controller.devices)
                  RadarBlip(
                    id: device.deviceIdPrefix,
                    strength: radarStrength(device.rssi),
                    label: device.displayName.isEmpty
                        ? '?'
                        : device.displayName.characters.first.toUpperCase(),
                    colors: PeerAvatar.colorsFor(device.deviceIdPrefix),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const _StatusBar(),
      ],
    );
  }
}

/// What the scan is doing, and whether other phones can see this one.
class _StatusBar extends GetView<NearbyController> {
  const _StatusBar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bt = controller.bluetooth;
    return Obx(() {
      final count = controller.devices.length;
      final scanning = bt.isScanning.value;
      final label = count > 0
          ? (count == 1 ? '1 person found' : '$count people found')
          : scanning
          ? 'Searching…'
          : 'Search paused';
      final visible = bt.isAdvertising.value;
      return Panel(
        radius: 100,
        padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PulseDot(active: scanning, color: AppColors.accentLight, size: 7),
            AnimatedSwitcher(
              duration: Motion.medium,
              transitionBuilder: fadeLiftTransition,
              child: Text(
                label,
                key: ValueKey(label),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: count > 0 ? AppColors.text : AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Tooltip(
              message: visible
                  ? 'Other Blue Chat users nearby can find you'
                  : 'Other phones cannot find you right now',
              child: AnimatedContainer(
                duration: Motion.medium,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                  color: (visible ? AppColors.success : AppColors.textFaint).withValues(
                    alpha: 0.16,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      visible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                      size: 14,
                      color: visible ? AppColors.success : AppColors.textMuted,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      visible ? 'Visible' : 'Hidden',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: visible ? AppColors.success : AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
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
            child: notice == null ? const SizedBox(width: double.infinity) : _Notice(text: notice),
          );
        }),
        Expanded(
          child: Obx(() {
            final devices = controller.devices;
            final scanError = bt.scanError.value;
            final Widget content;
            if (devices.isEmpty) {
              if (scanError != null) {
                content = _Tips(
                  key: const ValueKey('error'),
                  title: 'Search failed',
                  subtitle: scanError,
                  action: PrimaryButton(label: 'Try again', onPressed: controller.rescan),
                );
              } else if (bt.isScanning.value) {
                content = const _Tips(
                  key: ValueKey('scanning'),
                  title: 'Looking for people nearby',
                  subtitle: 'This usually takes a few seconds. For them to show up:',
                );
              } else {
                content = _Tips(
                  key: const ValueKey('stopped'),
                  title: 'Nobody found yet',
                  subtitle: 'The search pauses after two minutes to save battery.',
                  action: PrimaryButton(
                    label: 'Search again',
                    icon: Icons.refresh_rounded,
                    onPressed: controller.rescan,
                  ),
                );
              }
            } else {
              content = _DeviceList(
                key: const ValueKey('list'),
                stagger: _stagger,
                topPadding: widget.topPadding,
              );
            }
            // Top-aligned, so tips sit right under the radar instead of floating.
            return AnimatedSwitcher(
              duration: Motion.medium,
              layoutBuilder: (current, previous) =>
                  Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
              child: content,
            );
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
    final theme = Theme.of(context);
    final inset = MediaQuery.paddingOf(context);
    final gutter = math.min(Responsive.gutter(context), 24.0);
    final bt = controller.bluetooth;
    final devices = controller.devices;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Responsive.maxContentWidth),
        child: ListView.builder(
          padding: EdgeInsets.fromLTRB(gutter, topPadding, gutter, inset.bottom + 16),
          itemCount: devices.length + 2,
          itemBuilder: (_, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                child: Text(
                  'People nearby',
                  style: theme.textTheme.labelLarge?.copyWith(color: AppColors.textMuted),
                ),
              );
            }
            if (index == devices.length + 1) {
              return Obx(
                () => AnimatedSwitcher(
                  duration: Motion.medium,
                  transitionBuilder: popTransition,
                  child: bt.isScanning.value
                      ? const SizedBox(height: 24)
                      : Padding(
                          padding: const EdgeInsets.all(8),
                          child: Center(
                            child: SecondaryButton(
                              label: 'Scan again',
                              icon: Icons.refresh_rounded,
                              dense: true,
                              onPressed: controller.rescan,
                            ),
                          ),
                        ),
                ),
              );
            }
            final device = devices[index - 1];
            return Padding(
              key: ValueKey(device.deviceIdPrefix),
              padding: const EdgeInsets.only(bottom: 10),
              child: Entrance(
                delay: stagger.delayFor(index - 1),
                offset: const Offset(0, 12),
                duration: Motion.medium,
                child: Obx(
                  () => DeviceTile(
                    device: device,
                    isKnown: controller.isKnown(device),
                    linkState: controller.linkStateOf(device),
                    onAction: () => controller.connectAndOpenChat(device),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A short card of what to check while nobody shows up.
class _Tips extends StatelessWidget {
  const _Tips({super.key, required this.title, required this.subtitle, this.action});

  final String title;
  final String subtitle;
  final Widget? action;

  static const _tips = [
    (Icons.phone_android_rounded, 'Blue Chat is open on their phone'),
    (Icons.bluetooth_rounded, 'Their Bluetooth is on'),
    (Icons.near_me_rounded, 'You are within about 10 metres'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inset = MediaQuery.paddingOf(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 12, 20, inset.bottom + 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Entrance(
            offset: const Offset(0, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Panel(
                  radius: 20,
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(subtitle, style: theme.textTheme.bodySmall),
                      const SizedBox(height: 10),
                      for (final (icon, text) in _tips)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              IconChip(icon: icon),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  text,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: AppColors.text,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
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
      child: Panel(
        radius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.visibility_off_outlined, size: 18, color: AppColors.warning),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
          ],
        ),
      ),
    );
  }
}
