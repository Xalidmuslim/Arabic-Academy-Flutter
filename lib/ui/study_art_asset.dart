/// References only approved, standalone generated 3D files. A picture
/// must be created for the particular teaching concept; old screen captures,
/// sprite atlases, crops and recycled generic illustrations are not accepted.
abstract final class StudyArtAsset {
  static final RegExp _standalone = RegExp(
    r'^assets/artwork/lesson_generated/[a-z0-9][a-z0-9_-]*\\.webp$',
  );

  static String? valid(Object? source) {
    if (source is! String) return null;
    final trimmed = source.trim();
    return _standalone.hasMatch(trimmed) ? trimmed : null;
  }
}
