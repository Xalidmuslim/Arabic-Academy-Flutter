import 'package:flutter/material.dart';

import '../../core/academy_state.dart';
import '../../ui/components.dart';
import '../../ui/design_tokens.dart';

/// Offline guided tracing, not OCR or an automatic handwriting grade.
/// The letter shapes are rendered by the embedded Arabic font.
class HandwritingScreen extends StatefulWidget {
  const HandwritingScreen({super.key, required this.state});
  final AcademyState state;

  @override
  State<HandwritingScreen> createState() => _HandwritingScreenState();
}

class _HandwritingScreenState extends State<HandwritingScreen> {
  static const letters = [
    'ا', 'ب', 'ت', 'ث', 'ج', 'ح', 'خ', 'د', 'ذ', 'ر', 'ز',
    'س', 'ش', 'ص', 'ض', 'ط', 'ظ', 'ع', 'غ', 'ف', 'ق',
    'ك', 'ل', 'م', 'ن', 'ه', 'و', 'ي',
  ];
  static const forms = <String, List<String>>{
    'ب': ['ب', 'بـ', 'ـبـ', 'ـب'],
    'ت': ['ت', 'تـ', 'ـتـ', 'ـت'],
    'ث': ['ث', 'ثـ', 'ـثـ', 'ـث'],
    'ج': ['ج', 'جـ', 'ـجـ', 'ـج'],
    'ح': ['ح', 'حـ', 'ـحـ', 'ـح'],
    'خ': ['خ', 'خـ', 'ـخـ', 'ـخ'],
    'س': ['س', 'سـ', 'ـسـ', 'ـس'],
    'ش': ['ش', 'شـ', 'ـشـ', 'ـش'],
    'ص': ['ص', 'صـ', 'ـصـ', 'ـص'],
    'ض': ['ض', 'ضـ', 'ـضـ', 'ـض'],
    'ط': ['ط', 'طـ', 'ـطـ', 'ـط'],
    'ظ': ['ظ', 'ظـ', 'ـظـ', 'ـظ'],
    'ع': ['ع', 'عـ', 'ـعـ', 'ـع'],
    'غ': ['غ', 'غـ', 'ـغـ', 'ـغ'],
    'ف': ['ف', 'فـ', 'ـفـ', 'ـف'],
    'ق': ['ق', 'قـ', 'ـقـ', 'ـق'],
    'ك': ['ك', 'كـ', 'ـكـ', 'ـك'],
    'ل': ['ل', 'لـ', 'ـلـ', 'ـل'],
    'م': ['م', 'مـ', 'ـمـ', 'ـم'],
    'ن': ['ن', 'نـ', 'ـنـ', 'ـن'],
    'ه': ['ه', 'هـ', 'ـهـ', 'ـه'],
    'ي': ['ي', 'يـ', 'ـيـ', 'ـي'],
  };

  String _letter = 'ب';
  List<List<Offset>> _strokes = [];
  bool _saving = false;
  int _savedCount = 0;

  void _choose(String value) => setState(() {
    _letter = value;
    _strokes = [];
  });

  Future<void> _save() async {
    if (_strokes.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.state.recordAttempt(
        lessonId: 'arabic-alphabet',
        exerciseId: 'handwriting:$_letter',
        answer: {
          'letter': _letter,
          'stroke_count': _strokes.length,
          'review_type': 'manual',
        },
        status: 'needsReview',
        points: 0,
      );
      if (mounted) setState(() {
        _savedCount++;
        _strokes = [];
      });
      if (mounted) notice(context,
        'Тренировка сохранена. Сравните свою букву с образцом.');
    } catch (error) {
      if (mounted) notice(context, 'Не удалось сохранить: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Тренажёр арабского письма')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 155),
      children: [
        const Text('Выберите букву и обведите светлый образец пальцем. '
          'Приложение сохраняет факт тренировки, но не оценивает '
          'правильность почерка автоматически.',
          style: TextStyle(fontSize: 12, color: DesignTokens.secondary)),
        const SizedBox(height: 12),
        SizedBox(
          height: 86,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final letter in letters)
                Padding(
                  padding: const EdgeInsets.only(right: 7),
                  child: ChoiceChip(
                    key: ValueKey('handwriting-letter-$letter'),
                    label: Text(letter,
                      style: const TextStyle(
                        fontFamily: 'NotoNaskhArabic', fontSize: 24)),
                    selected: _letter == letter,
                    onSelected: (_) => _choose(letter),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text('Буква: $_letter', textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: DesignTokens.cardSurface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: DesignTokens.softOutline),
          ),
          height: 285,
          child: LayoutBuilder(builder: (context, constraints) =>
            GestureDetector(
              key: const ValueKey('handwriting-canvas'),
              behavior: HitTestBehavior.opaque,
              onPanStart: (details) => setState(() {
                _strokes.add([details.localPosition]);
              }),
              onPanUpdate: (details) => setState(() {
                if (_strokes.isNotEmpty) {
                  _strokes.last.add(details.localPosition);
                }
              }),
              child: CustomPaint(
                size: Size(constraints.maxWidth, 285),
                painter: _TracePainter(_letter, _strokes),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: _strokes.isEmpty ? null : () => setState(() {
              _strokes.removeLast();
            }),
            icon: const Icon(Icons.undo),
            label: const Text('Отменить линию'),
          )),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(
            onPressed: _strokes.isEmpty ? null :
                () => setState(() => _strokes = []),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Очистить'),
          )),
        ]),
        const SizedBox(height: 10),
        FilledButton.icon(
          key: const ValueKey('handwriting-save'),
          onPressed: _strokes.isEmpty || _saving ? null : _save,
          icon: const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Сохранение…' : 'Сохранить тренировку'),
        ),
        const SizedBox(height: 16),
        const Text('Как меняется форма буквы',
          style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        if (forms.containsKey(_letter))
          Panel(child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final form in forms[_letter]!)
                Expanded(child: Column(children: [
                  NaskhText(form, size: 30, align: TextAlign.center),
                ])),
            ],
          ))
        else
          const Text('Эта буква не соединяется со всеми соседними буквами. '
            'Смотрите форму в реальных словах учебника.',
            style: TextStyle(fontSize: 12, color: DesignTokens.secondary)),
        const SizedBox(height: 10),
        Text('Сохранённых тренировок за сеанс: $_savedCount',
          style: const TextStyle(color: DesignTokens.secondary)),
      ],
    ),
  );
}

class _TracePainter extends CustomPainter {
  const _TracePainter(this.letter, this.strokes);
  final String letter;
  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final text = TextPainter(
      text: TextSpan(text: letter,
        style: const TextStyle(
          fontFamily: 'NotoNaskhArabic',
          fontSize: 170,
          color: Color(0x4C849275),
          height: 1.4,
        )),
      textDirection: TextDirection.rtl,
    )..layout();
    text.paint(canvas,
      Offset((size.width - text.width) / 2,
             (size.height - text.height) / 2));
    final pen = Paint()
      ..color = DesignTokens.deepOlive
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final points in strokes) {
      if (points.isEmpty) continue;
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      if (points.length == 1) {
        canvas.drawCircle(points.first, 3, Paint()..color = DesignTokens.deepOlive);
      } else {
        canvas.drawPath(path, pen);
      }
    }
    text.dispose();
  }

  @override
  bool shouldRepaint(covariant _TracePainter old) => true;
}
