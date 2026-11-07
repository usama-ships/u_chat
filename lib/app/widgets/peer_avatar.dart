import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import 'motion.dart';

/// Metal disc with the person's initial. The finish comes from their ID, so
/// a contact keeps the same look on every screen.
class PeerAvatar extends StatelessWidget {
  const PeerAvatar({
    super.key,
    required this.seed,
    required this.name,
    this.size = 54,
    this.online = false,
    this.heroTag,
  });

  final String seed;
  final String name;
  final double size;
  final bool online;
  final Object? heroTag;

  static const _finishes = <(List<Color>, Color)>[
    ([Color(0xFFE4E7EC), Color(0xFF9AA2AF)], AppColors.graphite900), // silver
    ([Color(0xFF4A525E), Color(0xFF242A32)], AppColors.silver100), // gunmetal
    ([AppColors.bronze300, AppColors.bronze500], AppColors.graphite900), // champagne
    ([Color(0xFF8E96A3), Color(0xFF4F5763)], AppColors.silver100), // steel
  ];

  @override
  Widget build(BuildContext context) {
    final (colors, ink) = _finishes[_hash(seed) % _finishes.length];
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();

    Widget disc = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Text(
        initial,
        style: TextStyle(
          color: ink,
          fontSize: size * 0.40,
          fontWeight: FontWeight.w800,
          height: 1,
          // Heroes fly outside any DefaultTextStyle.
          decoration: TextDecoration.none,
        ),
      ),
    );
    if (heroTag != null) disc = Hero(tag: heroTag!, child: disc);

    final ringGap = size * 0.09;
    return SizedBox(
      width: size + ringGap * 2,
      height: size + ringGap * 2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedOpacity(
            duration: Motion.medium,
            opacity: online ? 1 : 0,
            child: online
                ? Looping(
                    period: const Duration(milliseconds: 2400),
                    reverse: true,
                    restingValue: 0.5,
                    builder: (context, t, _) => Container(
                      width: size + ringGap * 2,
                      height: size + ringGap * 2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.bronze400, width: 1.6),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.bronze400.withValues(alpha: 0.12 + 0.20 * t),
                            blurRadius: 8 + 8 * t,
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          disc,
        ],
      ),
    );
  }

  /// Stable across runs, unlike [String.hashCode].
  static int _hash(String value) {
    var hash = 0x811c9dc5; // FNV-1a
    for (final unit in value.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return hash >> 7;
  }
}
