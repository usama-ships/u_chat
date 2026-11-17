import 'package:flutter/material.dart';

/// Lavender Glass: a soft purple header over light, frosted sheets.
///
/// Four tones carry the whole app:
///   * Mist `#F7F7F7`: the sheets everything sits on.
///   * Ink `#1A1A1A`: text.
///   * Lavender `#6A5BC2`: the header, your own messages and every main action.
///   * Lemon `#F4F185`: one highlight at a time, such as the selected filter.
///
/// Glass is a translucent white fill with a bright edge over a still
/// background, so it costs nothing extra per frame. Green means online and
/// pink-red means unread or a problem.
abstract final class AppColors {
  // Sheets and surfaces, back to front.
  static const bg = Color(0xFFF7F7F7);
  static const bgElevated = Color(0xFFFFFFFF); // composer, banners
  static const surface = Color(0xFFFFFFFF); // cards
  static const surfaceRaised = Color(0xFFFFFFFF); // dialogs, sheets
  static const surfaceHigh = Color(0xFFEFEDF8); // pressed rows, chips

  /// The other person's message bubbles.
  static const bubbleIn = Color(0xFFFFFFFF);

  /// Bottom of the chat sheet, tinted towards lavender.
  static const chatBottom = Color(0xFFF1EFFA);

  // Header.
  static const headerTop = Color(0xFF7768D0);
  static const headerBottom = Color(0xFF6A5BC2);
  static const onHeader = Color(0xFFFFFFFF);
  static const onHeaderMuted = Color(0xC7FFFFFF);

  /// Frosted circles and chips on the purple header.
  static const headerGlass = Color(0x29FFFFFF);
  static const headerGlassBorder = Color(0x3DFFFFFF);

  // Glass on the light sheets.
  static const glassTop = Color(0xE6FFFFFF);
  static const glassBottom = Color(0xB3FFFFFF);
  static const glassBorder = Color(0x1A6A5BC2);

  /// Fill of a glass panel: brighter at the top-left, like light on glass.
  static const glassFill = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [glassTop, glassBottom],
  );

  /// The soft lavender shadow under floating glass.
  static const glassShadow = [
    BoxShadow(color: Color(0x146A5BC2), blurRadius: 24, offset: Offset(0, 8)),
  ];

  static const border = Color(0x0F1A1A1A);
  static const borderStrong = Color(0x1F1A1A1A);

  // Text.
  static const text = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF4B4B57);
  static const textMuted = Color(0xFF8A8A99);
  static const textFaint = Color(0xFFB9B9C6);

  // Accent.
  static const accent = Color(0xFF6A5BC2);
  static const accentLight = Color(0xFF6A5BC2); // accent text and icons on light
  static const accentDeep = Color(0xFF5546AE);
  static const violet = Color(0xFF8A7BE0);
  static const accentSoft = Color(0x1F6A5BC2); // tinted backgrounds
  static const accentBorder = Color(0x666A5BC2);
  static const onAccent = Colors.white;

  // Highlight.
  static const highlight = Color(0xFFF4F185);
  static const onHighlight = Color(0xFF1A1A1A);

  // Status.
  static const success = Color(0xFF34C77B);
  static const danger = Color(0xFFF0506E);
  static const warning = Color(0xFFE0A019);

  /// Primary buttons, your own message bubbles.
  static const accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7A6BD6), accentDeep],
  );

  /// The header behind every screen.
  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [headerTop, headerBottom],
  );
}
