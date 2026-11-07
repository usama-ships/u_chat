import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_motion.dart';
import '../../../app/widgets/buttons.dart';
import '../../../app/widgets/glass.dart';
import '../../../app/widgets/motion.dart';
import '../../../app/widgets/overlays.dart';
import '../../../app/widgets/peer_avatar.dart';
import '../../../app/widgets/responsive.dart';
import '../../../app/widgets/silver_backdrop.dart';
import '../../../app/widgets/status_view.dart';
import '../../../core/utils/time_format.dart';
import '../controllers/contact_controller.dart';

class ContactView extends GetView<ContactController> {
  const ContactView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gutter = Responsive.gutter(context);
    return GlassScaffold(
      appBar: GlassBar.text('Contact'),
      // Builder: the clearance for the glass bar only exists below the Scaffold.
      body: Builder(
        builder: (context) => Obx(() {
          final inset = MediaQuery.paddingOf(context);
          if (!controller.isLoaded.value) return const Center(child: BusySpinner(size: 26));
          final peer = controller.peer.value;
          if (peer == null) {
            return const StatusView(icon: Icons.person_off_outlined, title: 'Contact not found');
          }
          final safety = controller.safetyNumberText;
          final connected = controller.isConnected;
          final connecting = controller.isConnecting;
          final status = connected
              ? 'Connected'
              : connecting
              ? 'Connecting…'
              : 'Last seen ${formatConversationTime(peer.lastSeenAt)}';

          return ListView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            padding: EdgeInsets.fromLTRB(gutter, inset.top + 24, gutter, inset.bottom + 28),
            children: [
              Center(
                child: PeerAvatar(
                  seed: peer.id,
                  name: peer.displayName,
                  size: 96,
                  online: connected,
                  heroTag: 'avatar-${peer.id}',
                ),
              ),
              const SizedBox(height: 14),
              Entrance(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        peer.displayName,
                        style: theme.textTheme.headlineSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: Motion.medium,
                      transitionBuilder: popTransition,
                      child: peer.verified
                          ? const Padding(
                              key: ValueKey('verified'),
                              padding: EdgeInsets.only(left: 6),
                              child: Icon(
                                Icons.verified_rounded,
                                color: AppColors.bronze400,
                                semanticLabel: 'Verified',
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Entrance(
                delay: const Duration(milliseconds: 50),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: Motion.medium,
                    transitionBuilder: fadeLiftTransition,
                    child: Text(
                      status,
                      key: ValueKey(status),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: connected ? AppColors.bronze300 : AppColors.silver300,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Entrance(
                delay: const Duration(milliseconds: 100),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: Motion.medium,
                    transitionBuilder: popTransition,
                    child: peer.blocked
                        ? const SizedBox.shrink()
                        : connected
                        ? GhostButton(
                            key: const ValueKey('disconnect'),
                            label: 'Disconnect',
                            icon: Icons.bluetooth_disabled_rounded,
                            onPressed: controller.disconnect,
                          )
                        : ChromeButton(
                            key: const ValueKey('connect'),
                            label: 'Connect',
                            icon: Icons.bluetooth_rounded,
                            onPressed: connecting ? null : controller.connect,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Entrance(
                delay: const Duration(milliseconds: 160),
                child: GlassSection(
                  title: 'Safety number',
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: safety == null
                          ? Text(
                              'Available after the first secure connection with this contact.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.silver300,
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _SafetyGrid(number: safety),
                                const SizedBox(height: 14),
                                Text(
                                  'Compare this number with the one on ${peer.displayName}\'s phone, '
                                  'in person. If they match, your connection is not being '
                                  'intercepted and you can mark the contact as verified.',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                    ),
                    if (safety != null)
                      GlassSwitchTile(
                        icon: Icons.verified_outlined,
                        title: 'Verified',
                        subtitle: 'I compared the safety numbers and they match',
                        value: peer.verified,
                        onChanged: controller.setVerified,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Entrance(
                delay: const Duration(milliseconds: 220),
                child: GlassSection(
                  title: 'Device',
                  children: [
                    GlassTile(
                      icon: Icons.fingerprint_rounded,
                      title: 'Device ID',
                      subtitleWidget: SelectableText(
                        peer.id,
                        style: theme.textTheme.bodySmall?.copyWith(letterSpacing: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Entrance(
                delay: const Duration(milliseconds: 280),
                child: GlassSection(
                  title: 'Privacy',
                  children: [
                    GlassSwitchTile(
                      icon: Icons.block_rounded,
                      title: 'Block contact',
                      subtitle: 'Blocked contacts cannot connect or send you messages',
                      value: peer.blocked,
                      onChanged: controller.setBlocked,
                    ),
                    GlassTile(
                      icon: Icons.delete_outline_rounded,
                      iconColor: AppColors.clay,
                      title: 'Delete conversation',
                      titleColor: AppColors.clay,
                      subtitle: 'Removes all messages with this contact from this phone',
                      onTap: () => _confirmDelete(context, peer.displayName),
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String name) async {
    final confirmed = await showGlassConfirm(
      context,
      title: 'Delete conversation?',
      message: 'All messages with $name will be removed from this phone. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (confirmed) await controller.deleteConversation();
  }
}

/// The six groups of the safety number, laid out for reading aloud.
class _SafetyGrid extends StatelessWidget {
  const _SafetyGrid({required this.number});

  final String number;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = number.split(' ');
    return Semantics(
      label: 'Safety number $number',
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 8.0;
          final columns = constraints.maxWidth < 260 ? 2 : 3;
          final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (var i = 0; i < groups.length; i++)
                Entrance(
                  delay: Duration(milliseconds: 240 + 50 * i),
                  offset: const Offset(0, 10),
                  child: Container(
                    width: width,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        groups[i],
                        style: theme.textTheme.titleMedium?.copyWith(
                          letterSpacing: 1.6,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
