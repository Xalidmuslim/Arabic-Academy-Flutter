import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../services/private_dialogue_store.dart';
import '../../ui/components.dart';
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
              child: OriginalPdfZoomImage(
                image: bytes,
                viewerKey: const ValueKey('lesson-original-pdf-zoom'),
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

class _VisualDialogueDraft {
  const _VisualDialogueDraft(this.page, this.crop, this.image, this.message);
  final int page;
  final DialogueCrop? crop;
  final Uint8List? image;
  final String? message;
}

/// Shows the exact source pixels of one of the two dialogue panels.
/// There is deliberately no OCR text field, transcription or TTS.
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
  late final int _part;
  late final String _lessonId;
  late final int _defaultSlot;
  late int _page;
  late int _slot;
  bool _busy = true;
  bool _bookReady = false;
  bool _editingCrop = false;
  bool _zoomLocked = false;
  DialogueCrop? _crop;
  Uint8List? _image;
  String? _message;
  String? _error;
  final Map<int, _VisualDialogueDraft> _drafts = {};

  String _recordId(int slot) {
    if (slot == _defaultSlot) return _lessonId;
    final base = _lessonId.length > 60
        ? _lessonId.substring(0, 60)
        : _lessonId;
    return '${base}_dialogue_$slot';
  }

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
    _slot = _defaultSlot;
    unawaited(_loadInitial());
  }

  Future<Uint8List?> _renderSaved(SavedOriginalDialogue? saved) async {
    if (saved?.crop == null || _store is! DialogueArtworkStore) return null;
    try {
      return await (_store as DialogueArtworkStore)
          .renderCrop(_part, saved!.pageIndex, saved.crop!);
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadInitial() async {
    try {
      final ready = await _store.hasImportedPdf(_part);
      final saved = ready ? await _store.load(_part, _recordId(_slot)) : null;
      final image = ready ? await _renderSaved(saved) : null;
      if (!mounted) return;
      setState(() {
        _bookReady = ready;
        _page = saved?.pageIndex ?? _page;
        _crop = saved?.crop;
        _image = image;
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Не удалось открыть личный PDF: $error';
      });
    }
  }

  Future<void> _switchDialogue(int next) async {
    if (_busy || next == _slot || next < 1 || next > 2) return;
    _drafts[_slot] = _VisualDialogueDraft(_page, _crop, _image, _message);
    setState(() {
      _busy = true;
      _zoomLocked = false;
      _error = null;
    });
    try {
      final draft = _drafts[next];
      final saved = draft == null
          ? await _store.load(_part, _recordId(next))
          : null;
      final preview = draft?.image ?? await _renderSaved(saved);
      if (!mounted) return;
      setState(() {
        _slot = next;
        _page = draft?.page ?? saved?.pageIndex ?? _page;
        _crop = draft?.crop ?? saved?.crop;
        _image = preview;
        _editingCrop = false;
        _busy = false;
        _message = draft?.message ??
            (preview == null ? 'Выбран диалог ${next == 1 ? "А" : "Б"}.'
                : 'Загружен сохранённый фрагмент PDF.');
      });
      if (preview == null && _bookReady) await _findOriginal();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Не удалось открыть второй диалог: $error';
      });
    }
  }

  Future<void> _openPdf() async {
    final selected = await Navigator.of(context).push<int>(
      MaterialPageRoute<int>(
        builder: (_) => TextbookReaderScreen(
          part: _part,
          initialPage: _page,
          selectPageForDialogue: true,
        ),
      ),
    );
    if (!mounted) return;
    final available = await _store.hasImportedPdf(_part);
    if (!mounted) return;
    setState(() {
      _bookReady = available;
      if (selected != null && selected != _page) {
        _page = selected;
        _crop = null;
        _image = null;
        _editingCrop = false;
        _drafts.clear();
      }
    });
    if (available && selected != null) await _findOriginal();
  }

  Future<void> _findOriginal() async {
    if (_busy || !_bookReady) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
      _editingCrop = false;
      _zoomLocked = false;
    });
    try {
      // Native Android scans only the background geometry and returns PNG.
      // No Arabic OCR, synthetic vocalization or handwritten transcript.
      final result = await _store.recognizeDialogue(_part, _page, _slot);
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (result.crop != null && result.imagePng != null &&
            result.imagePng!.isNotEmpty) {
          _crop = result.crop;
          _image = result.imagePng;
          _page = result.pageIndex;
          _message = 'Выделен оригинальный диалог ${_slot == 1 ? "А" : "Б"}. '
              'Изображение и огласовки сохранены без изменений. '
              'Проверьте границы перед сохранением.';
        } else {
          _crop = null;
          _image = null;
          _message = 'Жёлтая область этого диалога не определена. '
              'Выберите страницу PDF и повторите поиск либо '
              'отметьте границы вручную.';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Ошибка поиска оригинального диалога: $error';
      });
    }
  }

  Future<void> _applyCrop() async {
    final crop = _crop;
    if (_busy || !_bookReady || crop == null || !crop.isValid ||
        _store is! DialogueArtworkStore) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final png = await (_store as DialogueArtworkStore)
          .renderCrop(_part, _page, crop);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _image = png;
        _editingCrop = false;
        _message = 'Границы применены. Проверьте фрагмент PDF.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Не удалось применить границы: $error';
      });
    }
  }

  Future<void> _save() async {
    if (_busy || !_bookReady) return;
    if (_editingCrop) {
      setState(() => _error = 'Сначала примените новые границы.');
      return;
    }
    if (_crop == null || !_crop!.isValid || _image == null) {
      setState(() => _error = 'Сначала найдите или выделите фрагмент PDF.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _store.save(
        _part, _recordId(_slot),
        SavedOriginalDialogue(
          pageIndex: _page,
          text: '', // No guesswork: only a visual PDF crop is saved.
          verified: false,
          source: 'manual',
          crop: _crop,
        ),
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _drafts.remove(_slot);
        _message = 'Оригинальный фрагмент PDF сохранён на этом устройстве.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Не удалось сохранить оригинал PDF: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Оригинальный диалог')),
      body: ListView(
        physics: _zoomLocked
            ? const NeverScrollableScrollPhysics()
            : const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 150),
        children: [
          Text('Диалог ${_slot == 1 ? "А (أ)" : "Б (ب)"}',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 7),
          const Text(
            'Только изображение оригинального учебника — '
            'без распознавания и изменения арабского текста.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 14),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Книга 1 · часть $_part',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                const Text('Выберите диалог на странице',
                    style: TextStyle(fontSize: 13)),
                const SizedBox(height: 7),
                SegmentedButton<int>(
                  key: const ValueKey('original-dialogue-selector'),
                  segments: const [
                    ButtonSegment<int>(
                        value: 1, label: Text('Диалог А (أ)')),
                    ButtonSegment<int>(
                        value: 2, label: Text('Диалог Б (ب)')),
                  ],
                  selected: {_slot},
                  showSelectedIcon: false,
                  onSelectionChanged: _busy
                      ? null
                      : (values) => _switchDialogue(values.first),
                ),
                const SizedBox(height: 12),
                Text('Страница ${_page + 1} · '
                    '${_bookReady ? "PDF загружен" : "PDF не загружен"}',
                    key: const ValueKey('original-dialogue-source-page')),
                const SizedBox(height: 12),
                if (_image == null) ...[
                  const Text(
                    'Найдите страницу с диалогом в личном PDF. '
                    'Приложение выделит жёлтую область без фотографии.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    key: const ValueKey('original-dialogue-open-pdf'),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    onPressed: _busy ? null : _openPdf,
                    label: Text(_bookReady
                        ? 'Открыть PDF · выбрать страницу'
                        : 'Импортировать личный PDF'),
                  ),
                  if (_bookReady) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const ValueKey('original-dialogue-extract'),
                      onPressed: _busy ? null : _findOriginal,
                      icon: const Icon(Icons.crop_free),
                      label: const Text('Найти оригинальный диалог'),
                    ),
                  ],
                ] else if (_bookReady)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const ValueKey('original-dialogue-open-pdf'),
                          onPressed: _busy ? null : _openPdf,
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: const Text('Страница PDF'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const ValueKey('original-dialogue-extract'),
                          onPressed: _busy ? null : _findOriginal,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Найти снова'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_busy) const Center(child: CircularProgressIndicator()),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_message!,
                  key: const ValueKey('original-dialogue-notice')),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!,
                  key: const ValueKey('original-dialogue-error')),
            ),
          if (_bookReady && !_busy) ...[
            Row(
              children: [
                Expanded(
                  child: Text('Фрагмент оригинального PDF',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                if (_store is DialogueArtworkStore)
                  TextButton(
                    key: const ValueKey('original-dialogue-crop-edit'),
                    onPressed: () => setState(() {
                      _crop ??= const DialogueCrop(0.50, 0.20, 0.96, 0.82);
                      _editingCrop = !_editingCrop;
                    }),
                    child: Text(_image == null ? 'Выделить' : 'Границы'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_image != null) ...[
              Container(
                key: const ValueKey('original-dialogue-pdf-fragment'),
                height: 370,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFFFCF7D5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: OriginalPdfZoomImage(
                  image: _image!,
                  viewerKey: const ValueKey('original-dialogue-pdf-zoom'),
                  onScrollLockChanged: (locked) {
                    if (mounted && _zoomLocked != locked) {
                      setState(() => _zoomLocked = locked);
                    }
                  },
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Масштабируйте двумя пальцами или кнопками. '
                'Все огласовки — из оригинального PDF.',
                style: TextStyle(fontSize: 12),
              ),
            ] else
              const Text(
                'Выберите страницу и нажмите «Найти оригинальный диалог». '
                'Если фон не распознан, задайте границы вручную.',
                style: TextStyle(fontSize: 12),
              ),
            if (_editingCrop && _crop != null) ...[
              const SizedBox(height: 12),
              const Text('Границы по ширине страницы'),
              RangeSlider(
                key: const ValueKey('original-dialogue-crop-horizontal'),
                values: RangeValues(_crop!.left, _crop!.right),
                min: 0, max: 1,
                onChanged: (value) {
                  if (value.end - value.start < .08) return;
                  setState(() {
                    _crop = DialogueCrop(value.start, _crop!.top,
                        value.end, _crop!.bottom);
                  });
                },
              ),
              const Text('Границы по высоте страницы'),
              RangeSlider(
                key: const ValueKey('original-dialogue-crop-vertical'),
                values: RangeValues(_crop!.top, _crop!.bottom),
                min: 0, max: 1,
                onChanged: (value) {
                  if (value.end - value.start < .06) return;
                  setState(() {
                    _crop = DialogueCrop(_crop!.left, value.start,
                        _crop!.right, value.end);
                  });
                },
              ),
              FilledButton.icon(
                key: const ValueKey('original-dialogue-crop-apply'),
                icon: const Icon(Icons.crop),
                onPressed: _applyCrop,
                label: const Text('Применить границы'),
              ),
            ],
            if (_image != null && !_editingCrop && _crop != null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const ValueKey('original-dialogue-save'),
                icon: const Icon(Icons.save_outlined),
                onPressed: _save,
                label: const Text('Сохранить оригинальный фрагмент'),
              ),
            ],
          ],
          const SizedBox(height: 18),
          const Text(
            'Ваш учебник и фрагменты хранятся только на устройстве. '
            'Никакого OCR-текста, исправлений или искусственных огласовок.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
