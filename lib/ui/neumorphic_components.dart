import 'package:flutter/material.dart';
import 'design_tokens.dart';

/// Shared, deliberately lightweight soft-matte visual language.
/// Solid warm relief with a real exposed edge, no gradient or backdrop blur.
abstract final class NeumorphicPalette {
  static const background = DesignTokens.ivory;
  static const surface = Color(0xFFF6EBDE);
  static const ink = DesignTokens.ink;
  static const olive = DesignTokens.olive;
  static const secondary = DesignTokens.secondary;
  static const outline = Color(0xCCFFFFFF);
}

/// Solid matte elevation with no painted contour, hard extrusion or gradient.
/// A soft close-contact shadow plus a broad ambient shadow reproduce the
/// understated raised panels of the supplied reference at mobile scale.
class NeumorphicSurface extends StatelessWidget {
  const NeumorphicSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 22,
    this.emphasized = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  /// Stronger lighting is reserved for main interactive cards.
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('matte-3d-surface'),
      decoration: BoxDecoration(
        color: const Color(0xFFF5ECDF),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: emphasized ? const [
          BoxShadow(color: Color(0x4A493B2F), offset: Offset(0, 5), blurRadius: 10, spreadRadius: -3),
          BoxShadow(color: Color(0x2B5B483B), offset: Offset(0, 13), blurRadius: 23, spreadRadius: -6),
          BoxShadow(color: Color(0x125B483B), offset: Offset(0, 23), blurRadius: 34, spreadRadius: -10),
        ] : const [
          // Defines the elevation without creating a brown outline.
          BoxShadow(
            color: Color(0x3F634F3F),
            offset: Offset(1, 5),
            blurRadius: 11,
            spreadRadius: -4,
          ),
          // Wider falloff makes it feel physically raised, not boxed-in.
          BoxShadow(
            color: Color(0x23584535),
            offset: Offset(0, 13),
            blurRadius: 25,
            spreadRadius: -7,
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Padding(padding: padding, child: child),
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
      emphasized: true,
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
      emphasized: true,
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
