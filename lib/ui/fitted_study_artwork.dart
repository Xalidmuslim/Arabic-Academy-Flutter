import 'package:flutter/material.dart';

/// A single standalone illustration, fitted inside its entire frame.
/// Neither the source image nor any part of it is cropped or stretched.
class FittedStudyArtwork extends StatelessWidget {
  const FittedStudyArtwork({
    super.key,
    required this.image,
    this.size = 120,
    this.semanticLabel,
  });

  final ImageProvider image;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        key: const ValueKey('fitted-study-artwork'),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(21),
          border: Border.all(color: colors.outlineVariant.withValues(alpha: .28)),
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
          padding: EdgeInsets.all(size * .055),
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
                color: colors.onSurfaceVariant, size: size * .3),
            ),
          ),
        ),
      ),
    );
  }
}
