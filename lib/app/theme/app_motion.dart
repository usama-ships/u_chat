import 'package:flutter/widgets.dart';

/// Shared timing, so the whole app moves with one rhythm.
abstract final class Motion {
  static const fast = Duration(milliseconds: 160);
  static const medium = Duration(milliseconds: 280);
  static const slow = Duration(milliseconds: 460);
  static const page = Duration(milliseconds: 380);

  /// Default for anything entering or changing.
  static const Curve ease = Cubic(0.2, 0, 0, 1);

  /// A small overshoot, for things that should feel like they landed.
  static const Curve pop = Curves.easeOutBack;

  /// True when the user turned animations off in Android's accessibility
  /// settings. Looping and entrance animations must stop in that case.
  static bool isReduced(BuildContext context) => MediaQuery.disableAnimationsOf(context);
}
