import 'package:flutter/material.dart';
import 'design_tokens.dart';

/// Shared, deliberately lightweight soft-matte visual language.
/// Two pre-defined shadows and local WebP images avoid expensive backdrop blur.
abstract final class NeumorphicPalette {
  static const background = DesignTokens.ivory;
  static const surface = Color(0xFFF7F0E2);
  static const ink = DesignTokens.ink;
  static const olive = DesignTokens.olive;
  static const secondary = DesignTokens.secondary;
  static const outline = Color(0xCCFFFFFF);
}

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
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: NeumorphicPalette.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: NeumorphicPalette.outline, width: 1),
      boxShadow: const [
        BoxShadow(
          color: Color(0xBFFFFFFF),
          offset: Offset(-4, -4),
          blurRadius: 10,
        ),
        BoxShadow(
          color: Color(0x358D7C65),
          offset: Offset(5, 6),
          blurRadius: 14,
        ),
      ],
    ),
    child: Material(type: MaterialType.transparency, child: child),
  );
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
    scale: _pressed ? 0.975 : 1,
    duration: Duration(
      milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 115,
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
