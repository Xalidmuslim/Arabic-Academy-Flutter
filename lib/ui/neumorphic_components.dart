import 'package:flutter/material.dart';
import 'design_tokens.dart';

/// Shared, deliberately lightweight soft-matte visual language.
/// Directional lighting and layered shadows use no expensive backdrop blur.
abstract final class NeumorphicPalette {
  static const background = DesignTokens.ivory;
  static const surface = Color(0xFFF7F0E2);
  static const ink = DesignTokens.ink;
  static const olive = DesignTokens.olive;
  static const secondary = DesignTokens.secondary;
  static const outline = Color(0xCCFFFFFF);
}

/// A raised matte card: directional light, a narrow chamfered rim,
/// and two warm contact/ambient shadows. No blur filters or images.
/// Keep the inner Material transparent so existing InkWell/ListTile work.
class NeumorphicSurface extends StatelessWidget {
  const NeumorphicSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 22,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final outerRadius = BorderRadius.circular(radius);
    final innerRadius = BorderRadius.circular(
      (radius - 2.0).clamp(0.0, double.infinity).toDouble(),
    );
    return DecoratedBox(
      key: const ValueKey('matte-3d-surface'),
      decoration: BoxDecoration(
        borderRadius: outerRadius,
        // Matte outer rim: restrained upper illumination and a thin lower lip.
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFAF1),
            Color(0xFFF2E8DA),
            Color(0xFFCDBAA5),
          ],
          stops: [0.0, 0.66, 1.0],
        ),
        boxShadow: const [
          // A restrained fill light, not a glowing white halo.
          BoxShadow(
            color: Color(0x76FFFFFF),
            offset: Offset(-2, -2),
            blurRadius: 7,
          ),
          // Crisp contact shade makes the card visibly sit above the page.
          BoxShadow(
            color: Color(0x485A4A36),
            offset: Offset(3, 5),
            blurRadius: 6,
            spreadRadius: -1,
          ),
          // Soft, subtle ambient depth under the physical edge.
          BoxShadow(
            color: Color(0x225A4A36),
            offset: Offset(0, 12),
            blurRadius: 19,
            spreadRadius: -5,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: innerRadius,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF9F3E9),
                Color(0xFFF6EEE3),
                Color(0xFFF0E6D8),
              ],
              stops: [0.0, 0.55, 1.0],
            ),
            border: Border.all(
              color: const Color(0x52FFFFFF),
              width: 0.6,
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

class NeumorphicFeatureTile extends StatefulWidget {
  const NeumorphicFeatureTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.image,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String image;
  final VoidCallback onTap;

  @override
  State<NeumorphicFeatureTile> createState() => _NeumorphicFeatureTileState();
}

class _NeumorphicFeatureTileState extends State<NeumorphicFeatureTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: _pressed ? 0.985 : 1,
    duration: Duration(
      milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 135,
    ),
    curve: Curves.easeOutCubic,
    child: NeumorphicSurface(
      padding: EdgeInsets.zero,
      radius: 21,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(21),
        child: InkWell(
          borderRadius: BorderRadius.circular(21),
          onHighlightChanged: (value) {
            if (mounted) setState(() => _pressed = value);
          },
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(11, 8, 11, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Center(
                    child: Image.asset(
                      widget.image,
                      fit: BoxFit.contain,
                      cacheWidth: 360,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.auto_stories_rounded,
                        size: 56,
                        color: NeumorphicPalette.olive,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: NeumorphicPalette.ink,
                    fontWeight: FontWeight.w800,
                    fontVariations: [FontVariation('wght', 800)],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: NeumorphicPalette.secondary,
                    fontSize: 10.5,
                    height: 1.18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// No placeholder achievement numbers: all values come from AcademyState.
class NeumorphicCourseHero extends StatelessWidget {
  const NeumorphicCourseHero({
    super.key,
    required this.progress,
    required this.completed,
    required this.total,
    required this.onContinue,
  });

  final double progress;
  final int completed;
  final int total;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final value = progress.clamp(0.0, 1.0).toDouble();
    return NeumorphicSurface(
      padding: const EdgeInsets.fromLTRB(16, 13, 15, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Мой курс',
                      style: TextStyle(
                        color: NeumorphicPalette.secondary,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Базовый уровень 1',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: NeumorphicPalette.ink,
                        fontWeight: FontWeight.w800,
                        fontVariations: [FontVariation('wght', 800)],
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 48,
                width: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: value,
                        strokeWidth: 5,
                        strokeCap: StrokeCap.round,
                        color: NeumorphicPalette.olive,
                        backgroundColor: const Color(0xFFDDD1C0),
                      ),
                    ),
                    Text(
                      '${(value * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        fontVariations: [FontVariation('wght', 800)],
                        color: NeumorphicPalette.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            'Пройдено $completed из $total уроков',
            style: const TextStyle(
              color: NeumorphicPalette.secondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 6,
                    color: NeumorphicPalette.olive,
                    backgroundColor: const Color(0xFFDDD1C0),
                  ),
                ),
              ),
              const SizedBox(width: 11),
              SizedBox(
                height: 36,
                child: FilledButton(
                  onPressed: onContinue,
                  style: FilledButton.styleFrom(
                    backgroundColor: NeumorphicPalette.olive,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                  child: const Text(
                    'Продолжить',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
