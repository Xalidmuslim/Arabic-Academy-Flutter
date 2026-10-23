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
    this.blurSilhouette = true,
  });

  final ImageProvider image;
  final double size;
  final double? width;
  final double? height;
  final String? semanticLabel;
  /// Diagnostic A/B only. Ordinary releases retain the exact soft shadow.
  final bool blurSilhouette;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final imageWidth = width ?? size;
    final imageHeight = height ?? size;
    final base = imageWidth < imageHeight ? imageWidth : imageHeight;
    // Both the subject and its alpha-shaped shadow must share a single
    // image-cache key. Decoding the full original WebP twice per visible
    // scrolling tile wastes raster bandwidth and texture memory.
    final decodeWidth =
        (imageWidth * MediaQuery.devicePixelRatioOf(context)).ceil();
    final sizedImage = ResizeImage.resizeIfNeeded(
      decodeWidth,
      null,
      image,
    );
    // Flutter perf guidance recommends pre-calculating static effects to
    // avoid per-frame offscreen layers. CI prepares transparent PNG masks from
    // the SAME bundled WebP alpha, blurred at the original 2.5%-size sigma.
    // The approved full-quality subject image is always rendered above it.
    // Opt-in per build so source checkouts without generated masks retain the
    // exact previous ImageFiltered rendering.
    const usePreparedMasks = bool.fromEnvironment(
      'BAYNA_STATIC_SHADOW_ASSETS',
      defaultValue: false,
    );
    String? shadowAsset;
    // Fields are not type-promoted in Dart; capture the image provider locally.
    final source = image;
    if (usePreparedMasks &&
        source is AssetImage &&
        source.assetName.startsWith('assets/artwork/') &&
        source.assetName.endsWith('.webp') &&
        !source.assetName.contains('/shadow_cache/')) {
      final subpath = source.assetName.substring('assets/artwork/'.length);
      shadowAsset = 'assets/artwork/shadow_cache/'
          '${subpath.substring(0, subpath.length - 5).replaceAll('/', '__')}.png';
    }
    final shadowProvider = shadowAsset == null ? null :
        ResizeImage.resizeIfNeeded(decodeWidth, null, AssetImage(shadowAsset));
    final silhouette = ColorFiltered(
      colorFilter: ColorFilter.mode(
        colors.shadow.withValues(alpha: dark ? .26 : .17),
        BlendMode.srcIn,
      ),
      child: Image(
        image: sizedImage,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );

    final maskTint = colors.shadow.withValues(alpha: dark ? .26 : .17);
    Widget liveBlur() => ImageFiltered(
      imageFilter: ui.ImageFilter.blur(
        sigmaX: base * .025,
        sigmaY: base * .025,
      ),
      child: silhouette,
    );
    // Decoding the pre-blurred mask is a standard image texture draw. No
    // repeated Gaussian blur or duplicate tinted WebP texture on raster frames.
    final shadow = !blurSilhouette
        ? silhouette
        : shadowProvider != null
            ? Image(
                image: shadowProvider,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.low,
                excludeFromSemantics: true,
                color: maskTint,
                colorBlendMode: BlendMode.srcIn,
                // Safety fallback if someone builds with the flag but forgets
                // to run the deterministic offline generation script.
                errorBuilder: (_, __, ___) => liveBlur(),
              )
            : liveBlur();

    // v29 drew the immutable artwork directly inside its sliver's existing
    // child repaint boundary. A second one per illustration adds a composited
    // layer and can consume GPU raster-cache memory while scrolling.
    // Keep full-quality subject, shared decode and Gaussian silhouette.
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
              child: shadow,
            ),
          ),
          Padding(
            padding: EdgeInsets.all(base * .025),
            child: Image(
              key: const ValueKey('fitted-study-image'),
              image: sizedImage,
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
