import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import 'motion.dart';
import 'pressable.dart';
import 'responsive.dart';

/// A frosted glass card: translucent white with a soft lavender edge. It
/// doesn't blur what's behind it, because the sheets it sits on are smooth and
/// still, so it stays cheap to draw in long lists.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.radius = 18,
    this.color,
    this.borderColor = AppColors.glassBorder,
    this.shadow = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// A solid colour instead of glass, for things that must stay readable over
  /// other content, such as dialogs.
  final Color? color;
  final Color borderColor;

  /// For things that float above content, such as dialogs and banners.
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        gradient: color == null ? AppColors.glassFill : null,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
        boxShadow: shadow ? AppColors.glassShadow : null,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// The bar on the purple header: white title and icons, no fill of its own.
class TopBar extends StatelessWidget implements PreferredSizeWidget {
  const TopBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.height = 60,
    this.showBack = true,
    this.centerTitle = false,
    this.bottom,
  });

  /// Convenience for a plain text title.
  factory TopBar.text(String text, {Key? key, List<Widget> actions = const [], Widget? bottom}) =>
      TopBar(key: key, title: _BarTitle(text), actions: actions, bottom: bottom);

  final Widget title;
  final List<Widget> actions;
  final double height;
  final bool showBack;

  /// Centres [title] between the back button and the actions, as in chats.
  final bool centerTitle;

  /// Thin widget along the lower edge, such as a progress line.
  final Widget? bottom;

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final canPop = showBack && (ModalRoute.of(context)?.canPop ?? false);
    final gutter = Responsive.gutter(context);
    final back = canPop
        ? RoundIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
          )
        : null;
    final Widget row;
    if (centerTitle) {
      // Equal space on both sides keeps the title truly centred.
      final side = 48.0 * (actions.isEmpty ? 1 : actions.length);
      row = Row(
        children: [
          SizedBox(
            width: side,
            child: Align(alignment: Alignment.centerLeft, child: back),
          ),
          Expanded(child: Center(child: title)),
          SizedBox(
            width: side,
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
          ),
        ],
      );
    } else {
      row = Row(
        children: [
          if (back != null) ...[back, const SizedBox(width: 6)],
          Expanded(child: title),
          ...actions,
        ],
      );
    }
    return OnHeader(
      child: SafeArea(
        bottom: false,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            SizedBox(
              height: height,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: canPop ? gutter - 8 : gutter),
                child: row,
              ),
            ),
            ?bottom,
          ],
        ),
      ),
    );
  }
}

/// Makes text and icons inside it white, for content on the purple header.
class OnHeader extends StatelessWidget {
  const OnHeader({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.apply(
          bodyColor: AppColors.onHeader,
          displayColor: AppColors.onHeader,
        ),
        iconTheme: const IconThemeData(color: AppColors.onHeader),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: AppColors.onHeader),
        child: child,
      ),
    );
  }
}

class _BarTitle extends StatelessWidget {
  const _BarTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleLarge,
    );
  }
}

/// Icon button with a 44px touch target and a soft round highlight on press.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 44,
    this.filled = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;

  /// Gives the button a frosted background.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    // White on the header, ink on the sheets.
    final ink = IconTheme.of(context).color ?? AppColors.text;
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: onPressed,
        pressedScale: 0.9,
        semanticLabel: tooltip,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? ink.withValues(alpha: 0.14) : Colors.transparent,
            border: filled ? Border.all(color: ink.withValues(alpha: 0.2)) : null,
          ),
          child: Icon(icon, size: 22, color: ink),
        ),
      ),
    );
  }
}

/// A titled group of rows on one card.
class Section extends StatelessWidget {
  const Section({super.key, this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              title!,
              style: theme.textTheme.labelLarge?.copyWith(color: AppColors.textMuted),
            ),
          ),
        Panel(
          radius: 22,
          shadow: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const Divider(indent: 62),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Tinted rounded square that holds a row's icon.
class IconChip extends StatelessWidget {
  const IconChip({super.key, required this.icon, this.color = AppColors.accentLight});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Motion.medium,
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: color.withValues(alpha: 0.14),
      ),
      child: AnimatedSwitcher(
        duration: Motion.medium,
        transitionBuilder: popTransition,
        child: Icon(icon, key: ValueKey(icon), size: 19, color: color),
      ),
    );
  }
}

/// One row in a [Section].
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.icon,
    this.iconColor = AppColors.accentLight,
    this.titleColor,
    this.subtitle,
    this.subtitleWidget,
    this.trailing,
    this.onTap,
  });

  final String title;
  final IconData? icon;
  final Color iconColor;
  final Color? titleColor;
  final String? subtitle;
  final Widget? subtitleWidget;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          if (icon != null) ...[IconChip(icon: icon!, color: iconColor), const SizedBox(width: 14)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: titleColor ?? AppColors.text,
                    height: 1.25,
                  ),
                ),
                if (subtitleWidget != null) ...[
                  const SizedBox(height: 3),
                  subtitleWidget!,
                ] else if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  AnimatedSwitcher(
                    duration: Motion.medium,
                    layoutBuilder: startAlignedLayout,
                    transitionBuilder: fadeLiftTransition,
                    child: Text(
                      subtitle!,
                      key: ValueKey(subtitle),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );
    if (onTap == null) return row;
    return TapHighlight(onTap: onTap!, child: row);
  }
}

/// [ListRow] with a switch; the whole row toggles it.
class SwitchRow extends StatelessWidget {
  const SwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.icon,
    this.subtitle,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData? icon;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: ListRow(
        title: title,
        icon: icon,
        iconColor: value ? AppColors.accentLight : AppColors.textMuted,
        subtitle: subtitle,
        onTap: () => onChanged(!value),
        trailing: Switch(value: value, onChanged: onChanged),
      ),
    );
  }
}

/// Small rounded label, such as the day separator in a chat.
class Pill extends StatelessWidget {
  const Pill({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Panel(
      radius: 100,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: child,
    );
  }
}

/// Lights up while pressed, the way list rows do in native apps.
class TapHighlight extends StatefulWidget {
  const TapHighlight({super.key, required this.onTap, required this.child, this.onLongPress});

  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget child;

  @override
  State<TapHighlight> createState() => _TapHighlightState();
}

class _TapHighlightState extends State<TapHighlight> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      pressedScale: 1,
      onHighlight: (down) => setState(() => _down = down),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _down ? AppColors.surfaceHigh : Colors.transparent,
        child: widget.child,
      ),
    );
  }
}
