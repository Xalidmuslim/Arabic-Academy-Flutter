import 'package:flutter/material.dart';

/// A single standalone illustration, fitted inside its entire frame.
/// Neither the source image nor any part of it is cropped or stretched.
class FittedStudyArtwork extends StatelessWidget {
  const FittedStudyArtwork({
    super.key,
    required this.image,
    this.size = 120,
    this.width,
    this.height,
    this.semanticLabel,
  });

  final ImageProvider image;
  final double size;
  final double? width;
  final double? height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final imageWidth = width ?? size;
    final imageHeight = height ?? size;
    final base = imageWidth < imageHeight ? imageWidth : imageHeight;
    return SizedBox(
      width: imageWidth,
      height: imageHeight,
      child: DecoratedBox(
        key: const ValueKey('fitted-study-artwork'),
        decoration: BoxDecoration(
          // A subtle raised edge, with the original illustration always
          // fully visible: no ClipRRect, cut-outs or BoxFit.cover.
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(
                Colors.white.withValues(alpha: dark ? .045 : .48),
                colors.surface,
              ),
              colors.surface,
              Color.alphaBlend(
                colors.primary.withValues(alpha: dark ? .08 : .045),
                colors.surface,
              ),
            ],
          ),
          borderRadius: BorderRadius.circular(21),
          border: Border.all(
            color: dark
                ? colors.outlineVariant.withValues(alpha: .24)
                : Colors.white.withValues(alpha: .72),
            width: .85,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: dark ? .24 : .14),
              blurRadius: 23,
              spreadRadius: -7,
              offset: const Offset(0, 9),
            ),
            BoxShadow(
              color: colors.shadow.withValues(alpha: dark ? .12 : .06),
              blurRadius: 30,
              spreadRadius: -14,
              offset: const Offset(0, 17),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(base * .055),
          child: Image(
            key: const ValueKey('fitted-study-image'),
            image: image,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            filterQuality: FilterQuality.medium,
            semanticLabel: semanticLabel,
            errorBuilder: (_, __, ___) => Center(
              child: Icon(Icons.image_not_supported_outlined,
                color: colors.onSurfaceVariant, size: base * .3),
            ),
          ),
        ),
      ),
    );
  }
}
