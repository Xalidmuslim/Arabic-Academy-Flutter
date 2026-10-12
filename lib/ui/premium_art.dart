import 'package:flutter/material.dart';

/// Original modern design assets, stored locally for fast, offline rendering.
/// All lesson texts, controls, prices and accessible labels remain Flutter widgets.
class PremiumArt {
  static const background = 'assets/images/modern_background.webp';
  static const hero = 'assets/images/modern_hero.webp';
  static const emblem = 'assets/images/academy_emblem.webp';
  static const icons = <String>[
    'books', 'video', 'homework', 'students',
    'wallet', 'microphone', 'tests', 'settings',
  ];

  static String iconPath(String icon) => 'assets/images/icon_$icon.webp';
}

class ArtworkBackdrop extends StatelessWidget {
  const ArtworkBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: IgnorePointer(
          child: Opacity(
            opacity: 0.12,
            child: Image.asset(PremiumArt.background,
              fit: BoxFit.cover, alignment: Alignment.topCenter,
              gaplessPlayback: true),
          ),
        ),
      ),
      child,
    ],
  );
}

class ArtworkIcon extends StatelessWidget {
  const ArtworkIcon(this.name, {super.key, this.size = 60});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size, height: size,
    child: Image.asset(PremiumArt.iconPath(name),
      fit: BoxFit.contain, filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) =>
        const Icon(Icons.auto_stories_rounded, color: Color(0xFF174B3E)),
    ),
  );
}

class ArtworkHeroLayer extends StatelessWidget {
  const ArtworkHeroLayer({super.key});
  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: IgnorePointer(
      child: Opacity(
        opacity: 0.20,
        child: Image.asset(PremiumArt.hero,
          fit: BoxFit.cover, alignment: Alignment.center,
          color: const Color(0xFF0E4638),
          colorBlendMode: BlendMode.multiply),
      ),
    ),
  );
}
