import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// The scanned book is NEVER checked into the public repository or bundled
/// into the distributed APK. The reader opens a private copy the user picks
/// on their own device, preserving the book's images and Arabic diacritics.
class TextbookReaderScreen extends StatefulWidget {
  const TextbookReaderScreen({super.key, this.initialPage = 22});

  /// Zero-based starting page for the provided student book, part 1.
  final int initialPage;

  @override
  State<TextbookReaderScreen> createState() => _TextbookReaderScreenState();
}

class _TextbookReaderScreenState extends State<TextbookReaderScreen> {
  static const _native = MethodChannel('bayna.private_pdf');
  static const _fileName = 'student_book_1_part_1.pdf';
  static const _chapters = <(String, int)>[
    ('1 · Приветствие и знакомство', 22),
    ('2 · Семья', 48),
    ('3 · Жильё', 74),
    ('4 · Повседневная жизнь', 102),
    ('5 · Еда и напитки', 129),
    ('6 · Молитва', 156),
    ('7 · Учёба', 182),
    ('8 · Работа', 210),
  ];

  late final PageController _controller;
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
    _controller = PageController(initialPage: _page);
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
        if (mounted) setState(() => _busy = false);
        return;
      }
      await _openFile(file);
    } catch (error) {
      if (mounted) setState(() {
        _busy = false;
        _error = 'Не удалось открыть учебник: $error';
      });
    }
  }

  Future<void> _openFile(File file) async {
    final count = await _native.invokeMethod<int>('open', {
      'path': file.path,
    });
    if (count == null || count < 1) {
      throw const FormatException('PDF не содержит страниц');
    }
    if (!mounted) return;
    _pageCache.clear();
    setState(() {
      _hasBook = true;
      _busy = false;
      _error = null;
      _pageCount = count;
      _page = widget.initialPage.clamp(0, count - 1);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller.hasClients) _controller.jumpToPage(_page);
    });
  }

  Future<void> _importFile() async {
    if (_busy) return;
    final selected = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: false,
    );
    if (selected == null || selected.files.isEmpty) return;
    final path = selected.files.single.path;
    if (path == null) {
      if (mounted) setState(() => _error = 'Не удалось получить файл PDF.');
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
      if (await temporary.exists()) await temporary.delete();
      await source.copy(temporary.path);
      // Close any currently displayed PDF before swapping the file on disk.
      await _native.invokeMethod<void>('close');
      if (await target.exists()) await target.delete();
      await temporary.rename(target.path);
      await _openFile(target);
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

  void _onPageChanged(int page) {
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
            const ListTile(
              title: Text('Книга 1 · Часть 1'),
              subtitle: Text('Переход к началу раздела по печатному оглавлению'),
            ),
            for (final chapter in _chapters)
              ListTile(
                title: Text(chapter.$1),
                subtitle: Text('Страница PDF ${chapter.$2 + 1}'),
                enabled: chapter.$2 < _pageCount,
                onTap: () {
                  Navigator.pop(context);
                  _controller.jumpToPage(chapter.$2);
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
    _controller.dispose();
    // Native PDF resources are released on reader dismissal.
    _native.invokeMethod<void>('close');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Учебник · Часть 1'),
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
                      const Text('Выберите «Аль-Арабия байна ядайк», '
                          'Книга студента 1, часть 1 — 282 страницы.'),
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
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: _pageCount,
                      onPageChanged: _onPageChanged,
                      itemBuilder: (context, index) => FutureBuilder<Uint8List>(
                        future: _render(index),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(child: Text('Ошибка страницы: ${snapshot.error}'));
                          }
                          if (!snapshot.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          return InteractiveViewer(
                            minScale: 1,
                            maxScale: 4,
                            child: Center(
                              child: Image.memory(
                                snapshot.data!,
                                fit: BoxFit.contain,
                                gaplessPlayback: true,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Предыдущая страница',
                            onPressed: _page > 0
                                ? () => _controller.previousPage(
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOut,
                                  )
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
                                ? () => _controller.nextPage(
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOut,
                                  )
                                : null,
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
  );
}
