import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// Crop coordinates are fractions of the original PDF page bitmap.
/// (0, 0) is its upper left; (1, 1) is its lower right.
@immutable
class DialogueOcrRegion {
  const DialogueOcrRegion({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;

  /// Suggested starting crops for the common two-dialogue page layout.
  /// These are only guides: the student can redraw the crop on any page.
  static const upperDialogue = DialogueOcrRegion(
    left: .57, top: .20, right: .97, bottom: .54,
  );
  static const lowerDialogue = DialogueOcrRegion(
    left: .57, top: .61, right: .97, bottom: .95,
  );

  bool get valid =>
      left.isFinite && top.isFinite && right.isFinite && bottom.isFinite &&
      left >= 0 && top >= 0 && right <= 1 && bottom <= 1 &&
      right - left >= .025 && bottom - top >= .025;

  List<double> get normalizedBounds {
    if (!valid) {
      throw const FormatException('Select a non-empty rectangle on the page.');
    }
    return [left, top, right, bottom];
  }

  static DialogueOcrRegion fromDrag(
    double startX,
    double startY,
    double endX,
    double endY,
  ) {
    final x0 = startX.clamp(0.0, 1.0).toDouble();
    final x1 = endX.clamp(0.0, 1.0).toDouble();
    final y0 = startY.clamp(0.0, 1.0).toDouble();
    final y1 = endY.clamp(0.0, 1.0).toDouble();
    return DialogueOcrRegion(
      left: x0 < x1 ? x0 : x1,
      top: y0 < y1 ? y0 : y1,
      right: x0 > x1 ? x0 : x1,
      bottom: y0 > y1 ? y0 : y1,
    );
  }
}

/// A bitmap of an individually imported PDF page, rendered only on-device.
@immutable
class PrivatePdfPagePreview {
  const PrivatePdfPagePreview({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;

  bool get valid => bytes.isNotEmpty && width > 0 && height > 0;
}
