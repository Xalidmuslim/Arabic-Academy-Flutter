import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/dictionary_data.dart';
import 'frame_performance_monitor.dart';
import 'startup_diagnostics.dart';

const emerald = Color(0xFF25776D);
const mint = Color(0xFF82CABB);
const stone = Color(0xFFF4F4F0);
const charcoal = Color(0xFF15201E);
const muted = Color(0xFF758681);

enum DictionaryRenderMode { regular, plain, noVowels }

/// Diagnostic *display only*. The stored word, references and reader stay
/// fully vocalized; no spelling normalization or edits to corpus are applied.
String withoutArabicVowels(String arabic) => arabic.replaceAll(
    RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED]'), '');


ThemeData dictionaryTheme(bool dark) {
  final surface = dark ? const Color(0xFF202E2B) : Colors.white;
  final background = dark ? charcoal : stone;
  final scheme = ColorScheme.fromSeed(
    seedColor: emerald, brightness: dark ? Brightness.dark : Brightness.light,
    surface: surface);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    appBarTheme: AppBarTheme(backgroundColor: background, elevation: 0),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface, height: 72,
      indicatorColor: scheme.primary.withValues(alpha: .12),
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17), borderSide: BorderSide.none)),
    cardTheme: CardThemeData(
      color: surface, elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(21))),
  );
}

class DictionaryApp extends StatefulWidget {
  const DictionaryApp({super.key, this.previewWords});
  final List<Word>? previewWords;
  @override State<DictionaryApp> createState() => _DictionaryAppState();
}

class _DictionaryAppState extends State<DictionaryApp> {
  ThemeMode mode = ThemeMode.system;
  double font = 23;
  @override
  void initState() {
    super.initState();
    restore();
    // Submit the preference once the Flutter window has attached. This does
    // not force 120 Hz; the device may choose 60/90/120 based on its policy.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _requestHighRefreshRate();
    });
  }

  Future<void> _requestHighRefreshRate() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      // Keep the active display resolution; OS/user battery settings win.
      await FlutterDisplayMode.setHighRefreshRate();
    } on Exception {
      // Some vendors/displays do not expose discrete high refresh modes.
      // An unsupported preference must never prevent offline reading.
    }
  }

  Future<void> restore() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      mode = switch (p.getString('dictionary_theme_v2')) {
        'light' => ThemeMode.light, 'dark' => ThemeMode.dark, _ => ThemeMode.system};
      font = (p.getDouble('dictionary_font_size_v2') ?? 23).clamp(18.0, 34.0).toDouble();
    });
  }

  void changeTheme(ThemeMode value) {
    setState(() => mode = value);
    SharedPreferences.getInstance().then((p) => p.setString('dictionary_theme_v2',
      switch (value) {
        ThemeMode.light => 'light', ThemeMode.dark => 'dark',
        ThemeMode.system => 'system'}));
  }

  void changeFont(double value) {
    setState(() => font = value);
    SharedPreferences.getInstance().then(
      (p) => p.setDouble('dictionary_font_size_v2', value));
  }

  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Словарь Байна Ядайк',
    theme: dictionaryTheme(false),
    darkTheme: dictionaryTheme(true),
    themeMode: mode,
    home: DictionaryHome(
      previewWords: widget.previewWords, mode: mode, font: font,
      setMode: changeTheme, setFont: changeFont));
}

class DictionaryNav extends StatelessWidget {
  const DictionaryNav({super.key, required this.tab, required this.onTap});
  final int tab;
  final ValueChanged<int> onTap;
  @override Widget build(BuildContext context) => NavigationBar(
    selectedIndex: tab,
    onDestinationSelected: onTap,
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    destinations: const [
      NavigationDestination(icon: Icon(Icons.menu_book_outlined),
        selectedIcon: Icon(Icons.menu_book_rounded), label: 'Словарь'),
      NavigationDestination(icon: Icon(Icons.search_outlined),
        selectedIcon: Icon(Icons.search_rounded), label: 'Поиск'),
      NavigationDestination(icon: Icon(Icons.bookmark_border_rounded),
        selectedIcon: Icon(Icons.bookmark_rounded), label: 'Закладки'),
      NavigationDestination(icon: Icon(Icons.tune_rounded),
        selectedIcon: Icon(Icons.tune_rounded), label: 'Настройки'),
    ]);
}

class DictionaryHome extends StatefulWidget {
  const DictionaryHome({super.key, this.previewWords, required this.mode,
    required this.font, required this.setMode, required this.setFont});
  final List<Word>? previewWords;
  final ThemeMode mode;
  final double font;
  final ValueChanged<ThemeMode> setMode;
  final ValueChanged<double> setFont;
  @override State<DictionaryHome> createState() => _DictionaryHomeState();
}

class _DictionaryHomeState extends State<DictionaryHome> {
  late final Future<List<Word>> future = loadWords();
  final search = TextEditingController();
  final wordScroll = ScrollController();
  final searchScroll = ScrollController();
  final favoriteScroll = ScrollController();
  final bookmarkScroll = ScrollController();
  final tts = FlutterTts();
  final FramePerformanceMonitor frameMonitor = FramePerformanceMonitor();
  bool showFrameDiagnostics = false;
  DictionaryRenderMode renderMode = DictionaryRenderMode.regular;
  Set<String> favorites = {}, bookmarks = {};
  int tab = 0;
  int? selectedBook;
  int? selectedChapter;
  bool showAllWords = false;
  bool showFavorites = false;
  List<Word>? _cachedSource;
  List<Word>? _orderedWords;
  List<Word>? _visibleWords;
  Map<int, List<int>> _bookChapters = {};
  Map<Word, String> _searchContents = {};
  String? _visibleQuery;
  int? _visibleBook;
  int? _visibleChapter;

  List<Word> visibleWords(List<Word> all) {
    if (!identical(_cachedSource, all)) {
      _cachedSource = all;
      _orderedWords = sortWordsByBookOrder(all);
      _bookChapters = availableBookChapters(all);
      _searchContents = {
        for (final word in all)
          word: '${normalizeArabic(word.arabic)} ${normalizeArabic(word.meaning)} ${word.russian.toLowerCase()}',
      };
      _visibleWords = null;
    }
    // Book/topic browsing stays independent from the dedicated search tab.
    const query = '';
    if (_visibleWords != null &&
        query == _visibleQuery &&
        selectedBook == _visibleBook &&
        selectedChapter == _visibleChapter) {
      return _visibleWords!;
    }
    final matching = query.isEmpty
        ? _orderedWords!
        : _orderedWords!.where(
            (word) => _searchContents[word]!.contains(query)).toList();
    final visible = selectedBook == null
        ? matching.toList(growable: false)
        : selectedChapter == null
            ? matching.where((word) => word.isInBook(selectedBook!))
                .toList(growable: false)
            : filterWordsByChapter(matching, selectedBook!, selectedChapter!);
    _visibleQuery = query;
    _visibleBook = selectedBook;
    _visibleChapter = selectedChapter;
    _visibleWords = visible;
    return visible;
  }

  Future<List<Word>> loadWords() async {
    final p = await SharedPreferences.getInstance();
    final manifest = widget.previewWords == null
        ? jsonDecode(await rootBundle.loadString(
            'assets/data/corpus_manifest.json')) as Map<String, dynamic>
        : null;
    final files = (manifest?['files'] as List<dynamic>? ?? const []);
    final texts = await Future.wait([
      ...files.map((file) => rootBundle.loadString(file as String)),
      rootBundle.loadString('assets/data/ru_glosses.json'),
    ]);
    // JSON decoding/merging thousands of vocalized entries must not block
    // the Flutter UI isolate or scroll/transition frames.
    final List<Word> words = widget.previewWords == null
        ? await compute<List<String>, List<Word>>(
            decodeAndMergeCorporaWithRussian, texts)
        : widget.previewWords!;
    if (mounted) {
      setState(() {
      favorites = p.getStringList('dictionary_favorites')?.toSet() ?? {};
      bookmarks = p.getStringList('dictionary_bookmarks_v2')?.toSet() ?? {};
      });
    }
    return words;
  }

  @override void initState() {
    super.initState();
    search.addListener(onSearch);
  }
  void onSearch() { if (mounted) setState(() {}); }

  void setFrameDiagnostics(bool enabled) {
    if (enabled == showFrameDiagnostics) return;
    if (enabled) {
      frameMonitor.start();
    } else {
      frameMonitor.stop();
    }
    setState(() => showFrameDiagnostics = enabled);
  }

  @override void dispose() {
    search.removeListener(onSearch);
    search.dispose();
    wordScroll.dispose();
    searchScroll.dispose();
    favoriteScroll.dispose();
    bookmarkScroll.dispose();
    tts.stop();
    frameMonitor.dispose();
    super.dispose();
  }

  Future<void> speak(String text) async {
    await tts.setLanguage('ar-SA');
    await tts.setSpeechRate(.43);
    await tts.speak(text);
  }

  Future<void> copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Слово скопировано'),
        duration: Duration(seconds: 1)));
  }

  Future<void> toggleFavorite(String id) async {
    setState(() { if (!favorites.add(id)) favorites.remove(id); });
    final p = await SharedPreferences.getInstance();
    await p.setStringList('dictionary_favorites', favorites.toList());
  }

  Future<void> toggleBookmark(String id) async {
    setState(() { if (!bookmarks.add(id)) bookmarks.remove(id); });
    final p = await SharedPreferences.getInstance();
    await p.setStringList('dictionary_bookmarks_v2', bookmarks.toList());
  }

  void openWord(Word word, List<Word> corpus) {
    Navigator.of(context).push<void>(PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 230),
      reverseTransitionDuration: const Duration(milliseconds: 190),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final smooth = CurvedAnimation(
          parent: animation, curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic);
        return FadeTransition(
          opacity: smooth,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.045, 0.015),
              end: Offset.zero,
            ).animate(smooth),
            child: child,
          ));
      },
      pageBuilder: (_, animation, secondaryAnimation) => WordReader(
        word: word,
        font: widget.font,
        tab: tab,
        favorite: favorites.contains(word.id),
        bookmarked: bookmarks.contains(word.id),
        onFavorite: () => toggleFavorite(word.id),
        onBookmark: () => toggleBookmark(word.id),
        onSpeak: () { speak(word.arabic); },
        onCopy: () { copy(word.arabic); },
        onArabicTap: (token) {
          final next = findWordForToken(token, corpus);
          if (next == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Слово пока отсутствует в базе')));
          } else {
            openWord(next, corpus);
          }
        },
        onNavigate: (next) {
          Navigator.of(context).popUntil((r) => r.isFirst);
          setState(() => tab = next);
        },
      )));
  }

  @override Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (tab != 0) {
          setState(() => tab = 0);
        } else if (selectedChapter != null) {
          setState(() => selectedChapter = null);
        } else if (selectedBook != null || showAllWords) {
          setState(() {
            selectedBook = null;
            showAllWords = false;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Вы на главном экране словаря'),
              duration: Duration(seconds: 1)));
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Row(children: [
          Container(width: 37, height: 37,
            decoration: BoxDecoration(
              color: color.primary.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.auto_stories_rounded, size: 21, color: color.primary)),
          const SizedBox(width: 11),
          const Text('Байна Ядайк', style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w800)),
        ]), actions: [
          IconButton(tooltip: 'Настройки шрифта',
            icon: const Icon(Icons.text_fields_rounded),
            onPressed: () => setState(() => tab = 3)),
        ]),
        bottomNavigationBar: DictionaryNav(
          tab: tab, onTap: (next) {
            if (next != 0) frameMonitor.setScrolling(false);
            setState(() => tab = next);
          }),
        body: FutureBuilder<List<Word>>(
          future: future,
          builder: (context, snap) {
            if (snap.hasError) {
              return const Center(child: Text('Не удалось загрузить словарь'));
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final all = snap.data!;
            return Stack(children: [
              IndexedStack(index: tab, children: [
              dictionaryTab(all),
              searchTab(all),
              savedTab(all),
              settingsTab(),
              ]),
              if (showFrameDiagnostics)
                Positioned(
                  left: 12, right: 12, bottom: 8,
                  child: IgnorePointer(
                    child: frameDiagnosticsOverlay(),
                  ),
                ),
            ]);
          }),
      ));
  }

  Widget trackDictionaryScroll(Widget child) =>
      NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (!showFrameDiagnostics || notification.depth != 0) return false;
          if (notification is ScrollStartNotification) {
            frameMonitor.setScrolling(true);
          } else if (notification is ScrollEndNotification) {
            frameMonitor.setScrolling(false);
          }
          return false;
        },
        child: child,
      );

  Widget dictionaryTab(List<Word> all) {
    // Initialize sorted words and chapter references once per corpus.
    visibleWords(all);
    final books = _bookChapters;
    if (showAllWords || (selectedBook != null && selectedChapter != null)) {
      final words = visibleWords(all);
      return trackDictionaryScroll(CustomScrollView(
        key: const Key('dictionary-scroll-list'),
        controller: wordScroll,
        cacheExtent: 180,
        slivers: [
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                IconButton(
                  tooltip: showAllWords ? 'К томам' : 'К темам',
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => setState(() {
                    if (showAllWords) showAllWords = false;
                    selectedChapter = null;
                  })),
                Expanded(child: Text(
                  showAllWords ? 'Весь словарь' : 'Том $selectedBook · Тема $selectedChapter',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
              ]),
              const SizedBox(height: 4),
              Text('${words.length} слов', style: const TextStyle(color: muted)),
              if (!showAllWords) const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Привязки к учебнику требуют сверки с оригиналом.',
                  style: TextStyle(fontSize: 11, color: muted))),
            ]))),
          SliverList.builder(
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: true,
            itemCount: words.length,
            itemBuilder: (context, i) => WordTile(
              key: ValueKey(words[i].id),
              word: words[i], font: widget.font,
              showBackground: renderMode != DictionaryRenderMode.plain,
              showVowels: renderMode != DictionaryRenderMode.noVowels,
              favorite: favorites.contains(words[i].id),
              onOpen: () => openWord(words[i], all),
              onCopy: () { copy(words[i].arabic); },
              onFavorite: () { toggleFavorite(words[i].id); })),
          const SliverToBoxAdapter(child: SizedBox(height: 25)),
        ],
      ));
    }

    if (selectedBook != null) {
      final numbers = books[selectedBook!] ?? const <int>[];
      return ListView(
        key: const Key('chapter-list'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Row(children: [
            IconButton(
              tooltip: 'К томам',
              onPressed: () => setState(() => selectedBook = null),
              icon: const Icon(Icons.arrow_back_rounded)),
            Text('Том $selectedBook',
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
          ]),
          const Padding(
            padding: EdgeInsets.fromLTRB(9, 0, 9, 12),
            child: Text('Выберите тему. Отображаются только темы с привязками слов.',
              style: TextStyle(color: muted, fontSize: 13))),
          for (final chapter in numbers)
            Card(child: ListTile(
              key: ValueKey('chapter-$selectedBook-$chapter'),
              leading: const Icon(Icons.folder_open_outlined),
              title: Text('Тема $chapter'),
              subtitle: Text('${all.where((word) => word.isInChapter(selectedBook!, chapter)).length} слов'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => setState(() {
                selectedChapter = chapter;
                if (wordScroll.hasClients) wordScroll.jumpTo(0);
              }))),
        ],
      );
    }

    final bookNumbers = books.keys.toList()..sort();
    return ListView(
      key: const Key('volume-list'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF20443F) : const Color(0xFFE0EEE8),
            borderRadius: BorderRadius.circular(24)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('АРАБО-АРАБСКИЙ СЛОВАРЬ',
              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1,
                fontSize: 10)),
            const SizedBox(height: 7),
            Text('مُعْجَمُ الْعَرَبِيَّةِ',
              textDirection: TextDirection.rtl,
              style: TextStyle(fontSize: widget.font + 6,
                height: 1.6, fontWeight: FontWeight.bold)),
            Text('${all.length} статей · Офлайн',
              style: const TextStyle(fontSize: 13, color: muted)),
          ])),
        const SizedBox(height: 16),
        Card(child: ListTile(
          key: const Key('all-words-tile'),
          leading: const Icon(Icons.auto_stories_outlined),
          title: const Text('Весь словарь'),
          subtitle: Text('${all.length} слов, включая новые тематические разделы'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => setState(() {
            showAllWords = true;
            selectedBook = null;
            selectedChapter = null;
            if (wordScroll.hasClients) wordScroll.jumpTo(0);
          }))),
        const Padding(
          padding: EdgeInsets.fromLTRB(5, 17, 5, 5),
          child: Text('Тома учебника',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800))),
        const Padding(
          padding: EdgeInsets.fromLTRB(5, 0, 5, 7),
          child: Text('Только разделы, для которых есть ссылки на темы.',
            style: TextStyle(color: muted, fontSize: 12))),
        for (final book in bookNumbers)
          Card(child: ListTile(
            key: ValueKey('volume-$book'),
            leading: const Icon(Icons.menu_book_outlined),
            title: Text('Том $book'),
            subtitle: Text('${books[book]!.length} тем'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => setState(() {
              selectedBook = book;
              selectedChapter = null;
              showAllWords = false;
            }))),
      ],
    );
  }

  Widget searchTab(List<Word> all) {
    final query = normalizeArabic(search.text);
    visibleWords(all);
    final matches = query.isEmpty
        ? <Word>[]
        : _orderedWords!.where((word) =>
            _searchContents[word]!.contains(query)).toList(growable: false);
    final visible = matches;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Поиск по словарю',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          TextField(
            key: const Key('arabic-search'),
            controller: search,
            textDirection: RegExp(r'[а-яА-ЯёЁ]').hasMatch(search.text)
                ? TextDirection.ltr : TextDirection.rtl,
            style: TextStyle(fontSize: widget.font),
            decoration: InputDecoration(
              hintText: 'Поиск на арабском или русском',
              hintTextDirection: TextDirection.ltr,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: search.text.isEmpty ? null : IconButton(
                tooltip: 'Очистить поиск',
                onPressed: search.clear,
                icon: const Icon(Icons.close_rounded)))),
          const SizedBox(height: 7),
          Text(query.isEmpty
              ? 'Ищите по арабскому слову, объяснению или русскому переводу.'
              : '${matches.length} результатов${matches.length > visible.length ? ' · показаны первые ${visible.length}' : ''}',
              style: const TextStyle(color: muted, fontSize: 12)),
        ])),
      Expanded(child: query.isEmpty
          ? const Center(child: Icon(Icons.manage_search_rounded,
              size: 60, color: muted))
          : ListView.builder(
              key: const Key('search-results-list'),
              controller: searchScroll,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              itemCount: visible.length,
              itemBuilder: (context, i) => WordTile(
                key: ValueKey('search-${visible[i].id}'),
                word: visible[i], font: widget.font,
                favorite: favorites.contains(visible[i].id),
                onOpen: () => openWord(visible[i], all),
                onCopy: () { copy(visible[i].arabic); },
                onFavorite: () { toggleFavorite(visible[i].id); }))),
    ]);
  }

  Widget savedTab(List<Word> all) => Column(children: [
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 3),
      child: SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: false,
            label: Text('Закладки'), icon: Icon(Icons.bookmark_outline)),
          ButtonSegment(value: true,
            label: Text('Избранное'), icon: Icon(Icons.favorite_border)),
        ],
        selected: {showFavorites},
        onSelectionChanged: (values) =>
            setState(() => showFavorites = values.first))),
    Expanded(child: showFavorites
        ? collectionTab(all, favorites, 'Избранные слова',
            'Сохранено сердечком', favoriteScroll,
            const Key('favorites-scroll-list'), Icons.favorite_border)
        : collectionTab(all, bookmarks, 'Закладки',
            'Слова для быстрого возвращения', bookmarkScroll,
            const Key('bookmarks-scroll-list'), Icons.bookmark_border)),
  ]);

  Widget collectionTab(List<Word> all, Set<String> ids,
      String title, String subtitle, ScrollController controller,
      Key key, IconData emptyIcon) {
    final words = sortWordsByBookOrder(all.where((w) => ids.contains(w.id)));
    return CustomScrollView(
      key: key, controller: controller, cacheExtent: 180,
      slivers: [
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 27,
              fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(color: muted)),
            const SizedBox(height: 10),
            Text('${words.length} слов', style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary)),
          ]))),
        if (words.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Column(
              mainAxisSize: MainAxisSize.min, children: [
                Icon(emptyIcon, size: 50, color: muted),
                const SizedBox(height: 14),
                const Text('Здесь пока нет слов',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const Text('Отметьте слово при чтении',
                  style: TextStyle(color: muted)),
              ])))
        else SliverList.builder(
          itemCount: words.length,
          itemBuilder: (context, i) => WordTile(
            key: ValueKey('saved-${words[i].id}'),
            word: words[i], font: widget.font,
            favorite: favorites.contains(words[i].id),
            onOpen: () => openWord(words[i], all),
            onCopy: () { copy(words[i].arabic); },
            onFavorite: () { toggleFavorite(words[i].id); })),
      ]);
  }

  Widget frameDiagnosticsOverlay() => ValueListenableBuilder<
      FramePerformanceReport>(
    valueListenable: frameMonitor,
    builder: (context, report, _) {
      final sufficient = report.cadenceIntervals >= 10;
      final fps = sufficient && report.cadenceFps != null
          ? report.cadenceFps!.toStringAsFixed(0) : '—';
      final interval = sufficient && report.cadenceP95Ms != null
          ? report.cadenceP95Ms!.toStringAsFixed(1) : '—';
      final longGaps = sufficient && report.longGapPercent != null
          ? report.longGapPercent!.toStringAsFixed(0) : '—';
      return DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xE91D2A27),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Экран: ${report.displayHz.toStringAsFixed(0)} Гц · '
                'Flutter: $fps кадров/с',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white, fontSize: 12,
                  fontWeight: FontWeight.w700)),
              Text(
                'Интервал p95: $interval мс · длинных: $longGaps%',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFDAE8E2), fontSize: 11)),
              Text(
                report.samples == 0
                  ? 'Прокрутите список — ожидаем данные Flutter'
                  : 'UI: ${report.uiP95Ms.toStringAsFixed(1)} · '
                    'Raster: ${report.rasterP95Ms.toStringAsFixed(1)} мс · '
                    '> бюджета: ${report.overBudgetPercent.toStringAsFixed(0)}%',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFDAE8E2), fontSize: 11)),
            ],
          ),
        ),
      );
    },
  );

  Widget settingsTab() => ListView(
    key: const Key('settings-list'),
    padding: const EdgeInsets.fromLTRB(18, 24, 18, 30),
    children: [
      const Text('Настройки чтения', style: TextStyle(
        fontWeight: FontWeight.w800, fontSize: 27)),
      const SizedBox(height: 6),
      const Text('Настройте словарь под экран и освещение',
        style: TextStyle(color: muted)),
      const SizedBox(height: 21),
      settingCard(children: [
        const Text('Размер арабского шрифта', style: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Row(children: [
          const Text('Аа', style: TextStyle(fontSize: 15)),
          Expanded(child: Slider(
            key: const Key('arabic-font-slider'),
            min: 18, max: 34, divisions: 16, value: widget.font,
            label: '${widget.font.round()}',
            onChanged: widget.setFont)),
          const Text('Аа', style: TextStyle(fontSize: 25)),
        ]),
        Center(child: Text('${widget.font.round()}',
          style: const TextStyle(fontWeight: FontWeight.w700))),
        const SizedBox(height: 14),
        Text('مَبْنًى يَسْكُنُ فِيهِ النَّاسُ',
          textAlign: TextAlign.center, textDirection: TextDirection.rtl,
          style: TextStyle(fontSize: widget.font, height: 1.9)),
      ]),
      const SizedBox(height: 15),
      settingCard(children: [
        const Text('Оформление', style: TextStyle(
          fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 12),
        Wrap(spacing: 7, runSpacing: 6, children: [
          ChoiceChip(label: const Text('Системная'),
            selected: widget.mode == ThemeMode.system,
            onSelected: (_) => widget.setMode(ThemeMode.system)),
          ChoiceChip(label: const Text('Светлая'),
            selected: widget.mode == ThemeMode.light,
            onSelected: (_) => widget.setMode(ThemeMode.light)),
          ChoiceChip(label: const Text('Тёмная'),
            selected: widget.mode == ThemeMode.dark,
            onSelected: (_) => widget.setMode(ThemeMode.dark)),
        ]),
      ]),
      const SizedBox(height: 15),
      settingCard(children: [
        SwitchListTile.adaptive(
          key: const Key('frame-diagnostics-toggle'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Диагностика плавности',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          subtitle: const Text(
            'Показывает частоту экрана и время UI/raster при прокрутке.',
            style: TextStyle(fontSize: 12)),
          value: showFrameDiagnostics,
          onChanged: setFrameDiagnostics,
        ),
        const Text(
          '120 Гц — это частота дисплея, не FPS приложения. Flutter показывает '
          'интервалы между кадрами движка, а не момент их вывода Android.',
          style: TextStyle(fontSize: 12, color: muted)),
        const SizedBox(height: 9),
        OutlinedButton.icon(
          key: const Key('copy-cadence-report'),
          icon: const Icon(Icons.copy_all_outlined),
          label: const Text('Скопировать отчёт прокрутки'),
          onPressed: () async {
            final report = frameMonitor.value;
            String fmt(double? value) =>
                value == null ? 'недостаточно данных' : value.toStringAsFixed(2);
            final diagnostic = [
              'Байна Ядайк — прокрутка Flutter',
              'Дисплей: ${report.displayHz.toStringAsFixed(1)} Гц',
              'Бюджет: ${report.frameBudgetMs.toStringAsFixed(2)} мс',
              'Кадры Flutter (оценка, НЕ FPS SurfaceFlinger): '
                  '${fmt(report.cadenceFps)} кадров/с',
              'Интервал кадра p95: ${fmt(report.cadenceP95Ms)} мс',
              'Длинные vsync интервалы: ${fmt(report.longGapPercent)}%',
              'Интервалы: ${report.cadenceIntervals}; '
                  'выборка: ${report.samples}',
              'UI p95: ${report.uiP95Ms.toStringAsFixed(2)} мс',
              'Raster p95: ${report.rasterP95Ms.toStringAsFixed(2)} мс',
              'Доля кадров с превышением бюджета фаз: '
                  '${report.overBudgetPercent.toStringAsFixed(1)}%',
            ].join('\n');
            await Clipboard.setData(ClipboardData(text: diagnostic));
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Отчёт прокрутки скопирован')));
          },
        ),
        const SizedBox(height: 17),
        const Text('Сравнение отрисовки',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 9),
        Wrap(spacing: 7, runSpacing: 7, children: [
          ChoiceChip(
            key: const Key('render-mode-regular'),
            label: const Text('Обычные'),
            selected: renderMode == DictionaryRenderMode.regular,
            onSelected: (_) =>
              setState(() => renderMode = DictionaryRenderMode.regular)),
          ChoiceChip(
            key: const Key('render-mode-plain'),
            label: const Text('Без фона'),
            selected: renderMode == DictionaryRenderMode.plain,
            onSelected: (_) =>
              setState(() => renderMode = DictionaryRenderMode.plain)),
          ChoiceChip(
            key: const Key('render-mode-no-vowels'),
            label: const Text('Без огласовок'),
            selected: renderMode == DictionaryRenderMode.noVowels,
            onSelected: (_) =>
              setState(() => renderMode = DictionaryRenderMode.noVowels)),
        ]),
        const SizedBox(height: 8),
        const Text(
          'Только для диагностики списка. Слова в базе и карточке чтения '
          'не меняются. После перезапуска возвращается обычный режим.',
          style: TextStyle(fontSize: 12, color: muted)),
      ]),
      const SizedBox(height: 15),
      if (StartupFrameDiagnostics.enabled) ...[
        OutlinedButton.icon(
          key: const Key('copy-startup-trace'),
          icon: const Icon(Icons.copy_all_outlined),
          label: const Text('Скопировать отчёт о плавности'),
          onPressed: () async {
            final report = StartupFrameDiagnostics.instance.report(
              app: 'Байна Ядайк — словарь');
            await Clipboard.setData(ClipboardData(text: report));
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Отчёт скопирован. Вставьте его в чат.')),
            );
          },
        ),
        const SizedBox(height: 15),
      ],
      settingCard(children: const [
        Text('Офлайн-чтение', style: TextStyle(
          fontWeight: FontWeight.w700, fontSize: 16)),
        SizedBox(height: 8),
        Text('Закладки, избранные слова и настройки сохраняются на телефоне.',
          style: TextStyle(color: muted, fontSize: 13)),
      ]),
    ]);

  Widget settingCard({required List<Widget> children}) => Container(
    padding: const EdgeInsets.all(19),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(22)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children));
}

class WordTile extends StatelessWidget {
  const WordTile({super.key, required this.word, required this.font,
    required this.favorite, required this.onOpen, required this.onCopy,
    required this.onFavorite,
    this.showBackground = true, this.showVowels = true});
  final Word word;
  final double font;
  final bool favorite;
  final VoidCallback onOpen, onCopy, onFavorite;
  final bool showBackground, showVowels;

  @override Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reference =
        word.bookReferences.isEmpty ? null : word.bookReferences.first;
    final displayBook = word.bookNumber ?? reference?['book'] as int?;
    final displayChapter = word.chapterNumber ?? reference?['chapter'] as int?;
    final rounding = BorderRadius.circular(20);
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 16, 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Копировать слово',
                  onPressed: onCopy,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 48, minHeight: 48),
                  icon: const Icon(Icons.content_copy_rounded, size: 19)),
                const SizedBox(height: 7),
                IconButton(
                  tooltip: 'В избранное',
                  onPressed: onFavorite,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 48, minHeight: 48),
                  color: favorite ? scheme.primary : muted,
                  icon: Icon(
                    favorite ? Icons.favorite : Icons.favorite_border,
                    size: 21)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  showVowels ? word.arabic : withoutArabicVowels(word.arabic),
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: font + 2,
                    fontWeight: FontWeight.w700,
                    height: 1.42)),
                if (word.russian.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(word.russian, textAlign: TextAlign.left,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(fontSize: 15,
                      color: scheme.primary, fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 5),
                Text(
                  showVowels ? word.meaning : withoutArabicVowels(word.meaning),
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: font - 5,
                    height: 1.57,
                    color: scheme.onSurface.withValues(alpha: .78))),
                if (displayBook != null && displayChapter != null) ...[
                  const SizedBox(height: 9),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text(
                      'Книга $displayBook · Тема $displayChapter',
                      style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500,
                        color: scheme.primary)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    // A/B mode keeps the *same* word layouts, text sizes, actions, keys
    // and scroll state while removing only the card's Material background.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: showBackground
          ? Material(
              color: scheme.surface,
              borderRadius: rounding,
              child: InkWell(
                borderRadius: rounding,
                onTap: onOpen,
                child: content,
              ),
            )
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onOpen,
              child: content,
            ),
    );
  }
}

class WordReader extends StatefulWidget {
  const WordReader({super.key, required this.word, required this.font,
    required this.tab, required this.favorite, required this.bookmarked,
    required this.onFavorite, required this.onBookmark,
    required this.onSpeak, required this.onCopy, required this.onArabicTap,
    required this.onNavigate});
  final Word word;
  final double font;
  final int tab;
  final bool favorite, bookmarked;
  final Future<void> Function() onFavorite, onBookmark;
  final VoidCallback onSpeak, onCopy;
  final ValueChanged<String> onArabicTap;
  final ValueChanged<int> onNavigate;
  @override State<WordReader> createState() => _WordReaderState();
}

class _WordReaderState extends State<WordReader> {
  late bool favorite = widget.favorite, bookmarked = widget.bookmarked;
  @override Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final w = widget.word;
    return Scaffold(
      appBar: AppBar(title: const Text('Карточка слова'),
        actions: [
          IconButton(
            tooltip: 'Копировать слово',
            onPressed: widget.onCopy,
            icon: const Icon(Icons.content_copy_rounded)),
          IconButton(
            tooltip: 'В избранное',
            color: favorite ? scheme.primary : null,
            icon: Icon(favorite ? Icons.favorite : Icons.favorite_border),
            onPressed: () async {
              await widget.onFavorite();
              if (mounted) setState(() => favorite = !favorite);
            }),
          IconButton(
            tooltip: 'Добавить закладку',
            color: bookmarked ? scheme.primary : null,
            icon: Icon(bookmarked ? Icons.bookmark : Icons.bookmark_border),
            onPressed: () async {
              await widget.onBookmark();
              if (mounted) setState(() => bookmarked = !bookmarked);
            }),
        ]),
      bottomNavigationBar: DictionaryNav(tab: widget.tab, onTap: widget.onNavigate),
      body: ListView(
        key: ValueKey('reader-${w.id}'),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 27),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 27, horizontal: 16),
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF234841) : const Color(0xFFDFEEE7),
              borderRadius: BorderRadius.circular(26)),
            child: Column(children: [
              Text(w.arabic, textDirection: TextDirection.rtl,
                style: TextStyle(fontSize: widget.font + 18,
                  fontWeight: FontWeight.w700, height: 1.7)),
              if (w.grammar.isNotEmpty)
                Text(w.grammar.first.split('؛').first,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(fontSize: widget.font - 5,
                    color: dark ? mint : emerald)),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: widget.onSpeak,
                icon: const Icon(Icons.volume_up_outlined),
                label: const Text('Прослушать')),
            ]),
          ),
          const SizedBox(height: 14),
          const Padding(padding: EdgeInsets.only(left: 5, bottom: 12),
            child: Text('Нажмите на арабское слово для перехода к статье.',
              style: TextStyle(color: muted, fontSize: 11))),
          if (w.russian.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(21),
                color: scheme.surface),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Перевод на русский',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 9),
                  Text(w.russian, textDirection: TextDirection.ltr,
                    style: TextStyle(fontSize: 18, color: scheme.primary)),
                ],
              ),
            ),
          section('01', 'Значения слова',
            [w.meaning, ...w.additionalMeanings], numbered: true),
          section('02', 'Синонимы', w.synonyms),
          section('03', 'Антонимы', w.antonyms,
            noData: 'Прямой антоним не указан'),
          section('04', 'Грамматика', w.grammar),
          section('05', 'Словосочетания', w.collocations),
          section('06', 'Примеры в предложениях', w.examples),
          section('07', 'Особенности употребления',
            w.usage.isEmpty ? [] : [w.usage]),
        ]),
    );
  }

  Widget section(String n, String title, List<String> texts, {
      bool numbered = false, String noData = 'Нет данных'}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(21), color: scheme.surface),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text(n, style: TextStyle(fontSize: 12, color: scheme.primary,
            fontWeight: FontWeight.w800)),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 13),
        if (texts.isEmpty)
          Text(noData, style: const TextStyle(color: muted))
        else
          for (var i = 0; i < texts.length; i++) ...[
            if (numbered && texts.length > 1)
              Text('Значение ${i + 1}', style: TextStyle(
                fontSize: 11, color: scheme.primary)),
            arabicWords(texts[i]),
            if (i < texts.length - 1)
              const Padding(padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1)),
          ],
      ]));
  }

  Widget arabicWords(String phrase) => Directionality(
    textDirection: TextDirection.rtl,
    child: Wrap(
      textDirection: TextDirection.rtl, spacing: 5, runSpacing: 2,
      children: [
        for (final token in phrase.split(RegExp(r'\s+')))
          if (token.isNotEmpty)
            InkWell(
              onTap: () => widget.onArabicTap(token),
              borderRadius: BorderRadius.circular(4),
              child: Text(token, textDirection: TextDirection.rtl,
                style: TextStyle(fontSize: widget.font, height: 1.7)),
            ),
      ]));
}
