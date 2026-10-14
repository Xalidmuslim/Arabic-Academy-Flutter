import 'package:flutter/material.dart';
import 'fitted_study_artwork.dart';
import 'study_art_asset.dart';

/// A distinct, semantically matched cue for each unit. Used only while a
/// separately generated, unit-specific 3D scene is not bundled. Never rotates
/// unrelated 3D feature art through the lesson catalog.
class CourseUnitArt extends StatelessWidget {
  const CourseUnitArt({super.key, required this.unitId, this.size = 78, this.imageAsset});
  final String unitId;
  final double size;
  final String? imageAsset;

  static IconData iconFor(String unitId) => switch (unitId) {
    'u1' => Icons.waving_hand_rounded,
    'u2' => Icons.groups_2_outlined,
    'u3' => Icons.bed_outlined,
    'u4' => Icons.wb_sunny_outlined,
    'u5' => Icons.restaurant_outlined,
    'u6' => Icons.access_time_outlined,
    'u7' => Icons.school_outlined,
    'u8' => Icons.work_outline,
    'u9' => Icons.shopping_bag_outlined,
    'u10' => Icons.cloud_outlined,
    'u11' => Icons.place_outlined,
    'u12' => Icons.sports_soccer_outlined,
    'u13' => Icons.flight_takeoff_outlined,
    'u14' => Icons.mosque_outlined,
    'u15' => Icons.health_and_safety_outlined,
    'u16' => Icons.beach_access_outlined,
    _ => Icons.menu_book_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final verified = StudyArtAsset.valid(imageAsset);
    if (verified != null) {
      return FittedStudyArtwork(image: AssetImage(verified), size: size);
    }
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Тематический значок раздела',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: .65),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: .1),
              blurRadius: 19, spreadRadius: -6,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(child: Icon(iconFor(unitId),
          color: scheme.onPrimaryContainer, size: size * .46)),
      ),
    );
  }
}
