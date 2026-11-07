import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';

/// Fades, lifts and slightly grows its child into place when first shown.
class Entrance extends StatefulWidget {
  const Entrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = const Offset(0, 20),
    this.duration = Motion.slow,
  });

  final Widget child;
  final Duration delay;
  final Offset offset;
  final Duration duration;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _curve = CurvedAnimation(parent: _controller, curve: Motion.ease);
  Timer? _timer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Motion.isReduced(context)) {
      _controller.value = 1;
    } else if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _timer = Timer(widget.delay, _controller.forward);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) {
        final v = _curve.value;
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: widget.offset * (1 - v),
            child: Transform.scale(scale: 0.98 + 0.02 * v, child: child),
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Spreads the [Entrance] of list items over time when a list first appears.
/// Items that scroll in later come in with no delay.
class Stagger {
  Stagger({this.step = const Duration(milliseconds: 55), this.maxItems = 9});

  final Duration step;
  final int maxItems;
  final _start = DateTime.now();

  Duration delayFor(int index) {
    if (DateTime.now().difference(_start) > const Duration(milliseconds: 800)) {
      return Duration.zero;
    }
    return step * math.min(index, maxItems);
  }
}

/// Runs [builder] with a 0 to 1 value that repeats for as long as it's on
/// screen, or stays at [restingValue] if the user turned animations off.
class Looping extends StatefulWidget {
  const Looping({
    super.key,
    required this.period,
    required this.builder,
    this.child,
    this.restingValue = 0,
    this.reverse = false,
  });

  final Duration period;
  final double restingValue;
  final bool reverse;
  final Widget? child;
  final Widget Function(BuildContext context, double value, Widget? child) builder;

  @override
  State<Looping> createState() => _LoopingState();
}

class _LoopingState extends State<Looping> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.isReduced(context)) {
      _controller
        ..stop()
        ..value = widget.restingValue;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: widget.reverse);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The boundary keeps each frame's repaint to this small area.
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => widget.builder(context, _controller.value, child),
        child: widget.child,
      ),
    );
  }
}

/// A status dot with a ring radiating out of it.
class PulseDot extends StatelessWidget {
  const PulseDot({super.key, this.color = AppColors.bronze400, this.size = 8, this.active = true});

  final Color color;
  final double size;

  /// When false the dot sits still in a dimmed silver.
  final bool active;

  @override
  Widget build(BuildContext context) {
    final dot = AnimatedContainer(
      duration: Motion.medium,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? color : AppColors.silver500,
      ),
    );
    return SizedBox(
      width: size * 2.4,
      height: size * 2.4,
      child: Center(
        child: !active
            ? dot
            : Looping(
                period: const Duration(milliseconds: 2000),
                restingValue: 1,
                child: dot,
                builder: (context, t, child) {
                  final eased = Curves.easeOut.transform(t);
                  return Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: size * (1 + 1.4 * eased),
                        height: size * (1 + 1.4 * eased),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.withValues(alpha: 0.45 * (1 - eased)),
                        ),
                      ),
                      child!,
                    ],
                  );
                },
              ),
      ),
    );
  }
}

/// Text with a band of light passing across it, like a polished nameplate.
class ShimmerText extends StatelessWidget {
  const ShimmerText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Looping(
      period: const Duration(seconds: 6),
      restingValue: 0.8,
      child: Text(text, style: style?.copyWith(color: Colors.white), maxLines: 1),
      builder: (context, t, child) {
        // The light crosses during the first third, then the text rests.
        final x = -1.6 + 3.2 * (t * 3).clamp(0.0, 1.0);
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(x - 0.7, -0.3),
            end: Alignment(x + 0.7, 0.3),
            colors: const [AppColors.silver300, Colors.white, AppColors.silver300],
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}

/// Shakes its child sideways once when first shown, to flag a problem.
class ShakeOnce extends StatelessWidget {
  const ShakeOnce({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (Motion.isReduced(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      child: child,
      builder: (context, t, child) => Transform.translate(
        offset: Offset(math.sin(t * math.pi * 5) * 5 * (1 - t), 0),
        child: child,
      ),
    );
  }
}

/// Default swap for [AnimatedSwitcher]: a short fade and lift.
Widget fadeLiftTransition(Widget child, Animation<double> animation) {
  return FadeTransition(
    opacity: animation,
    child: SlideTransition(
      position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(animation),
      child: child,
    ),
  );
}

/// Swap for [AnimatedSwitcher] that pops the new child into place.
Widget popTransition(Widget child, Animation<double> animation) {
  return FadeTransition(
    opacity: animation,
    child: ScaleTransition(
      scale: CurvedAnimation(parent: animation, curve: Motion.pop),
      child: child,
    ),
  );
}

/// Keeps the old child's layout tight while [AnimatedSwitcher] cross-fades
/// left-aligned text.
Widget startAlignedLayout(Widget? current, List<Widget> previous) {
  return Stack(alignment: AlignmentDirectional.centerStart, children: [...previous, ?current]);
}
