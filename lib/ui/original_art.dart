import 'dart:math';
import 'package:flutter/material.dart';
import 'design_tokens.dart';

/// Complete, original generated assets. Historical reference crops are absent
/// from pubspec and can never be restored over this directory by a build.
abstract final class PremiumArt {
  static const background = 'assets/artwork/hero.webp';
  static const hero = background;
  static const emblem = 'assets/artwork/emblem.webp';
  static const icons = [
    'books',
    'video',
    'homework',
    'students',
    'vocabulary',
    'microphone',
    'tests',
    'settings',
  ];
  static const _scenes = {
    'books': 'lessons',
    'grammar': 'grammar',
    'vocabulary': 'vocabulary',
    'analytics': 'progress',
    'microphone': 'oral',
    'video': 'live',
    'homework': 'exercises',
    'tests': 'exercises',
    'students': 'teacher',
  };
  static String iconPath(String name) =>
      'assets/artwork/${_scenes[name] ?? name}.webp';
}

class ArtworkIcon extends StatelessWidget {
  const ArtworkIcon(this.name, {super.key, this.size = 60});
  final String name;
  final double size;
  @override
  Widget build(BuildContext context) {
    if (PremiumArt._scenes.containsKey(name)) {
      return Image.asset(
        PremiumArt.iconPath(name),
        width: size,
        height: size,
        fit: BoxFit.contain,
        cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
        excludeFromSemantics: true,
        filterQuality: FilterQuality.medium,
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _SystemIconPainter(name)),
    );
  }
}

/// An original scalable miniature family for compact system controls.
class _SystemIconPainter extends CustomPainter {
  const _SystemIconPainter(this.name);
  final String name;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 48, size.height / 48);
    final shape = RRect.fromRectAndRadius(
      const Rect.fromLTWH(5, 5, 38, 38),
      const Radius.circular(12),
    );
    canvas.drawRRect(
      shape.shift(const Offset(2, 3)),
      Paint()..color = const Color(0x228B6F47),
    );
    canvas.drawRRect(
      shape,
      Paint()..color = const Color(0xFFF3E7D6),
    );
    final pen = Paint()
      ..color = DesignTokens.deepOlive
      ..strokeWidth = 2.3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (name) {
      case 'schedule':
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(13, 15, 22, 21),
            const Radius.circular(3),
          ),
          pen,
        );
        canvas.drawLine(const Offset(13, 21), const Offset(35, 21), pen);
        canvas.drawLine(const Offset(19, 12), const Offset(19, 17), pen);
        canvas.drawLine(const Offset(29, 12), const Offset(29, 17), pen);
        for (final x in [19.0, 25.0, 31.0]) {
          canvas.drawCircle(Offset(x, 27), 1, pen);
        }
      case 'settings':
        for (var i = 0; i < 8; i++) {
          final a = i * pi / 4;
          canvas.drawLine(
            Offset(24 + cos(a) * 10, 24 + sin(a) * 10),
            Offset(24 + cos(a) * 14, 24 + sin(a) * 14),
            pen,
          );
        }
        canvas.drawCircle(const Offset(24, 24), 10, pen);
        canvas.drawCircle(const Offset(24, 24), 4, pen);
      case 'bookmark':
        canvas.drawPath(
          Path()
            ..moveTo(16, 13)
            ..lineTo(32, 13)
            ..lineTo(32, 36)
            ..lineTo(24, 30)
            ..lineTo(16, 36)
            ..close(),
          pen,
        );
      case 'messages':
        canvas.drawPath(
          Path()
            ..moveTo(14, 15)
            ..lineTo(34, 15)
            ..lineTo(34, 30)
            ..lineTo(23, 30)
            ..lineTo(15, 36)
            ..lineTo(16, 30)
            ..lineTo(14, 30)
            ..close(),
          pen,
        );
        canvas.drawLine(const Offset(19, 21), const Offset(29, 21), pen);
        canvas.drawLine(const Offset(19, 25), const Offset(26, 25), pen);
      case 'notifications':
        canvas.drawPath(
          Path()
            ..moveTo(14, 31)
            ..quadraticBezierTo(18, 26, 18, 19)
            ..quadraticBezierTo(24, 9, 30, 19)
            ..quadraticBezierTo(30, 26, 34, 31)
            ..close(),
          pen,
        );
        canvas.drawArc(const Rect.fromLTWH(20, 30, 8, 8), 0, pi, false, pen);
      case 'search':
        canvas.drawCircle(const Offset(22, 22), 9, pen);
        canvas.drawLine(const Offset(29, 29), const Offset(36, 36), pen);
      case 'profile':
        canvas.drawCircle(const Offset(24, 17), 6, pen);
        canvas.drawArc(const Rect.fromLTWH(13, 25, 22, 20), pi, pi, false, pen);
      case 'download':
        canvas.drawLine(const Offset(24, 12), const Offset(24, 29), pen);
        canvas.drawPath(
          Path()
            ..moveTo(17, 23)
            ..lineTo(24, 30)
            ..lineTo(31, 23),
          pen,
        );
        canvas.drawPath(
          Path()
            ..moveTo(13, 30)
            ..lineTo(13, 35)
            ..lineTo(35, 35)
            ..lineTo(35, 30),
          pen,
        );
      case 'wallet':
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(12, 15, 25, 20),
            const Radius.circular(4),
          ),
          pen,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(28, 21, 11, 8),
            const Radius.circular(2),
          ),
          pen,
        );
        canvas.drawCircle(const Offset(32, 25), 1, pen);
      default:
        canvas.drawPath(
          Path()
            ..moveTo(12, 23)
            ..lineTo(24, 13)
            ..lineTo(36, 23)
            ..moveTo(16, 21)
            ..lineTo(16, 35)
            ..lineTo(32, 35)
            ..lineTo(32, 21),
          pen,
        );
    }
  }

  @override
  bool shouldRepaint(_SystemIconPainter oldDelegate) =>
      oldDelegate.name != name;
}

class ArtworkBackdrop extends StatelessWidget {
  const ArtworkBackdrop({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: RepaintBoundary(
          child: IgnorePointer(child: CustomPaint(painter: _MatteTexture())),
        ),
      ),
      child,
    ],
  );
}

class _MatteTexture extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(17);
    final paint = Paint()..color = const Color(0x088B6F47);
    for (var i = 0; i < 400; i++) {
      canvas.drawCircle(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
        0.7,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_MatteTexture oldDelegate) => false;
}

class ArtworkHeroLayer extends StatelessWidget {
  const ArtworkHeroLayer({super.key});
  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: IgnorePointer(
      child: Opacity(
        opacity: 0.25,
        child: Image.asset(
          PremiumArt.hero,
          fit: BoxFit.cover,
          cacheWidth: 900,
          excludeFromSemantics: true,
        ),
      ),
    ),
  );
}
