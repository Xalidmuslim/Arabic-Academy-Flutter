import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/speech.dart';
import '../../services/private_dialogue_store.dart';
import '../../ui/components.dart';
import '../../ui/fitted_study_artwork.dart';
import '../../ui/study_art_asset.dart';
import 'textbook_reader_screen.dart';
import 'original_pdf_zoom_image.dart';

/// Inline original scan preview for the lesson's primary Dialogue stage.
/// Shows only a fragment previously saved by this learner from their PDF.
class OriginalDialoguePdfPreview extends StatefulWidget {
  const OriginalDialoguePdfPreview({
    super.key,
    required this.lesson,
    this.store,
  });

  final Map<String, dynamic> lesson;
  final OriginalDialogueStore? store;

  @override
  State<OriginalDialoguePdfPreview> createState() =>
      _OriginalDialoguePdfPreviewState();
}

class _OriginalDialoguePdfPreviewState
    extends State<OriginalDialoguePdfPreview> {
  late final Future<Uint8List?> _preview;

  @override
  void initState() {
    super.initState();
    _preview = _load();
  }

  Future<Uint8List?> _load() async {
    final store = widget.store ?? const OnDeviceDialogueStore();
    if (store is! DialogueArtworkStore) return null;
    final part = widget.lesson['pdf_part'] == 2 ? 2 : 1;
    final id = widget.lesson['id'] as String?;
    if (id == null || !await store.hasImportedPdf(part)) return null;
    final saved = await store.load(part, id);
    if (saved?.crop == null) return null;
    try {
      return await (store as DialogueArtworkStore).renderCrop(
          part, saved!.pageIndex, saved.crop!);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _preview,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Диалог из оригинального PDF',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Container(
              key: const ValueKey('lesson-original-pdf-fragment'),
              height: 290,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFFFCF7D5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: InteractiveViewer(
                key: const ValueKey('lesson-original-pdf-zoom'),
                minScale: 1,
                maxScale: 6,
                boundaryMargin: const EdgeInsets.all(18),
                child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
              ),
            ),
            const SizedBox(height: 6),
            const Text('Оригинальное оформление и огласовки из '
                'вашего PDF. Увеличивайте двумя пальцами.',
                style: TextStyle(fontSize: 12)),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

class _OriginalDialogueDraft {
  const _OriginalDialogueDraft({
    required this.page,
    required this.text,
    required this.verified,
    required this.source,
    required this.crop,
    required this.originalPng,
    required this.editing,
    required this.editingCrop,
    required this.hadStoredText,
    this.message,
  });
  final int page;
  final String text;
  final bool verified;
  final String source;
  final DialogueCrop? crop;
  final Uint8List? originalPng;
  final bool editing;
  final bool editingCrop;
  final bool hadStoredText;
  final String? message;
}

/// A private companion to a reader-owned PDF. The bundled editorial dialog is
/// deliberately NOT used as the original or silently substituted for it.
class OriginalDialogueScreen extends StatefulWidget {
  const OriginalDialogueScreen({
    super.key,
    required this.lesson,
    this.store,
  });

  final Map<String, dynamic> lesson;
  final OriginalDialogueStore? store;

  @override
  State<OriginalDialogueScreen> createState() => _OriginalDialogueScreenState();
}

class _OriginalDialogueScreenState extends State<OriginalDialogueScreen> {
  late final OriginalDialogueStore _store;
  final TextEditingController _transcript = TextEditingController();
  late int _page;
  late final int _part;
  late final String _lessonId;
  late final int _defaultSlot;
  int _dialogueSlot = 1;
  final Map<int, _OriginalDialogueDraft> _drafts = {};
  bool _zoomLocked = false;

  String _recordId(int slot) {
    if (slot == _defaultSlot) return _lessonId;
    final safeBase = _lessonId.length > 60
        ? _lessonId.substring(0, 60)
        : _lessonId;
    return '${safeBase}_dialogue_$slot';
  }


  bool _busy = true;
  bool _bookReady = false;
  bool _editing = false;
  bool _verified = false;
  bool _hadStoredText = false;
  Uint8List? _originalPng;
  DialogueCrop? _crop;
  bool _editingCrop = false;
  String _source = 'manual';
  String? _message;
  String? _error;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? const OnDeviceDialogueStore();
    _part = widget.lesson['pdf_part'] == 2 ? 2 : 1;
    _page = widget.lesson['pdf_page'] is int
        ? (widget.lesson['pdf_page'] as int).clamp(0, 10000).toInt()
        : 22;
    _lessonId = (widget.lesson['id'] as String?) ?? 'unknown';
    _defaultSlot = widget.lesson['lesson_order'] == 2 ? 2 : 1;
    _dialogueSlot = _defaultSlot;
    unawaited(_loadLocal());
  }

  Future<void> _loadLocal() async {
    try {
      final hasBook = await _store.hasImportedPdf(_part);
      final saved = await _store.load(_part, _recordId(_dialogueSlot));
      Uint8List? preview;
      if (hasBook && saved?.crop != null && _store is DialogueArtworkStore) {
        try {
          preview = await (_store as DialogueArtworkStore)
              .renderCrop(_part, saved!.pageIndex, saved.crop!);
        } catch (_) {
          // A changed or damaged PDF must not suppress the saved transcription.
        }
      }
      if (!mounted) return;
      setState(() {
        _bookReady = hasBook;
        _hadStoredText = saved != null;
        _crop = saved?.crop;
        _originalPng = preview;
        if (saved != null) {
          _page = saved.pageIndex;
          _transcript.text = saved.text;
          _verified = saved.verified;
          _source = saved.source;
        }
        _busy = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Не удалось прочитать локальные данные: $e';
      });
    }
  }

  Future<void> _openPdf({bool choosePage = false}) async {
    final selected = await Navigator.of(context).push<int>(
      MaterialPageRoute<int>(
        builder: (_) => TextbookReaderScreen(
          part: _part,
          initialPage: _page,
          selectPageForDialogue: choosePage,
        ),
      ),
    );
    if (!mounted) return;
    final available = await _store.hasImportedPdf(_part);
    final storedAfter = await _store.load(_part, _recordId(_dialogueSlot));
    if (!mounted) return;
    setState(() {
      if (storedAfter == null) _drafts.clear();
      _bookReady = available;
      final wasReplaced = _hadStoredText && storedAfter == null;
      _hadStoredText = storedAfter != null;
      if (wasReplaced) {
        _crop = null;
        _originalPng = null;
        _editingCrop = false;
        _transcript.clear();
        _verified = false;
        _source = 'manual';
        _editing = false;
        _message = 'PDF заменён. Старые диалоги очищены, чтобы '
            'не выдавать их за текст новой книги.';
      }
      if (selected != null && selected != _page) {
        _page = selected;
        _crop = null;
        _originalPng = null;
        _editingCrop = false;
        _transcript.clear();
        _source = 'manual';
        _editing = false;
        _verified = false;
        if (!wasReplaced) {
          _message =
              'Страница изменена. Проверьте привязку текста и сохраните заново.';
        }
      }
    });
    // Once the learner confirms a page, find its dialogue without
    // requiring a manual crop or a second recognition button.
    if (available && selected != null) {
      unawaited(_extract());
    }
  }

  Future<void> _extract() async {
    if (_busy || !_bookReady) return;
    setState(() {
      _busy = true;
      _message = null;
      _error = null;
      _originalPng = null;
      _crop = null;
      _editingCrop = false;
    });
    try {
      // The native engine analyzes text-line positions, separates dialogues
      // from illustrations and instructions, then OCRs ONLY the chosen block.
      // The second conversation may share the earlier PDF page with the first.
      final slot = _dialogueSlot;
      final data = await _store.recognizeDialogue(_part, _page, slot);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _crop = data.crop;
        _originalPng = data.imagePng;
        if (data.crop != null) _page = data.pageIndex;
        if (data.status == 'ocr' && data.text.trim().isNotEmpty) {
          if (_page != data.pageIndex) {
            _page = data.pageIndex;
          }
          _transcript.text = data.text;
          _verified = false;
          _source = 'ocr_arabic';
          _editing = true;
          if (data.yellowDetected == true) {
            final incomplete = data.blueLines == 0 || data.orangeLines == 0;
            _message = 'Жёлтая область диалога выделена без фотографии. '
                'Синие реплики: ${data.blueLines}, '
                'оранжевые: ${data.orangeLines}. '
                '${incomplete ? "Один из цветов распознан не полностью. " : ""}'
                'Сверьте пропущенные слова и огласовки с оригинальным PDF.';
          } else if (data.yellowDetected == false) {
            _message = 'Граница жёлтого фона не определена надёжно. '
                'Обрезана только текстовая колонка, без изображения. '
                'Проверьте фрагмент и при необходимости измените границы. '
                'Огласовки требуют ручной сверки.';
          } else {
            _message = data.autoSelected
                ? 'Область диалога найдена автоматически '
                    '(блоков на странице: ${data.detectedBlocks}). '
                    'Сверьте текст и огласовки с PDF.'
                : 'Текст получен, но точность выделения не подтверждена. '
                    'Сверьте область и реплики по оригинальной странице.';
          }
        } else if (data.status == 'empty') {
          _message = data.crop != null
              ? 'Оригинальный фрагмент найден, но OCR не распознал реплики. '
                  'Проверьте границы и введите арабский текст вручную.'
              : 'Не удалось надёжно определить область диалога. '
              'Откройте страницу PDF, выберите правильную страницу '
              'и повторите автоматический поиск. '
              'Полный текст страницы подставляться не будет.';
        } else if (data.status == 'unsupported') {
          _message = 'Автоматическое распознавание доступно в Android-приложении.';
        } else {
          _bookReady = false;
          _message = 'Сначала импортируйте личный PDF учебника.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Ошибка распознавания области диалога: $e';
      });
    }
  }

  Future<void> _renderManualCrop() async {
    final crop = _crop;
    final store = _store;
    if (crop == null || !crop.isValid || store is! DialogueArtworkStore) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final image = await (store as DialogueArtworkStore).renderCrop(_part, _page, crop);
      if (!mounted) return;
      setState(() {
        _originalPng = image;
        _editingCrop = false;
        _verified = false;
        _busy = false;
        _message = 'Границы изменены. Сверьте картинку и огласовки, '
            'затем сохраните локально.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Не удалось обрезать PDF: $e';
      });
    }
  }

  Future<void> _save() async {
    if (_busy || !_bookReady) return;
    if (_editingCrop) {
      setState(() => _error = 'Примените границы обрезки перед сохранением.');
      return;
    }
    if (_transcript.text.trim().isEmpty &&
        (_crop == null || _originalPng == null)) {
      setState(() => _error = 'Добавьте фрагмент PDF или текст реплик.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _store.save(_part, _recordId(_dialogueSlot), SavedOriginalDialogue(
        pageIndex: _page,
        text: _transcript.text.trim(),
        verified: _verified,
        source: _source,
        crop: _crop,
      ));
      if (!mounted) return;
      setState(() {
        _busy = false;
        _editing = false;
        _hadStoredText = true;
        _drafts.remove(_dialogueSlot);
        _message = _crop == null
            ? 'Текст сохранён только на этом телефоне.'
            : 'Фрагмент PDF и текст сохранены только на этом телефоне.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Не удалось сохранить текст на телефоне: $e';
      });
    }
  }

  Future<void> _speak(String text) async {
    try {
      await ArabicSpeech.speak(text);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Озвучка сейчас недоступна.')),
      );
    }
  }

  @override
  void dispose() {
    _transcript.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final illustration = StudyArtAsset.valid(
      widget.lesson['dialogue_illustration_asset'],
    );
    final lines = _transcript.text.split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Оригинальный диалог'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 150),
        children: [
          if (illustration != null && _originalPng == null)
            Center(
              child: FittedStudyArtwork(
                image: AssetImage(illustration),
                size: 180,
                semanticLabel: 'Иллюстрация к диалогу',
              ),
            ),
          Text(
            'Диалог ${widget.lesson['lesson_order'] ?? 1}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Личная копия учебника · оригинал сверяется по вашему PDF',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 14),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Книга 1 · часть $_part',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 5),
                Text(
                  'Страница ${_page + 1} · '
                  '${_bookReady ? 'PDF загружен' : 'PDF не загружен'}',
                  key: const ValueKey('original-dialogue-source-page'),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Начальная страница указана ориентировочно. '
                  'Найдите настоящий диалог в книге и подтвердите страницу.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const ValueKey('original-dialogue-open-pdf'),
                  onPressed: _busy
                      ? null
                      : () => _openPdf(choosePage: true),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(_bookReady
                      ? 'Открыть PDF · выбрать страницу'
                      : 'Импортировать личный PDF'),
                ),
                if (_bookReady) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const ValueKey('original-dialogue-extract'),
                    onPressed: _busy ? null : _extract,
                    icon: const Icon(Icons.text_snippet_outlined),
                    label: const Text('Найти и распознать только диалог'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_busy) const Center(child: CircularProgressIndicator()),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_message!, key: const ValueKey('original-dialogue-notice')),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, key: const ValueKey('original-dialogue-error')),
            ),
          if (_bookReady && !_busy) ...[
            Row(
              children: [
                Expanded(
                  child: Text('Оригинальный фрагмент PDF',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                if (_store is DialogueArtworkStore)
                  TextButton(
                    key: const ValueKey('original-dialogue-crop-edit'),
                    onPressed: () => setState(() {
                      _crop ??= const DialogueCrop(0.40, 0.10, 0.96, 0.90);
                      _editingCrop = !_editingCrop;
                    }),
                    child: Text(_crop == null ? 'Выделить' : 'Границы'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_originalPng != null) ...[
              Container(
                key: const ValueKey('original-dialogue-pdf-fragment'),
                height: 300,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFFFCF7D5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: InteractiveViewer(
                  key: const ValueKey('original-dialogue-pdf-zoom'),
                  minScale: 1,
                  maxScale: 6,
                  boundaryMargin: const EdgeInsets.all(18),
                  child: Center(
                    child: Image.memory(_originalPng!,
                        fit: BoxFit.contain, gaplessPlayback: true),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text('Фрагмент из вашего PDF. Увеличивайте двумя '
                  'пальцами. Проверьте границы и огласовки.',
                  style: TextStyle(fontSize: 12)),
            ] else
              const Text('Нажмите «Найти и распознать только диалог» '
                  'для автоматической обрезки оригинальной страницы.',
                  style: TextStyle(fontSize: 12)),
            if (_editingCrop && _crop != null) ...[
              const SizedBox(height: 12),
              const Text('Границы по ширине страницы PDF'),
              RangeSlider(
                key: const ValueKey('original-dialogue-crop-horizontal'),
                values: RangeValues(_crop!.left, _crop!.right),
                min: 0,
                max: 1,
                onChanged: (value) {
                  if (value.end - value.start < 0.08) return;
                  setState(() {
                    _crop = DialogueCrop(value.start, _crop!.top,
                        value.end, _crop!.bottom);
                    _verified = false;
                  });
                },
              ),
              const Text('Границы по высоте страницы PDF'),
              RangeSlider(
                key: const ValueKey('original-dialogue-crop-vertical'),
                values: RangeValues(_crop!.top, _crop!.bottom),
                min: 0,
                max: 1,
                onChanged: (value) {
                  if (value.end - value.start < 0.06) return;
                  setState(() {
                    _crop = DialogueCrop(_crop!.left, value.start,
                        _crop!.right, value.end);
                    _verified = false;
                  });
                },
              ),
              FilledButton.icon(
                key: const ValueKey('original-dialogue-crop-apply'),
                onPressed: _renderManualCrop,
                icon: const Icon(Icons.crop),
                label: const Text('Применить обрезку'),
              ),
            ],
            if (_crop != null && _originalPng != null &&
                !_editing && !_editingCrop && _transcript.text.trim().isEmpty)
              TextButton.icon(
                key: const ValueKey('original-dialogue-save-image'),
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Сохранить фрагмент PDF'),
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text('Текст диалога',
                    style: Theme.of(context).textTheme.titleLarge),
                ),
                if (!_editing && _transcript.text.isNotEmpty)
                  IconButton(
                    key: const ValueKey('original-dialogue-edit'),
                    tooltip: 'Исправить текст',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => setState(() => _editing = true),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (_editing) ...[
              TextField(
                key: const ValueKey('original-dialogue-editor'),
                controller: _transcript,
                minLines: 7,
                maxLines: 16,
                maxLength: 100000,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  hintText: 'Только выделенный диалог. Сверьте арабские '
                      'слова и огласовки; каждая реплика — с новой строки.',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (_verified || _source != 'manual') {
                    setState(() {
                      _verified = false;
                      _source = 'manual';
                    });
                  }
                },
              ),
              SwitchListTile.adaptive(
                key: const ValueKey('original-dialogue-verified'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Сверено со страницей PDF'),
                subtitle: const Text(
                  'Отмечайте только после проверки огласовок и реплик.',
                ),
                value: _verified,
                onChanged: (value) => setState(() => _verified = value),
              ),
              FilledButton.icon(
                key: const ValueKey('original-dialogue-save'),
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Сохранить на устройстве'),
              ),
            ] else if (lines.isNotEmpty) ...[
              Text(
                _verified
                    ? 'Проверено вами по PDF · локальная запись'
                    : 'Не проверено: сверьте с оригинальной страницей',
                style: const TextStyle(fontSize: 12),
                key: const ValueKey('original-dialogue-verification-state'),
              ),
              const SizedBox(height: 8),
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Panel(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconButton(
                          tooltip: 'Озвучить: синтез речи',
                          icon: const Icon(Icons.volume_up_outlined),
                          onPressed: () => _speak(line),
                        ),
                        Expanded(child: NaskhText(line, size: 25)),
                      ],
                    ),
                  ),
                ),
            ] else ...[
              const Text(
                'Оригинальный текст не подменяется авторским. '
                'Нажмите «Найти и распознать только диалог». '
                'Приложение само определит границы текста, '
                'исключая заголовки и фотографии.',
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: const ValueKey('original-dialogue-type'),
                onPressed: () => setState(() {
                  _editing = true;
                  _source = 'manual';
                  _verified = false;
                }),
                icon: const Icon(Icons.edit_note_outlined),
                label: const Text('Ввести текст вручную'),
              ),
            ],
          ],
          const SizedBox(height: 14),
          const Text(
            'PDF и введённые реплики хранятся только на устройстве. '
            'Материалы не включаются в APK и не отправляются в школьный сервис.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
