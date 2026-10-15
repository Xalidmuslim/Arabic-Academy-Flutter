import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../services/private_dialogue_store.dart';

/// The scanned book is NEVER checked into the public repository or bundled
/// into the distributed APK. The reader opens a private copy the user picks
/// on their own device, preserving the book's images and Arabic diacritics.
class TextbookReaderScreen extends StatefulWidget {
  const TextbookReaderScreen({
    super.key,
    this.initialPage = 22,
    this.part = 1,
    this.selectPageForDialogue = false,
  })
      : assert(part == 1 || part == 2);

  /// Zero-based starting page within the selected privately imported file.
  final int initialPage;
  final int part;
  /// When true, the user can choose the verified page for one dialogue.
  final bool selectPageForDialogue;

  @override
  State<TextbookReaderScreen> createState() => _TextbookReaderScreenState();
}

class _TextbookReaderScreenState extends State<TextbookReaderScreen> {
  static const _native = MethodChannel('bayna.private_pdf');
  String get _fileName => 'student_book_1_part_${widget.part}.pdf';
  List<(String, int)> get _chapters => widget.part == 1 ? _chaptersPart1 : _chaptersPart2;
  static const _chaptersPart1 = <(String, int)>[
    ('1 · Приветствие и знакомство', 22),
    ('2 · Семья', 48),
    ('3 · Жильё', 76),
    ('4 · Повседневная жизнь', 102),
    ('5 · Еда и напитки', 130),
    ('6 · Молитва', 156),
    ('7 · Учёба', 184),
    ('8 · Работа', 210),
  ];
  static const _chaptersPart2 = <(String, int)>[
    ('9 · Покупки', 22),
    ('10 · Погода', 48),
    ('11 · Люди и места', 76),
    ('12 · Увлечения', 102),
    ('13 · Путешествие', 130),
    ('14 · Хадж и умра', 156),
    ('15 · Здоровье', 184),
    ('16 · Каникулы и отдых', 210),
  ];

  final TransformationController _zoom = TransformationController();
  final Set<int> _pointers = <int>{};
  Offset? _swipeStart;
  bool _multitouch = false;
  double _scale = 1;
  bool _fitWidth = false;
  Size _viewportSize = Size.zero;
  final Map<int, Future<Uint8List>> _pageCache = {};
  int _page = 0;
  int _pageCount = 0;
  bool _busy = true;
  String? _error;
  bool _hasBook = false;

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage;
    _zoom.addListener(_onZoomChanged);
    _openSaved();
  }

  Future<File> _targetFile() async {
    final directory = Directory(
      '${(await getApplicationSupportDirectory()).path}/private_textbooks',
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return File('${directory.path}/$_fileName');
  }

  Future<void> _openSaved() async {
    if (!Platform.isAndroid) {
      setState(() {
        _busy = false;
        _error = 'Просмотр сканированных страниц доступен на Android.';
      });
      return;
    }
    try {
      final file = await _targetFile();
      if (!await file.exists()) {
        if (mounted) {
          setState(() => _busy = false);
        }
        return;
      }
      await _openFile(file);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Не удалось открыть учебник: $error';
        });
      }
    }
  }

  Future<void> _openFile(File file) async {
    final count = await _native.invokeMethod<int>('open', {
      'path': file.path,
    });
    if (count == null || count < 1) {
      throw const FormatException('PDF не содержит страниц');
    }
    if (!mounted) {
      return;
    }
    _pageCache.clear();
    setState(() {
      _hasBook = true;
      _busy = false;
      _error = null;
      _pageCount = count;
      _page = widget.initialPage.clamp(0, count - 1).toInt();
    });
    _zoom.value = Matrix4.identity();
  }

  Future<void> _importFile() async {
    if (_busy) {
      return;
    }
    final selected = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: false,
    );
    if (selected == null || selected.files.isEmpty) {
      return;
    }
    final path = selected.files.single.path;
    if (path == null) {
      if (mounted) {
        setState(() => _error = 'Не удалось получить файл PDF.');
      }
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final source = File(path);
      final size = await source.length();
      if (size < 5 || size > 400 * 1024 * 1024) {
        throw const FormatException('Неверный размер PDF (не более 400 МБ).');
      }
      final handle = await source.open();
      try {
        final signature = await handle.read(5);
        if (String.fromCharCodes(signature) != '%PDF-') {
          throw const FormatException('Выбранный файл не является PDF.');
        }
      } finally {
        await handle.close();
      }
      // Stage the copy in the same private directory, then rename atomically.
      final target = await _targetFile();
      final temporary = File('${target.path}.importing');
      if (await temporary.exists()) {
        await temporary.delete();
      }
      await source.copy(temporary.path);
      // Close any currently displayed PDF before swapping the file on disk.
      await _native.invokeMethod<void>('close');
      if (await target.exists()) {
        await target.delete();
      }
      await temporary.rename(target.path);
      await _openFile(target);
      // Replacing the source book must invalidate saved transcriptions so
      // old quotations cannot accidentally be assigned to a new PDF.
      await const OnDeviceDialogueStore().clearPart(widget.part);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Ошибка импорта: $error';
        });
      }
    }
  }

  Future<Uint8List> _render(int page) =>
      _pageCache.putIfAbsent(page, () async {
        final data = await _native.invokeMethod<Uint8List>('render', {
          'page': page,
          'width': 1150,
        });
        if (data == null || data.isEmpty) {
          throw const FormatException('Не удалось отрисовать страницу');
        }
        return data;
      });

  // Passive observation of swipes keeps Android system Back and pinch intact.
  void _pointerDown(PointerDownEvent e) {
    if (_pointers.isEmpty) {
      _swipeStart = e.localPosition;
      _multitouch = false;
    } else {
      _multitouch = true;
    }
    _pointers.add(e.pointer);
  }

  void _pointerUp(PointerUpEvent e) {
    final start = _swipeStart;
    final single = _pointers.length == 1 &&
        _pointers.contains(e.pointer) && !_multitouch;
    _pointers.remove(e.pointer);
    if (_pointers.isEmpty) {
      _swipeStart = null;
    }
    if (!single || start == null || _scale > 1.03) {
      return;
    }
    if (start.dx < 36 || start.dx > _viewportSize.width - 36) {
      return;
    }
    final movement = e.localPosition - start;
    if (movement.dx.abs() < 85 ||
        movement.dx.abs() < movement.dy.abs() * 1.4) {
      return;
    }
    _goToPage(_page + (movement.dx < 0 ? 1 : -1));
  }

  void _pointerCancel(PointerCancelEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.isEmpty) {
      _swipeStart = null;
    }
  }

  void _onZoomChanged() {
    final next = _zoom.value.getMaxScaleOnAxis();
    if ((next - _scale).abs() > 0.02 && mounted) {
      setState(() => _scale = next);
    }
  }

  void _setZoom(double scale) {
    final next = scale.clamp(1.0, 5.0).toDouble();
    final width = _viewportSize.width;
    final height = _viewportSize.height;
    final matrix = Matrix4.identity()
      ..setEntry(0, 0, next)
      ..setEntry(1, 1, next)
      ..setEntry(0, 3, width * (1 - next) / 2)
      ..setEntry(1, 3, height * (1 - next) / 2);
    _zoom.value = matrix;
  }

  void _goToPage(int page) {
    if (page < 0 || page >= _pageCount || page == _page) return;
    _zoom.value = Matrix4.identity();
    setState(() => _page = page);
    _pageCache.removeWhere((key, _) => (key - page).abs() > 2);
  }

  void _showChapters() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text('Книга 1 · Часть ${widget.part}'),
              subtitle: const Text('Переход к началу раздела по печатному оглавлению'),
            ),
            for (final chapter in _chapters)
              ListTile(
                title: Text(chapter.$1),
                subtitle: Text('Страница PDF ${chapter.$2 + 1}'),
                enabled: chapter.$2 < _pageCount,
                onTap: () {
                  Navigator.pop(context);
                  _goToPage(chapter.$2);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageCache.clear();
    _zoom.removeListener(_onZoomChanged);
    _zoom.dispose();
    // Native PDF resources are released on reader dismissal.
    _native.invokeMethod<void>('close');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('Учебник · Часть ${widget.part}'),
      actions: [
        if (_hasBook)
          IconButton(
            tooltip: 'Разделы книги',
            onPressed: _showChapters,
            icon: const Icon(Icons.list_alt_outlined),
          ),
        IconButton(
          tooltip: _hasBook ? 'Заменить локальный PDF' : 'Импортировать PDF',
          onPressed: _busy ? null : _importFile,
          icon: const Icon(Icons.file_open_outlined),
        ),
      ],
    ),
    body: _busy
        ? const Center(child: CircularProgressIndicator())
        : !_hasBook
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.menu_book_outlined, size: 52),
                      const SizedBox(height: 14),
                      const Text('Оригинальный учебник хранится только на устройстве.'),
                      const SizedBox(height: 8),
                      Text(widget.part == 1
                          ? 'Выберите «Аль-Арабия байна ядайк», Книга студента 1, часть 1 — 282 страницы.'
                          : 'Выберите «Аль-Арабия байна ядайк», Книга студента 1, часть 2 — 284 страницы.'),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                      ],
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _importFile,
                        icon: const Icon(Icons.file_open),
                        label: const Text('Выбрать PDF с телефона'),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        _viewportSize = constraints.biggest;
                        return FutureBuilder<Uint8List>(
                          key: ValueKey('pdf-page-$_page'),
                          future: _render(_page),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Center(child: Text('Ошибка страницы: ${snapshot.error}'));
                            }
                            if (!snapshot.hasData) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            return Listener(
                              onPointerDown: _pointerDown,
                              onPointerUp: _pointerUp,
                              onPointerCancel: _pointerCancel,
                              child: PdfPageImage(
                                bytes: snapshot.data!,
                                controller: _zoom,
                                fitWidth: _fitWidth,
                                viewport: constraints.biggest,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                key: const ValueKey('pdf-zoom-out'),
                                tooltip: 'Уменьшить масштаб',
                                onPressed: _scale <= 1.01 ? null : () => _setZoom(_scale / 1.5),
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              Text('${_scale.toStringAsFixed(1)}×'),
                              IconButton(
                                key: const ValueKey('pdf-zoom-in'),
                                tooltip: 'Увеличить масштаб',
                                onPressed: _scale >= 4.99 ? null : () => _setZoom(_scale * 1.5),
                                icon: const Icon(Icons.add_circle_outline),
                              ),
                              TextButton(
                                key: const ValueKey('pdf-fit-width'),
                                onPressed: () {
                                  _zoom.value = Matrix4.identity();
                                  setState(() => _fitWidth = !_fitWidth);
                                },
                                child: Text(_fitWidth ? 'Вся страница' : 'По ширине'),
                              ),
                              IconButton(
                                tooltip: 'Сбросить масштаб',
                                onPressed: () => _setZoom(1),
                                icon: const Icon(Icons.center_focus_strong_outlined),
                              ),
                            ],
                          ),
                          Row(
                        children: [
                          IconButton(
                            tooltip: 'Предыдущая страница',
                            onPressed: _page > 0
                                ? () => _goToPage(_page - 1)
                                : null,
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Expanded(
                            child: Text(
                              'Страница ${_page + 1} из $_pageCount',
                              textAlign: TextAlign.center,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Следующая страница',
                            onPressed: _page + 1 < _pageCount
                                ? () => _goToPage(_page + 1)
                                : null,
                            icon: const Icon(Icons.chevron_right),
                          ),
                          ],
                          ),
                          if (widget.selectPageForDialogue)
                            Padding(
                              padding: const EdgeInsets.only(top: 5, bottom: 7),
                              child: FilledButton.icon(
                                key: const ValueKey('choose-original-dialogue-page'),
                                onPressed: () => Navigator.of(context).pop(_page),
                                icon: const Icon(Icons.check),
                                label: Text('Выбрать страницу ${_page + 1} для диалога'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
  );
}


/// Standalone pinch/pan surface. Its parent detects page swipes at 1x.
class PdfPageImage extends StatelessWidget {
  const PdfPageImage({
    super.key,
    required this.bytes,
    required this.controller,
    required this.fitWidth,
    required this.viewport,
  });
  final Uint8List bytes;
  final TransformationController controller;
  final bool fitWidth;
  final Size viewport;

  @override
  Widget build(BuildContext context) => InteractiveViewer(
    key: const ValueKey('pdf-interactive-viewer'),
    transformationController: controller,
    constrained: false,
    boundaryMargin: const EdgeInsets.all(24),
    minScale: 1,
    maxScale: 5,
    panEnabled: true,
    scaleEnabled: true,
    trackpadScrollCausesScale: true,
    child: fitWidth
        ? Image.memory(
            bytes,
            width: viewport.width,
            fit: BoxFit.fitWidth,
            gaplessPlayback: true,
          )
        : SizedBox(
            width: viewport.width,
            height: viewport.height,
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
          ),
  );
}
