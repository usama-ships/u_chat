import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Layout rules shared by every screen.
abstract final class Responsive {
  /// Content never gets wider than this, so lines stay readable on tablets
  /// and in landscape. Lists keep scrolling edge to edge.
  static const maxContentWidth = 720.0;

  /// Horizontal padding that centres content in a [maxContentWidth] column.
  static double gutter(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final base = width < 350 ? 12.0 : 16.0;
    return math.max(base, (width - maxContentWidth) / 2);
  }

  /// Widest a message bubble may be on this screen.
  static double bubbleWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return math.min(width * 0.78, 520);
  }
}
