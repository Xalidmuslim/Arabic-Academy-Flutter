import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Displays an individual 3D illustration with no square tile or outline.
///
/// The artwork remains entirely visible (BoxFit.contain). A blurred duplicate
/// of its alpha silhouette creates a soft, object-shaped shadow instead of
/// a rounded rectangular frame. Course cards provide their own background.
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
      key: const ValueKey('fitted-study-artwork'),
      width: imageWidth,
      height: imageHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // An alpha-shaped shadow follows the actual 3D silhouette.
          // Never apply a box shadow, border, gradient or square backdrop.
          Padding(
            padding: EdgeInsets.all(base * .045),
            child: Transform.translate(
              offset: Offset(0, base * .036),
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(
                  sigmaX: base * .025,
                  sigmaY: base * .025,
                ),
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    colors.shadow.withValues(alpha: dark ? .26 : .17),
                    BlendMode.srcIn,
                  ),
                  child: Image(
                    image: image,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(base * .025),
            child: Image(
              key: const ValueKey('fitted-study-image'),
              image: image,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              semanticLabel: semanticLabel,
              errorBuilder: (_, __, ___) => Center(
                child: Icon(
                  Icons.image_not_supported_outlined,
                  color: colors.onSurfaceVariant,
                  size: base * .3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
