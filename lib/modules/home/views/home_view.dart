import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_motion.dart';
import '../../../app/widgets/buttons.dart';
import '../../../app/widgets/glass.dart';
import '../../../app/widgets/motion.dart';
import '../../../app/widgets/overlays.dart';
import '../../../app/widgets/radar.dart';
import '../../../app/widgets/responsive.dart';
import '../../../app/widgets/silver_backdrop.dart';
import '../../../app/widgets/status_view.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/conversation_with_peer.dart';
import '../controllers/home_controller.dart';
import '../widgets/conversation_tile.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: GlassBar(
        height: 76,
        showBack: false,
        title: const _Header(),
        actions: [
          GlassIconButton(
            icon: Icons.tune_rounded,
            tooltip: 'Settings',
            onPressed: controller.openSettings,
          ),
        ],
      ),
      floatingActionButton: Obx(() {
        final show = !controller.isLoading.value && controller.conversations.isNotEmpty;
        return AnimatedScale(
          scale: show ? 1 : 0,
          duration: Motion.slow,
          curve: show ? Motion.pop : Curves.easeIn,
          child: ChromeButton(
            label: 'Nearby',
            icon: Icons.radar_rounded,
            onPressed: show ? controller.openNearby : null,
          ),
        );
      }),
      body: Obx(() {
        final Widget content;
        final error = controller.errorMessage.value;
        if (controller.isLoading.value) {
          content = const Center(key: ValueKey('loading'), child: BusySpinner(size: 26));
        } else if (error != null) {
          content = StatusView(
            key: const ValueKey('error'),
            icon: Icons.error_outline_rounded,
            title: error,
          );
        } else if (controller.conversations.isEmpty) {
          content = StatusView(
            key: const ValueKey('empty'),
            icon: Icons.forum_outlined,
            illustration: const ExcludeSemantics(
              child: SizedBox(width: 190, child: Radar(scanning: true)),
            ),
            title: 'No conversations yet',
            body: 'Find people around you. No internet, no accounts, nothing leaves your phone.',
            action: ChromeButton(
              label: 'Find people nearby',
              icon: Icons.radar_rounded,
              onPressed: controller.openNearby,
            ),
          );
        } else {
          content = const _ConversationList(key: ValueKey('list'));
        }
        return AnimatedSwitcher(duration: Motion.medium, child: content);
      }),
    );
  }
}

class _Header extends GetView<HomeController> {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShimmerText(AppConstants.appName, style: theme.textTheme.headlineSmall),
        Obx(() {
          final active = controller.isPresent;
          return Row(
            children: [
              Transform.translate(
                offset: const Offset(-5, 0),
                child: PulseDot(active: active, size: 7),
              ),
              Flexible(
                child: Transform.translate(
                  offset: const Offset(-5, 0),
                  child: AnimatedSwitcher(
                    duration: Motion.medium,
                    layoutBuilder: startAlignedLayout,
                    transitionBuilder: fadeLiftTransition,
                    child: Text(
                      controller.presenceLabel,
                      key: ValueKey(controller.presenceLabel),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: active ? AppColors.bronze300 : AppColors.silver400,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }
}

class _ConversationList extends StatefulWidget {
  const _ConversationList({super.key});

  @override
  State<_ConversationList> createState() => _ConversationListState();
}

class _ConversationListState extends State<_ConversationList> {
  final _stagger = Stagger();

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeController>();
    final inset = MediaQuery.paddingOf(context);
    final gutter = Responsive.gutter(context);
    return Obx(() {
      final items = controller.conversations;
      return ListView.builder(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        // The bottom space keeps the last row clear of the Nearby button.
        padding: EdgeInsets.fromLTRB(gutter, inset.top + 14, gutter, inset.bottom + 96),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return Padding(
            key: ValueKey(item.conversation.id),
            padding: const EdgeInsets.only(bottom: 10),
            child: Entrance(
              delay: _stagger.delayFor(index),
              child: Obx(
                () => ConversationTile(
                  item: item,
                  isConnected: controller.isConnected(item.peer.id),
                  onTap: () => controller.openConversation(item),
                  onLongPress: () => _confirmDelete(context, item),
                ),
              ),
            ),
          );
        },
      );
    });
  }
}

Future<void> _confirmDelete(BuildContext context, ConversationWithPeer item) async {
  final controller = Get.find<HomeController>();
  final confirmed = await showGlassConfirm(
    context,
    title: 'Delete conversation?',
    message:
        'All messages with ${item.peer.displayName} will be removed from this phone. '
        'This cannot be undone.',
    confirmLabel: 'Delete',
    destructive: true,
  );
  if (confirmed) await controller.deleteConversation(item);
}
