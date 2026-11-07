import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import 'motion.dart';
import 'pressable.dart';
import 'responsive.dart';

/// A frosted panel with a lit edge.
///
/// Leave [blur] off for panels that sit straight on the backdrop: blurring a
/// smooth gradient changes nothing visually but costs a lot on the GPU. Turn
/// it on only where content scrolls behind the glass.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.radius = 20,
    this.blur = false,
    this.fill,
    this.rim,
    this.shadow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool blur;
  final Gradient? fill;
  final Gradient? rim;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    Widget content = CustomPaint(
      foregroundPainter: RimPainter(radius: radius, gradient: rim ?? AppColors.glassRim),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          gradient: fill ?? AppColors.glassFill,
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
    if (blur) {
      content = ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: content,
        ),
      );
    }
    if (!shadow) return content;
    return CustomPaint(painter: _OuterShadowPainter(radius: radius), child: content);
  }
}

/// Soft shadow drawn only outside the panel. A normal box shadow also paints
/// underneath, and would show through the translucent glass as a dark band.
class _OuterShadowPainter extends CustomPainter {
  const _OuterShadowPainter({required this.radius});

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final panel = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    canvas.save();
    canvas.clipPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect((Offset.zero & size).inflate(48))
        ..addRRect(panel),
    );
    canvas.drawRRect(
      panel.shift(const Offset(0, 8)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.32)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 11),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OuterShadowPainter oldDelegate) => oldDelegate.radius != radius;
}

/// Draws the 1px lit edge of a glass surface.
class RimPainter extends CustomPainter {
  const RimPainter({required this.radius, required this.gradient});

  final double radius;
  final Gradient gradient;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = gradient.createShader(rect),
    );
  }

  @override
  bool shouldRepaint(RimPainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.gradient != gradient;
}

/// Frosted top bar. Content scrolls underneath it.
class GlassBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.height = 64,
    this.showBack = true,
    this.bottom,
  });

  /// Convenience for a plain text title.
  factory GlassBar.text(String text, {Key? key, List<Widget> actions = const [], Widget? bottom}) =>
      GlassBar(key: key, title: _BarTitle(text), actions: actions, bottom: bottom);

  final Widget title;
  final List<Widget> actions;
  final double height;
  final bool showBack;

  /// Thin widget along the lower edge, such as a progress line.
  final Widget? bottom;

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final canPop = showBack && (ModalRoute.of(context)?.canPop ?? false);
    final gutter = Responsive.gutter(context);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.graphite800.withValues(alpha: 0.86),
                AppColors.graphite800.withValues(alpha: 0.58),
              ],
            ),
            border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.09))),
          ),
          child: SafeArea(
            bottom: false,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                SizedBox(
                  height: height,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: canPop ? gutter - 6 : gutter),
                    child: Row(
                      children: [
                        if (canPop) ...[
                          GlassIconButton(
                            icon: Icons.arrow_back_rounded,
                            tooltip: 'Back',
                            onPressed: () => Navigator.of(context).maybePop(),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(child: title),
                        ...actions,
                      ],
                    ),
                  ),
                ),
                ?bottom,
              ],
            ),
          ),
        ),
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

/// Round glass icon button with a 44px touch target.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 44,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: onPressed,
        pressedScale: 0.9,
        semanticLabel: tooltip,
        child: SizedBox(
          width: size,
          height: size,
          child: GlassPanel(
            radius: size / 2,
            shadow: false,
            child: Center(child: Icon(icon, size: 20, color: AppColors.silver200)),
          ),
        ),
      ),
    );
  }
}

/// A titled group of rows on one glass card.
class GlassSection extends StatelessWidget {
  const GlassSection({super.key, this.title, required this.children});

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
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
            child: Text(
              title!.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.silver400,
                letterSpacing: 1.4,
              ),
            ),
          ),
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const Divider(indent: 16, endIndent: 16),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Small metal chip that holds a row's icon.
class IconChip extends StatelessWidget {
  const IconChip({super.key, required this.icon, this.color = AppColors.silver200});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        color: Colors.white.withValues(alpha: 0.07),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: AnimatedSwitcher(
        duration: Motion.medium,
        transitionBuilder: popTransition,
        child: Icon(icon, key: ValueKey(icon), size: 19, color: color),
      ),
    );
  }
}

/// One row in a [GlassSection].
class GlassTile extends StatelessWidget {
  const GlassTile({
    super.key,
    required this.title,
    this.icon,
    this.iconColor = AppColors.silver200,
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            IconChip(icon: icon!, color: iconColor),
            const SizedBox(width: 13),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: titleColor,
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
    return Pressable(onTap: onTap, pressedScale: 0.985, child: row);
  }
}

/// [GlassTile] with a switch; the whole row toggles it.
class GlassSwitchTile extends StatelessWidget {
  const GlassSwitchTile({
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
      child: GlassTile(
        title: title,
        icon: icon,
        iconColor: value ? AppColors.bronze400 : AppColors.silver200,
        subtitle: subtitle,
        onTap: () => onChanged(!value),
        trailing: Switch(value: value, onChanged: onChanged),
      ),
    );
  }
}

/// Small rounded label, such as the presence pill or the day separator.
class GlassPill extends StatelessWidget {
  const GlassPill({super.key, required this.child, this.blur = false, this.padding});

  final Widget child;
  final bool blur;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: 100,
      blur: blur,
      shadow: false,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: child,
    );
  }
}
