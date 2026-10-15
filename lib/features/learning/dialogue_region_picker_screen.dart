import 'package:flutter/material.dart';

import '../../services/dialogue_ocr_region.dart';
import '../../ui/design_tokens.dart';

/// The learner explicitly selects the *actual dialogue lines* in their own
/// PDF. No copyright-bearing pages or recognized text leave the device.
class DialogueRegionPickerScreen extends StatefulWidget {
  const DialogueRegionPickerScreen({
    super.key,
    required this.preview,
    required this.pageNumber,
  });

  final PrivatePdfPagePreview preview;
  /// User-facing page number (1 based).
  final int pageNumber;

  @override
  State<DialogueRegionPickerScreen> createState() =>
      _DialogueRegionPickerScreenState();
}

class _DialogueRegionPickerScreenState
    extends State<DialogueRegionPickerScreen> {
  DialogueOcrRegion _region = DialogueOcrRegion.upperDialogue;
  Offset? _dragStart;
  DialogueOcrRegion _previousValidRegion = DialogueOcrRegion.upperDialogue;

  void _choose(DialogueOcrRegion region) {
    setState(() {
      _region = region;
      _previousValidRegion = region;
    });
  }

  void _start(Offset position, Size page) {
    final point = Offset(position.dx / page.width, position.dy / page.height);
    setState(() {
      _dragStart = point;
      _previousValidRegion = _region;
    });
  }

  void _move(Offset position, Size page) {
    final start = _dragStart;
    if (start == null) return;
    setState(() {
      _region = DialogueOcrRegion.fromDrag(
        start.dx,
        start.dy,
        position.dx / page.width,
        position.dy / page.height,
      );
    });
  }

  void _finish() {
    setState(() {
      if (!_region.valid) _region = _previousValidRegion;
      _dragStart = null;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Выберите текст диалога')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 160),
        children: [
          Text(
            'Страница ${widget.pageNumber} · OCR только внутри зелёной области',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Нажмите подходящий вариант или проведите пальцем по странице '
            'от одного угла нужного текста до противоположного. '
            'Не включайте фотографию, заголовок и другой диалог.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 7,
            children: [
              ChoiceChip(
                key: const ValueKey('ocr-crop-upper'),
                label: const Text('Верхний диалог (А)'),
                selected: _region == DialogueOcrRegion.upperDialogue,
                onSelected: (_) => _choose(DialogueOcrRegion.upperDialogue),
              ),
              ChoiceChip(
                key: const ValueKey('ocr-crop-lower'),
                label: const Text('Нижний диалог (Б)'),
                selected: _region == DialogueOcrRegion.lowerDialogue,
                onSelected: (_) => _choose(DialogueOcrRegion.lowerDialogue),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(
                  constraints.maxWidth,
                  constraints.maxWidth *
                      widget.preview.height / widget.preview.width,
                );
                return SizedBox(
                  width: size.width,
                  height: size.height,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.memory(
                          widget.preview.bytes,
                          key: const ValueKey('ocr-crop-page-preview'),
                          fit: BoxFit.fill,
                          gaplessPlayback: true,
                          errorBuilder: (_, _, _) => const Center(
                            child: Text('Не удалось показать страницу PDF'),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _CropShadePainter(_region),
                        ),
                      ),
                      Positioned.fill(
                        child: GestureDetector(
                          key: const ValueKey('ocr-crop-touch-area'),
                          behavior: HitTestBehavior.opaque,
                          onPanStart: (details) =>
                              _start(details.localPosition, size),
                          onPanUpdate: (details) =>
                              _move(details.localPosition, size),
                          onPanCancel: _finish,
                          onPanEnd: (_) => _finish(),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.crop_free_outlined,
                  size: 18, color: DesignTokens.olive),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _region.valid
                      ? 'Выбран только отмеченный фрагмент страницы.'
                      : 'Выделите область побольше.',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            key: const ValueKey('ocr-crop-confirm'),
            onPressed: _region.valid
                ? () => Navigator.of(context).pop(_region)
                : null,
            icon: const Icon(Icons.document_scanner_outlined),
            label: const Text('Распознать выделенный текст'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Результат будет черновиком для сверки огласовок '
            'и разбивки на реплики, а не проверенной цитатой автоматически.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

class _CropShadePainter extends CustomPainter {
  const _CropShadePainter(this.region);
  final DialogueOcrRegion region;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Rect.fromLTRB(
      region.left * size.width,
      region.top * size.height,
      region.right * size.width,
      region.bottom * size.height,
    );
    final fullPage = Path()..addRect(Offset.zero & size);
    final selection = Path()..addRect(bounds);
    canvas.drawPath(
      Path.combine(PathOperation.difference, fullPage, selection),
      Paint()..color = const Color(0x730F2019),
    );
    canvas.drawRect(
      bounds,
      Paint()
        ..color = const Color(0xFF557B46)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _CropShadePainter oldDelegate) =>
      oldDelegate.region != region;
}
