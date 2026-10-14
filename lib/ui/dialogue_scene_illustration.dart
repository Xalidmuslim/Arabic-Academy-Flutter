import 'package:flutter/material.dart';

/// Original scalable learning vignette. Faces are intentionally blank:
/// no eyes, nose, mouth or facial expression. Only show scenes when the
/// dialogue title or setting supplies a recognizable context.
class DialogueSceneIllustration extends StatelessWidget {
  const DialogueSceneIllustration({
    super.key,
    required this.setting,
  });

  final String setting;

  static String? sceneFor(String input) {
    final text = input.toLowerCase();
    if (['магазин', 'покуп', 'рынок', 'سوق', 'متجر']
        .any(text.contains)) return 'shop';
    if (['школ', 'класс', 'учител', 'مدرس', 'فصل', 'صف']
        .any(text.contains)) return 'classroom';
    if (['дом', 'семь', 'кухн', 'بيت', 'أسرة', 'عائلة']
        .any(text.contains)) return 'home';
    if (['дорог', 'улиц', 'путь', 'طريق', 'شارع']
        .any(text.contains)) return 'street';
    if (['библиот', 'книг', 'كتاب', 'مكتبة']
        .any(text.contains)) return 'books';
    if (['знаком', 'привет', 'встреч', 'تعارف', 'سلام']
        .any(text.contains)) return 'greeting';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scene = sceneFor(setting);
    if (scene == null) return const SizedBox.shrink();
    return Semantics(
      label: 'Оригинальная учебная иллюстрация: $setting. '
          'Персонажи изображены без черт лица.',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: AspectRatio(
          aspectRatio: 2,
          child: CustomPaint(
            painter: _DialogueScenePainter(scene),
          ),
        ),
      ),
    );
  }
}

class _DialogueScenePainter extends CustomPainter {
  const _DialogueScenePainter(this.scene);
  final String scene;

  void _box(Canvas c, double x, double y, double w, double h,
      Color color, {double radius = 8}) =>
    c.drawRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, w, h), Radius.circular(radius)),
      Paint()..color = color);

  void _oval(Canvas c, double x, double y, double w, double h,
      Color color) =>
    c.drawOval(Rect.fromLTWH(x, y, w, h), Paint()..color = color);

  void _stroke(Canvas c, Offset a, Offset b, Color color, double width) =>
    c.drawLine(a, b, Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round);

  void _person(Canvas c, double x, double y, {
    required Color clothing, required Color scarf,
    bool facingRight = true,
  }) {
    // Floor shadow, draped clothing, arms, hair/scarf, and a fully blank face.
    _oval(c, x - 24, y + 112, 76, 13, const Color(0x296B5743));
    final drape = Path()
      ..moveTo(x, y + 48)
      ..quadraticBezierTo(x - 16, y + 47, x - 19, y + 108)
      ..lineTo(x + 48, y + 108)
      ..quadraticBezierTo(x + 46, y + 49, x + 27, y + 46)
      ..close();
    c.drawPath(drape, Paint()..color = clothing);
    _box(c, x - 13, y + 61, 20, 43, clothing, radius: 12);
    _box(c, x + 30, y + 62, 16, 37, clothing, radius: 9);
    // Head covering is drawn behind the blank face, so facial features
    // can never be mistaken for decorative face marks.
    _oval(c, x - 2, y - 7, 39, 63, scarf);
    _oval(c, x + 5, y + 4, 27, 33, const Color(0xFFE1BA9C));
    _stroke(c, Offset(x + 11, y + 51), Offset(x + 23, y + 56),
      const Color(0x33FFF7E9), 3);
    _oval(c, x + (facingRight ? 45 : -15), y + 83, 11, 15,
      const Color(0xFFE1BA9C));
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 360, size.height / 180);
    _box(canvas, 0, 0, 360, 180, const Color(0xFFF1E9D8));
    _box(canvas, 0, 113, 360, 67, const Color(0xFFE4D7C0), radius: 0);
    _stroke(canvas, const Offset(0, 114), const Offset(360, 114),
      const Color(0x30A98E70), 2);

    if (scene == 'classroom' || scene == 'books') {
      _box(canvas, 18, 21, 113, 67, const Color(0xFFB8BFA2), radius: 7);
      _box(canvas, 25, 28, 99, 53, const Color(0xFFECE7D4), radius: 4);
      for (var i = 0; i < 6; i++) {
        _box(canvas, 37 + i * 13.0, 48, 8, 31,
          i.isEven ? const Color(0xFF789074) : const Color(0xFFA98870),
          radius: 2);
      }
    } else if (scene == 'shop') {
      _box(canvas, 11, 24, 113, 64, const Color(0xFFD4BCA0), radius: 5);
      _box(canvas, 17, 30, 101, 51, const Color(0xFFF5EFE1), radius: 4);
      for (var i = 0; i < 4; i++) {
        _oval(canvas, 25 + i * 23.0, 52, 17, 18,
          i.isEven ? const Color(0xFFBF7552) : const Color(0xFF879F69));
      }
      _stroke(canvas, const Offset(19, 71), const Offset(115, 71),
        const Color(0xFFA08B76), 4);
    } else if (scene == 'home' || scene == 'greeting') {
      _box(canvas, 26, 20, 89, 73, const Color(0xFFD3C4A8), radius: 7);
      _box(canvas, 32, 27, 77, 59, const Color(0xFFF9F3E8), radius: 5);
      _box(canvas, 42, 39, 54, 39, const Color(0xFFBCC6B3), radius: 3);
      _stroke(canvas, const Offset(68, 38), const Offset(68, 79),
        const Color(0xFFEEE8D8), 4);
    } else if (scene == 'street') {
      _box(canvas, 26, 20, 78, 77, const Color(0xFFD4C6B5), radius: 4);
      _box(canvas, 37, 36, 24, 27, const Color(0xFFA0B8B7), radius: 2);
      _box(canvas, 70, 36, 24, 27, const Color(0xFFA0B8B7), radius: 2);
      _oval(canvas, 96, 78, 31, 49, const Color(0xFF82936D));
    }
    _person(canvas, 157, 21,
      clothing: const Color(0xFF788E79),
      scarf: const Color(0xFF9EA58A));
    _person(canvas, 260, 23,
      clothing: const Color(0xFFAF9587),
      scarf: const Color(0xFF917E76), facingRight: false);
    _oval(canvas, 159, 128, 152, 19, const Color(0x2765523D));
    _box(canvas, 164, 125, 141, 11, const Color(0xFFC9AD8C), radius: 4);
    _stroke(canvas, const Offset(175, 137), const Offset(175, 163),
      const Color(0xFFAC9078), 7);
    _stroke(canvas, const Offset(291, 137), const Offset(291, 163),
      const Color(0xFFAC9078), 7);
    if (scene == 'classroom' || scene == 'books') {
      _box(canvas, 204, 114, 37, 11, const Color(0xFF81917A), radius: 2);
      _box(canvas, 211, 109, 30, 6, const Color(0xFFE5D6B5), radius: 1);
    } else if (scene == 'shop') {
      _oval(canvas, 217, 104, 28, 21, const Color(0xFFB27B54));
      _oval(canvas, 229, 100, 21, 24, const Color(0xFF91A571));
    } else {
      _box(canvas, 208, 113, 28, 12, const Color(0xFFD7BD9A), radius: 4);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DialogueScenePainter oldDelegate) =>
      scene != oldDelegate.scene;
}
