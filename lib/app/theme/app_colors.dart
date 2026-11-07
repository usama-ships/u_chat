import 'package:flutter/material.dart';

/// The whole app is built from three tones:
///
/// * **Graphite**: the dark base everything sits on.
/// * **Silver**: glass, metal and text.
/// * **Bronze**: a muted champagne, used only for things that deserve
///   attention (unread, connected, active). [clay] is its deep shade, kept
///   for errors and destructive actions.
abstract final class AppColors {
  // Graphite
  static const graphite950 = Color(0xFF0C0E12);
  static const graphite900 = Color(0xFF12151A);
  static const graphite800 = Color(0xFF1A1E25);
  static const graphite700 = Color(0xFF252B33);
  static const graphite600 = Color(0xFF343B45);

  // Silver
  static const silver100 = Color(0xFFEDEFF3);
  static const silver200 = Color(0xFFD5D9E0);
  static const silver300 = Color(0xFFB6BCC7);
  static const silver400 = Color(0xFF8E96A3);
  static const silver500 = Color(0xFF6B7380);

  // Bronze
  static const bronze300 = Color(0xFFDCC3A1);
  static const bronze400 = Color(0xFFC9A77C);
  static const bronze500 = Color(0xFFA8845A);
  static const bronze700 = Color(0xFF6E5233);
  static const clay = Color(0xFFC27A5E);

  /// Polished metal: primary buttons, the send button.
  static const silverMetal = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF1F3F6), Color(0xFFBEC4CE), Color(0xFFE2E5EA), Color(0xFF9CA4B1)],
    stops: [0, 0.42, 0.62, 1],
  );

  /// Outgoing message bubbles: softer than [silverMetal] so text stays calm.
  static const silverBubble = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFDFE3E8), Color(0xFFB9C0CA)],
  );

  /// Unread badges and other small attention marks.
  static const bronzeMetal = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [bronze300, bronze500],
  );

  /// The body of a glass panel.
  static final glassFill = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      const Color(0xFFDDE2EA).withValues(alpha: 0.17),
      const Color(0xFFB6BCC7).withValues(alpha: 0.05),
    ],
  );

  /// The light catching the edge of a glass panel.
  static final glassRim = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Colors.white.withValues(alpha: 0.42),
      Colors.white.withValues(alpha: 0.07),
      Colors.white.withValues(alpha: 0.20),
    ],
    stops: const [0, 0.55, 1],
  );

  /// The same rim, warmed up to mark something as needing attention.
  static final bronzeRim = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      bronze300.withValues(alpha: 0.70),
      bronze400.withValues(alpha: 0.12),
      bronze400.withValues(alpha: 0.30),
    ],
    stops: const [0, 0.55, 1],
  );
}
