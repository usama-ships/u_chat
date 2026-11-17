import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';

/// A coloured circle with the person's initial and, when connected, a green
/// dot. The colour comes from their ID, so a contact looks the same on every
/// screen and is easy to tell apart from others at a glance.
class PeerAvatar extends StatelessWidget {
  const PeerAvatar({
    super.key,
    required this.seed,
    required this.name,
    this.size = 52,
    this.online = false,
    this.heroTag,
  });

  final String seed;
  final String name;
  final double size;
  final bool online;
  final Object? heroTag;

  static const _palettes = <List<Color>>[
    [Color(0xFF8A7BE0), Color(0xFF6A5BC2)], // lavender
    [Color(0xFFFF9A7B), Color(0xFFF0506E)], // coral
    [Color(0xFF5EC8E5), Color(0xFF4F8BE0)], // sky
    [Color(0xFFF7B955), Color(0xFFF07B3F)], // amber
    [Color(0xFF5FD3A0), Color(0xFF2FA67A)], // mint
    [Color(0xFFE48BD8), Color(0xFFA35CD0)], // orchid
  ];

  @override
  Widget build(BuildContext context) {
    final colors = colorsFor(seed);
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
      ),
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.40,
          fontWeight: FontWeight.w700,
          height: 1,
          // Heroes fly outside any DefaultTextStyle.
          decoration: TextDecoration.none,
        ),
      ),
    );
    if (heroTag != null) disc = Hero(tag: heroTag!, child: disc);

    final dot = (size * 0.28).clamp(10.0, 18.0);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          disc,
          Positioned(
            right: -1,
            bottom: -1,
            child: AnimatedScale(
              duration: Motion.medium,
              curve: Motion.pop,
              scale: online ? 1 : 0,
              child: Semantics(
                label: online ? 'Online' : null,
                child: Container(
                  width: dot,
                  height: dot,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.success,
                    border: Border.all(color: Colors.white, width: dot * 0.18),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The gradient a contact gets everywhere, so the radar can match it.
  static List<Color> colorsFor(String seed) => _palettes[_hash(seed) % _palettes.length];

  /// Stable across runs, unlike [String.hashCode].
  static int _hash(String value) {
    var hash = 0x811c9dc5; // FNV-1a
    for (final unit in value.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return hash >> 7;
  }
}
