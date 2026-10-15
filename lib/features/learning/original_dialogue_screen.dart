import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/speech.dart';
import '../../services/private_dialogue_store.dart';
import '../../ui/components.dart';
import '../../ui/fitted_study_artwork.dart';
import '../../ui/study_art_asset.dart';
import 'textbook_reader_screen.dart';

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

  bool _busy = true;
  bool _bookReady = false;
  bool _editing = false;
  bool _verified = false;
  bool _hadStoredText = false;
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
    unawaited(_loadLocal());
  }

  Future<void> _loadLocal() async {
    try {
      final hasBook = await _store.hasImportedPdf(_part);
      final saved = await _store.load(_part, _lessonId);
      if (!mounted) return;
      setState(() {
        _bookReady = hasBook;
        _hadStoredText = saved != null;
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
    final storedAfter = await _store.load(_part, _lessonId);
    if (!mounted) return;
    setState(() {
      _bookReady = available;
      final wasReplaced = _hadStoredText && storedAfter == null;
      _hadStoredText = storedAfter != null;
      if (wasReplaced) {
        _transcript.clear();
        _verified = false;
        _source = 'manual';
        _editing = false;
        _message = 'PDF заменён. Старые диалоги очищены, чтобы '
            'не выдавать их за текст новой книги.';
      }
      if (selected != null && selected != _page) {
        _page = selected;
        _verified = false;
        if (!wasReplaced) {
          _message =
              'Страница изменена. Проверьте привязку текста и сохраните заново.';
        }
      }
    });
  }

  Future<void> _extract({bool forceOcr = false}) async {
    if (_busy || !_bookReady) return;
    setState(() {
      _busy = true;
      _message = null;
      _error = null;
    });
    try {
      // On Android 15+ searchable pages can be read directly; image-only
      // scans, older Android versions and non-Arabic text layers use local OCR.
      final embedded = forceOcr
          ? const PdfTextExtraction('empty', '')
          : await _store.extractText(_part, _page);
      final hasArabic = RegExp(r'[\u0600-\u06ff]')
          .hasMatch(embedded.text);
      final data = embedded.status == 'ok' && hasArabic && !forceOcr
          ? embedded
          : embedded.status == 'missing'
              ? embedded
              : await _store.recognizeScan(_part, _page);
      if (!mounted) return;
      setState(() {
        _busy = false;
        if ((data.status == 'ok' || data.status == 'ocr') &&
            data.text.trim().isNotEmpty) {
          _transcript.text = data.text;
          _verified = false;
          _source = data.status == 'ocr' ? 'ocr_arabic' : 'pdf_text';
          _editing = true;
          _message = data.status == 'ocr'
              ? 'Арабский текст распознан со скана на этом телефоне. '
                  'OCR может ошибаться в огласовках, именах и порядке реплик. '
                  'Удалите посторонние строки и обязательно сверьте с PDF.'
              : 'Текстовый слой найден. Удалите лишние строки и '
                  'сверьте арабский текст с оригинальной страницей.';
        } else if (data.status == 'empty') {
          _message = 'OCR не смог прочитать эту страницу. Попробуйте '
              'соседнюю страницу или используйте ручное исправление.';
          _editing = true;
        } else if (data.status == 'unsupported') {
          _message = 'Распознавание недоступно на устройстве. '
              'Вы можете внести текст по личному PDF вручную.';
          _editing = true;
        } else {
          _bookReady = false;
          _message = 'Сначала импортируйте личный PDF учебника.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Ошибка распознавания страницы: $e';
      });
    }
  }

  Future<void> _save() async {
    if (_busy || !_bookReady) return;
    if (_transcript.text.trim().isEmpty) {
      setState(() => _error = 'Введите текст реплик перед сохранением.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _store.save(_part, _lessonId, SavedOriginalDialogue(
        pageIndex: _page,
        text: _transcript.text.trim(),
        verified: _verified,
        source: _source,
      ));
      if (!mounted) return;
      setState(() {
        _busy = false;
        _editing = false;
        _hadStoredText = true;
        _message = 'Текст сохранён только в памяти этого телефона.';
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
          if (illustration != null)
            Center(
              child: FittedStudyArtwork(
                image: AssetImage(illustration),
                size: 180,
                semanticLabel: 'Иллюстрация к диалогу',
              ),
            ),
          Text(
            widget.lesson['title']?.toString() ?? 'Диалог',
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
                    label: const Text('Распознать арабский текст страницы'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const ValueKey('original-dialogue-force-ocr'),
                    onPressed: _busy ? null : () => _extract(forceOcr: true),
                    icon: const Icon(Icons.document_scanner_outlined),
                    label: const Text('Повторно распознать изображение (OCR)'),
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
                  hintText: 'Распознанные реплики · исправьте ошибки по PDF. '
                      'Каждую реплику разместите с новой строки.',
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
                'Нажмите «Распознать арабский текст страницы». '
                'Система прочитает даже скан без текстового слоя.',
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
