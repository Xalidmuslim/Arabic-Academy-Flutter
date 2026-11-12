import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/dictionary_data.dart';
import '../core/dictionary_backup.dart';
import '../core/dictionary_search.dart';
import '../core/reviewed_lexicon.dart';
import '../core/lexical_relations.dart';
import 'review_screen.dart';

const emerald = Color(0xFF25776D);
const mint = Color(0xFF82CABB);
const stone = Color(0xFFF4F4F0);
const charcoal = Color(0xFF15201E);

class NoMotionPageTransitionsBuilder extends PageTransitionsBuilder {
  const NoMotionPageTransitionsBuilder();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route, BuildContext context,
    Animation<double> animation, Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

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
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    focusColor: Colors.transparent,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: NoMotionPageTransitionsBuilder(),
        TargetPlatform.iOS: NoMotionPageTransitionsBuilder(),
        TargetPlatform.macOS: NoMotionPageTransitionsBuilder(),
        TargetPlatform.windows: NoMotionPageTransitionsBuilder(),
        TargetPlatform.linux: NoMotionPageTransitionsBuilder(),
        TargetPlatform.fuchsia: NoMotionPageTransitionsBuilder(),
      },
    ),
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
  double lineHeight = 1.7;
  @override
  void initState() {
    super.initState();
    restore();
    // No refresh preference is set by the app.
    // Android/HyperOS decides per-app display policy.
  }

  Future<void> restore() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      mode = switch (p.getString('dictionary_theme_v2')) {
        'light' => ThemeMode.light, 'dark' => ThemeMode.dark, _ => ThemeMode.system};
      font = (p.getDouble('dictionary_font_size_v2') ?? 23).clamp(18.0, 34.0).toDouble();
      lineHeight = (p.getDouble('dictionary_line_height_v3') ?? 1.7).clamp(1.3, 2.2).toDouble();
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

  void changeLineHeight(double value) {
    setState(() => lineHeight = value);
    SharedPreferences.getInstance().then(
      (p) => p.setDouble('dictionary_line_height_v3', value));
  }

  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Словарь Байна Ядайк',
    theme: dictionaryTheme(false),
    darkTheme: dictionaryTheme(true),
    themeAnimationDuration: Duration.zero,
    themeMode: mode,
    home: DictionaryHome(
      previewWords: widget.previewWords, mode: mode, font: font,
      lineHeight: lineHeight, setLineHeight: changeLineHeight,
      setMode: changeTheme, setFont: changeFont));
}

class DictionaryNav extends StatelessWidget {
  const DictionaryNav({super.key, required this.tab, required this.onTap});
  final int tab;
  final ValueChanged<int> onTap;
  @override Widget build(BuildContext context) => NavigationBar(
    animationDuration: Duration.zero,
    selectedIndex: tab,
    onDestinationSelected: onTap,
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    destinations: const [
      NavigationDestination(icon: Icon(Icons.menu_book_outlined),
        selectedIcon: Icon(Icons.menu_book_rounded), label: 'Словарь'),
      NavigationDestination(icon: Icon(Icons.search_outlined),
        selectedIcon: Icon(Icons.search_rounded), label: 'Поиск'),
      NavigationDestination(icon: Icon(Icons.bookmark_border_rounded),
        selectedIcon: Icon(Icons.bookmark_rounded), label: 'Сохранённое'),
    ]);
}

class DictionaryHome extends StatefulWidget {
  const DictionaryHome({super.key, this.previewWords, required this.mode,
    required this.font, required this.lineHeight,
    required this.setMode, required this.setFont,
    required this.setLineHeight});
  final List<Word>? previewWords;
  final ThemeMode mode;
  final double font, lineHeight;
  final ValueChanged<double> setLineHeight;
  final ValueChanged<ThemeMode> setMode;
  final ValueChanged<double> setFont;
  @override State<DictionaryHome> createState() => _DictionaryHomeState();
}

class _DictionaryHomeState extends State<DictionaryHome> {
  late final Future<List<Word>> future = loadWords();
  final search = TextEditingController();
  Timer? searchDebounce;
  final wordScroll = ScrollController();
  final searchScroll = ScrollController();
  final favoriteScroll = ScrollController();
  final bookmarkScroll = ScrollController();
  final tts = FlutterTts();
  Set<String> favorites = {}, bookmarks = {};
  int tab = 0;
  int? selectedBook;
  int? selectedChapter;
  bool showAllWords = false;
  bool showFavorites = false;
  List<String> recentWords = [];
  List<String> recentSearches = [];
  int? searchBook;
  VoidCallback? refreshSettings;
  List<Word>? _cachedSource;
  List<Word>? _orderedWords;
  List<Word>? _visibleWords;
  Map<int, List<int>> _bookChapters = {};
  Map<String, ReviewedArticle> _reviewedByWordId = const {};
  Map<String, LexicalRelations> _relationsByWordId = const {};
  int? _visibleBook;
  int? _visibleChapter;

  List<Word> visibleWords(List<Word> all) {
    if (!identical(_cachedSource, all)) {
      _cachedSource = all;
      _orderedWords = sortWordsByBookOrder(all);
      _bookChapters = availableBookChapters(all);
      _visibleWords = null;
    }
    if (_visibleWords != null &&
        selectedBook == _visibleBook &&
        selectedChapter == _visibleChapter) {
      return _visibleWords!;
    }
    final source = _orderedWords!;
    final visible = selectedBook == null
        ? source.toList(growable: false)
        : selectedChapter == null
            ? source.where((word) => word.isInBook(selectedBook!))
                .toList(growable: false)
            : filterWordsByChapter(source, selectedBook!, selectedChapter!);
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
    final texts = widget.previewWords == null
        ? await Future.wait(
            files.map((file) => rootBundle.loadString(file as String)))
        : <String>[];
    // JSON decoding/merging thousands of vocalized entries must not block
    // the Flutter UI isolate or scroll/transition frames.
    final List<Word> words = widget.previewWords == null
        ? await compute<List<String>, List<Word>>(
            decodeAndMergeCorpora, texts)
        : widget.previewWords!;
    if (widget.previewWords == null) {
      final reviewedJson = await rootBundle.loadString(
          'assets/data/reviewed_articles_v1.json');
      final reviewed = decodeReviewedArticles(reviewedJson);
      _reviewedByWordId = matchReviewedArticles(words, reviewed);
      final relationJson = await rootBundle.loadString(
          'assets/data/lexical_relations_v1.json');
      _relationsByWordId = matchLexicalRelations(
          words, decodeLexicalRelations(relationJson));
    }
    if (mounted) {
      setState(() {
      favorites = p.getStringList('dictionary_favorites')?.toSet() ?? {};
      bookmarks = p.getStringList('dictionary_bookmarks_v2')?.toSet() ?? {};
      recentWords = p.getStringList('dictionary_recent_words_v3') ?? [];
      recentSearches = (p.getStringList('dictionary_search_history_v3') ?? [])
          .where((entry) => RegExp(r'[\u0621-\u064A]').hasMatch(entry))
          .toList();
      tab = (p.getInt('dictionary_last_tab_v3') ?? 0).clamp(0, 2);
      selectedBook = p.getInt('dictionary_last_book_v3');
      selectedChapter = p.getInt('dictionary_last_chapter_v3');
      showAllWords = p.getBool('dictionary_all_words_v3') ?? false;
      });
    }
    return words;
  }

  @override void initState() {
    super.initState();
    search.addListener(onSearch);
  }

  @override void didUpdateWidget(covariant DictionaryHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.font != widget.font ||
        oldWidget.lineHeight != widget.lineHeight ||
        oldWidget.mode != widget.mode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) refreshSettings?.call();
      });
    }
  }
  void onSearch() {
    searchDebounce?.cancel();
    searchDebounce = Timer(const Duration(milliseconds: 110), () {
      if (mounted) setState(() {});
    });
  }

  @override void dispose() {
    refreshSettings = null;
    search.removeListener(onSearch);
    searchDebounce?.cancel();
    search.dispose();
    wordScroll.dispose();
    searchScroll.dispose();
    favoriteScroll.dispose();
    bookmarkScroll.dispose();
    tts.stop();
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

  void updateDictionaryLocation(VoidCallback change) {
    setState(change);
    saveNavigation();
  }

  void saveNavigation() {
    SharedPreferences.getInstance().then((p) async {
      await p.setInt('dictionary_last_tab_v3', tab);
      await p.setBool('dictionary_all_words_v3', showAllWords);
      if (selectedBook == null) {
        await p.remove('dictionary_last_book_v3');
      } else {
        await p.setInt('dictionary_last_book_v3', selectedBook!);
      }
      if (selectedChapter == null) {
        await p.remove('dictionary_last_chapter_v3');
      } else {
        await p.setInt('dictionary_last_chapter_v3', selectedChapter!);
      }
    });
  }

  void recordVisit(Word word) {
    setState(() {
      recentWords.remove(word.id);
      recentWords.insert(0, word.id);
      if (recentWords.length > 40) recentWords.removeLast();
    });
    SharedPreferences.getInstance().then(
      (p) => p.setStringList('dictionary_recent_words_v3', recentWords));
  }

  void recordSearch(String text) {
    final query = text.trim();
    if (query.isEmpty || !RegExp(r'[\u0621-\u064A]').hasMatch(query)) return;
    setState(() {
      recentSearches.remove(query);
      recentSearches.insert(0, query);
      if (recentSearches.length > 12) recentSearches.removeLast();
    });
    SharedPreferences.getInstance().then(
      (p) => p.setStringList('dictionary_search_history_v3', recentSearches));
  }

  void openReview(List<Word> all) {
    final words = all.where((word) => favorites.contains(word.id)).toList();
    Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => ReviewScreen(words: words, fontSize: widget.font)));
  }

  Future<void> exportBackup() async {
    final json = DictionaryBackup(
      favorites: favorites.toList(),
      bookmarks: bookmarks.toList(),
      recentWords: recentWords,
      searchHistory: recentSearches,
    ).toJsonText();
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Резервная копия JSON скопирована. Сохраните её в файл.')));
  }

  Future<void> importBackup() async {
    final clipboard = await Clipboard.getData('text/plain');
    DictionaryBackup data;
    try {
      data = DictionaryBackup.fromJsonText(clipboard?.text ?? '');
    } on FormatException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('В буфере нет корректной резервной копии')));
      return;
    }
    if (!mounted) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Восстановить данные?'),
        content: Text('Закладки: ${data.bookmarks.length}, избранное: '
          '${data.favorites.length}. Текущие сохранённые списки будут заменены.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Восстановить')),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    final validIds = _cachedSource?.map((word) => word.id).toSet() ?? <String>{};
    final incomingFavorites = data.favorites.where(validIds.contains).toSet();
    final incomingBookmarks = data.bookmarks.where(validIds.contains).toSet();
    setState(() {
      favorites = incomingFavorites;
      bookmarks = incomingBookmarks;
      recentWords = data.recentWords.where(validIds.contains).take(40).toList();
      recentSearches = data.searchHistory
          .where((entry) => RegExp(r'[\u0621-\u064A]').hasMatch(entry))
          .take(12).toList();
    });
    final p = await SharedPreferences.getInstance();
    await p.setStringList('dictionary_favorites', favorites.toList());
    await p.setStringList('dictionary_bookmarks_v2', bookmarks.toList());
    await p.setStringList('dictionary_recent_words_v3', recentWords);
    await p.setStringList('dictionary_search_history_v3', recentSearches);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Резервная копия восстановлена')));
  }

  void openWord(Word word, List<Word> corpus) {
    recordVisit(word);
    Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => WordReader(
        word: word,
        reviewed: _reviewedByWordId[word.id],
        relations: _relationsByWordId[word.id],
        font: widget.font,
        lineHeight: widget.lineHeight,

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
      )));
  }

  @override Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return PopScope(
      canPop: tab == 0 && selectedBook == null && !showAllWords,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (tab != 0) {
          setState(() => tab = 0);
          saveNavigation();
        } else if (selectedChapter != null) {
          setState(() => selectedChapter = null);
          saveNavigation();
        } else if (selectedBook != null || showAllWords) {
          setState(() {
            selectedBook = null;
            showAllWords = false;
          });
          saveNavigation();
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
            onPressed: openSettings),
        ]),
        bottomNavigationBar: DictionaryNav(
          tab: tab, onTap: (next) {
            setState(() => tab = next);
            saveNavigation();
          }),
        body: FutureBuilder<List<Word>>(
          future: future,
          builder: (context, snap) {
            if (snap.hasError) {
              return const Center(child: Text('Не удалось загрузить словарь'));
            }
            if (!snap.hasData) {
              return const Center(child: Text('Загрузка словаря…'));
            }
            final all = snap.data!;
            return IndexedStack(index: tab, children: [
              dictionaryTab(all),
              searchTab(all),
              savedTab(all),
            ]);
          }),
      ));
  }

  void openSettings() {
    Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => StatefulBuilder(
        builder: (routeContext, rebuild) {
          refreshSettings = () {
            if (routeContext.mounted) rebuild(() {});
          };
          return Scaffold(
            appBar: AppBar(title: const Text('Настройки чтения')),
            body: settingsTab(),
          );
        },
      ),
    )).whenComplete(() => refreshSettings = null);
  }

  Widget dictionaryTab(List<Word> all) {
    // Initialize sorted words and chapter references once per corpus.
    visibleWords(all);
    final books = _bookChapters;
    if (showAllWords || (selectedBook != null && selectedChapter != null)) {
      final words = visibleWords(all);
      return CustomScrollView(
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
                  onPressed: () => updateDictionaryLocation(() {
                    if (showAllWords) showAllWords = false;
                    selectedChapter = null;
                  })),
                Expanded(child: Text(
                  showAllWords ? 'Весь словарь' : 'Том $selectedBook · Тема $selectedChapter',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
              ]),
              const SizedBox(height: 4),
              Text('${words.length} слов', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              if (!showAllWords) Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Привязки к учебнику требуют сверки с оригиналом.',
                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant))),
            ]))),
          SliverList.builder(
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: true,
            itemCount: words.length,
            itemBuilder: (context, i) => WordTile(
              key: ValueKey(words[i].id),
              word: words[i], font: widget.font,
            lineHeight: widget.lineHeight,
              favorite: favorites.contains(words[i].id),
              onOpen: () => openWord(words[i], all),
              onCopy: () { copy(words[i].arabic); },
              onFavorite: () { toggleFavorite(words[i].id); })),
          const SliverToBoxAdapter(child: SizedBox(height: 25)),
        ],
      );
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
              onPressed: () => updateDictionaryLocation(() => selectedBook = null),
              icon: const Icon(Icons.arrow_back_rounded)),
            Text('Том $selectedBook',
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(9, 0, 9, 12),
            child: Text('Выберите тему. Отображаются только темы с привязками слов.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13))),
          for (final chapter in numbers)
            Material(color: Colors.transparent, child: ListTile(
              key: ValueKey('chapter-$selectedBook-$chapter'),
              leading: const Icon(Icons.folder_open_outlined),
              title: Text('Тема $chapter'),
              subtitle: Text('${all.where((word) => word.isInChapter(selectedBook!, chapter)).length} слов'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => updateDictionaryLocation(() {
                selectedChapter = chapter;
                if (wordScroll.hasClients) wordScroll.jumpTo(0);
              }))),
        ],
      );
    }

    final bookNumbers = books.keys.toList()..sort();
    final lastWord = recentWords.isEmpty ? <Word>[] : all
      .where((word) => word.id == recentWords.first).take(1).toList();
    return ListView(
      key: const Key('volume-list'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF20443F) : const Color(0xFFE0EEE8),
            borderRadius: BorderRadius.circular(16)),
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
              style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ])),
        const SizedBox(height: 6),
        if (lastWord.isNotEmpty) ListTile(
          leading: const Icon(Icons.history_rounded),
          title: const Text('Продолжить'),
          subtitle: Text(lastWord.first.arabic,
            textDirection: TextDirection.rtl),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => openWord(lastWord.first, all),
        ),
        ListTile(
          leading: const Icon(Icons.search_rounded),
          title: const Text('Найти слово'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () {
            setState(() => tab = 1);
            saveNavigation();
          },
        ),
        Material(color: Colors.transparent, child: ListTile(
          key: const Key('all-words-tile'),
          leading: const Icon(Icons.auto_stories_outlined),
          title: const Text('Весь словарь'),
          subtitle: Text('${all.length} слов, включая новые тематические разделы'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => updateDictionaryLocation(() {
            showAllWords = true;
            selectedBook = null;
            selectedChapter = null;
            if (wordScroll.hasClients) wordScroll.jumpTo(0);
          }))),
        const Padding(
          padding: EdgeInsets.fromLTRB(5, 10, 5, 5),
          child: Text('Тома учебника',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800))),
        Padding(
          padding: const EdgeInsets.fromLTRB(5, 0, 5, 7),
          child: Text('Только разделы, для которых есть ссылки на темы.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12))),
        for (final book in bookNumbers)
          Material(color: Colors.transparent, child: ListTile(
            key: ValueKey('volume-$book'),
            leading: const Icon(Icons.menu_book_outlined),
            title: Text('Том $book'),
            subtitle: Text('${books[book]!.length} тем'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => updateDictionaryLocation(() {
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
    final visible = searchDictionary(_orderedWords!, query,
      book: searchBook);
    final matches = visible;
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
            textDirection: TextDirection.rtl,
            style: TextStyle(fontSize: widget.font),
            textInputAction: TextInputAction.search,
            onSubmitted: recordSearch,
            decoration: InputDecoration(
              hintText: 'Поиск на арабском',
              hintTextDirection: TextDirection.ltr,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: search.text.isEmpty ? null : IconButton(
                tooltip: 'Очистить поиск',
                onPressed: search.clear,
                icon: const Icon(Icons.close_rounded)))),
          const SizedBox(height: 7),
          Row(children: [
            const Text('Том:', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 8),
            DropdownButton<int?>(
              value: searchBook,
              isDense: true,
              items: [
                const DropdownMenuItem<int?>(
                  value: null, child: Text('Все тома')),
                for (final book in _bookChapters.keys.toList()..sort())
                  DropdownMenuItem<int?>(
                    value: book, child: Text('Том $book')),
              ],
              onChanged: (value) => setState(() => searchBook = value),
            ),
          ]),
          Text(query.isEmpty
              ? 'Ищите по арабскому слову или его объяснению.'
              : 'Показано ${matches.length} результатов (максимум 300)',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
        ])),
      Expanded(child: query.isEmpty
          ? SingleChildScrollView(child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                const SizedBox(height: 22),
                Icon(Icons.manage_search_rounded, size: 42,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(height: 12),
                const Text('Поиск по арабскому словарю'),
                if (recentSearches.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  const Align(alignment: Alignment.centerLeft,
                    child: Text('Недавние запросы')),
                  const SizedBox(height: 9),
                  Wrap(spacing: 7, runSpacing: 8,
                    children: [
                      for (final text in recentSearches)
                        ActionChip(label: Text(text), onPressed: () {
                          search.text = text;
                          search.selection = TextSelection.collapsed(
                            offset: text.length);
                        }),
                    ]),
                ],
              ])))
          : ListView.builder(
              key: const Key('search-results-list'),
              controller: searchScroll,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              itemCount: visible.length,
              itemBuilder: (context, i) => WordTile(
                key: ValueKey('search-${visible[i].id}'),
                word: visible[i], font: widget.font,
                lineHeight: widget.lineHeight,
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
    if (favorites.isNotEmpty)
      Padding(padding: const EdgeInsets.fromLTRB(16, 2, 16, 5),
        child: SizedBox(width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.school_outlined),
            label: const Text('Повторить избранные слова'),
            onPressed: () => openReview(all)))),
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
            Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
                Icon(emptyIcon, size: 50, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(height: 14),
                const Text('Здесь пока нет слов',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                Text('Отметьте слово при чтении',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ])))
        else SliverList.builder(
          itemCount: words.length,
          itemBuilder: (context, i) => WordTile(
            key: ValueKey('saved-${words[i].id}'),
            word: words[i], font: widget.font,
            lineHeight: widget.lineHeight,
            favorite: favorites.contains(words[i].id),
            onOpen: () => openWord(words[i], all),
            onCopy: () { copy(words[i].arabic); },
            onFavorite: () { toggleFavorite(words[i].id); })),
      ]);
  }

  Widget settingsTab() => ListView(
    key: const Key('settings-list'),
    padding: const EdgeInsets.fromLTRB(18, 24, 18, 30),
    children: [
      const Text('Настройки чтения', style: TextStyle(
        fontWeight: FontWeight.w800, fontSize: 27)),
      const SizedBox(height: 6),
      Text('Настройте словарь под экран и освещение',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
          style: TextStyle(fontSize: widget.font, height: widget.lineHeight)),
      ]),
      const SizedBox(height: 12),
      settingCard(children: [
        const Text('Межстрочный интервал арабского текста',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        Slider(
          key: const Key('arabic-line-slider'),
          min: 1.3, max: 2.2, divisions: 9,
          value: widget.lineHeight, onChanged: widget.setLineHeight),
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
        const Text('Резервное копирование',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('Сохранение закладок, избранного и истории в переносимый JSON. '
          'Обмен осуществляется через буфер обмена.',
          style: TextStyle(fontSize: 13)),
        const SizedBox(height: 9),
        OutlinedButton.icon(
          onPressed: exportBackup,
          icon: const Icon(Icons.ios_share_outlined),
          label: const Text('Скопировать резервную копию')),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: importBackup,
          icon: const Icon(Icons.settings_backup_restore_rounded),
          label: const Text('Восстановить из буфера')),
      ]),
      const SizedBox(height: 15),
      settingCard(children: [
        const Text('Офлайн-чтение', style: TextStyle(
          fontWeight: FontWeight.w700, fontSize: 16)),
        SizedBox(height: 8),
        Text('Закладки, избранные слова и настройки сохраняются на телефоне.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
      ]),
    ]);

  Widget settingCard({required List<Widget> children}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children));
}

class WordTile extends StatelessWidget {
  const WordTile({super.key, required this.word, required this.font,
    required this.favorite, required this.onOpen, required this.onCopy,
    required this.onFavorite, this.lineHeight = 1.7});
  final Word word;
  final double font, lineHeight;
  final bool favorite;
  final VoidCallback onOpen, onCopy, onFavorite;

  @override Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reference =
        word.bookReferences.isEmpty ? null : word.bookReferences.first;
    final displayBook = word.bookNumber ?? reference?['book'] as int?;
    final displayChapter = word.chapterNumber ?? reference?['chapter'] as int?;
    final rounding = BorderRadius.circular(12);
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                word.arabic,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: font + 1,
                  fontWeight: FontWeight.w700,
                  height: 1.52,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                word.meaning,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: font - 6,
                  height: lineHeight,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (displayBook != null && displayChapter != null) ...[
                const SizedBox(height: 4),
                Text('Том $displayBook · Тема $displayChapter',
                  style: TextStyle(fontSize: 11,
                    color: scheme.onSurfaceVariant)),
              ],
            ],
          )),
          const SizedBox(width: 8),
          IconButton(
            tooltip: favorite ? 'Убрать из избранного' : 'В избранное',
            onPressed: () {
              HapticFeedback.selectionClick();
              onFavorite();
            },
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: Icon(favorite ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              size: 21, color: favorite ? scheme.primary
                  : scheme.onSurfaceVariant),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: rounding,
            onTap: onOpen,
            onLongPress: onCopy,
            child: content,
          ),
        ),
        Divider(height: 1, thickness: .6,
          color: scheme.outlineVariant.withValues(alpha: .55)),
      ]),
    );
  }
}

class WordReader extends StatefulWidget {
  const WordReader({super.key, required this.word, required this.font,
    required this.favorite, required this.bookmarked,
    required this.onFavorite, required this.onBookmark,
    required this.onSpeak, required this.onCopy, required this.onArabicTap,
    this.lineHeight = 1.7, this.reviewed, this.relations});
  final Word word;
  final ReviewedArticle? reviewed;
  final LexicalRelations? relations;
  final double font, lineHeight;
  final bool favorite, bookmarked;
  final Future<void> Function() onFavorite, onBookmark;
  final VoidCallback onSpeak, onCopy;
  final ValueChanged<String> onArabicTap;
  @override State<WordReader> createState() => _WordReaderState();
}

class _WordReaderState extends State<WordReader> {
  late bool favorite = widget.favorite, bookmarked = widget.bookmarked;
  final Set<String> expandedSections = {'01', '04', '06', '08'};
  @override Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final w = widget.word;
    final enrichedSynonyms = <String>{...w.synonyms, ...?widget.relations?.synonyms}.toList();
    final enrichedAntonyms = <String>{...w.antonyms, ...?widget.relations?.antonyms}.toList();
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
      body: ListView(
        key: ValueKey('reader-${w.id}'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF234841) : const Color(0xFFDFEEE7),
              borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              Text(w.arabic, textDirection: TextDirection.rtl,
                style: TextStyle(fontSize: widget.font + 14,
                  fontWeight: FontWeight.w700, height: widget.lineHeight)),
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
          Padding(padding: const EdgeInsets.only(left: 5, bottom: 12),
            child: Text('Нажмите на арабское слово для перехода к статье.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11))),
          if (widget.reviewed case final reviewed?) ...[
            reviewedSection('01', 'Разъяснение значения', reviewed.definition),
            reviewedSection('04', 'Грамматический разбор', reviewed.grammar),
            reviewedSection('02', 'Синонимы', reviewed.synonyms,
              emptyMessage: 'Точные синонимы для данного значения не установлены.'),
            reviewedSection('03', 'Противоположные слова', reviewed.contrasts,
              emptyMessage: 'Прямого словарного антонима нет или он не подтверждён.'),
            if (w.collocations.isNotEmpty)
              section('05', 'Словосочетания', w.collocations),
            reviewedSection('06', 'Примеры', reviewed.examples),
            reviewedSection('08', 'Важно знать', reviewed.important),
            if (w.usage.trim().isNotEmpty)
              section('07', 'Особенности употребления', [w.usage]),
          ] else ...[
            section('01', 'Значения слова',
              [w.meaning, ...w.additionalMeanings], numbered: true),
            if (enrichedSynonyms.isNotEmpty) section('02', 'Синонимы', enrichedSynonyms),
            if (enrichedAntonyms.isNotEmpty) section('03', 'Антонимы', enrichedAntonyms),
            if (w.grammar.isNotEmpty) section('04', 'Грамматика', w.grammar),
            if (w.collocations.isNotEmpty) section('05', 'Словосочетания', w.collocations),
            if (w.examples.isNotEmpty) section('06', 'Примеры в предложениях', w.examples),
            if (w.usage.trim().isNotEmpty)
              section('07', 'Особенности употребления', [w.usage]),
          ],
        ]),
    );
  }

  Widget section(String n, String title, List<String> texts, {
      bool numbered = false, String noData = 'Нет данных'}) {
    final scheme = Theme.of(context).colorScheme;
    final expanded = expandedSections.contains(n);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey<String>('detail-${widget.word.id}-$n'),
            onTap: () => setState(() {
              if (!expandedSections.add(n)) expandedSections.remove(n);
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Row(children: [
                Text(n, style: TextStyle(fontSize: 12,
                  color: scheme.primary, fontWeight: FontWeight.w700)),
                const SizedBox(width: 10),
                Expanded(child: Text(title, style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700))),
                Icon(expanded ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                  size: 20, color: scheme.onSurfaceVariant),
              ]),
            ),
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (texts.isEmpty)
                  Text(noData, style: TextStyle(
                    color: scheme.onSurfaceVariant))
                else
                  for (var i = 0; i < texts.length; i++) ...[
                    if (numbered && texts.length > 1)
                      Align(alignment: Alignment.centerLeft,
                        child: Text('Значение ${i + 1}',
                          style: TextStyle(
                            fontSize: 12, color: scheme.primary))),
                    arabicWords(texts[i]),
                    if (i < texts.length - 1)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1)),
                  ],
              ]),
          ),
        Divider(height: 1, thickness: .6, color: scheme.outlineVariant),
      ]),
    );
  }

  Widget reviewedSection(String n, String title, List<ReviewedFact> facts, {
      String emptyMessage = 'Раздел требует отдельной словарной сверки.'}) {
    final scheme = Theme.of(context).colorScheme;
    final expanded = expandedSections.contains(n);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey<String>('detail-${widget.word.id}-$n'),
            onTap: () => setState(() {
              if (!expandedSections.add(n)) expandedSections.remove(n);
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Row(children: [
                Text(n, style: TextStyle(fontSize: 12,
                  color: scheme.primary, fontWeight: FontWeight.w700)),
                const SizedBox(width: 10),
                Expanded(child: Text(title, style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700))),
                Icon(expanded ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                  size: 20, color: scheme.onSurfaceVariant),
              ]),
            ),
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (facts.isEmpty)
                  Text(emptyMessage, style: TextStyle(
                    color: scheme.onSurfaceVariant, fontSize: 13))
                else
                  for (var i = 0; i < facts.length; i++) ...[
                    arabicWords(facts[i].arabic),
                    if (i < facts.length - 1)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 9),
                        child: Divider(height: 1)),
                  ],
              ]),
          ),
        Divider(height: 1, thickness: .6, color: scheme.outlineVariant),
      ]),
    );
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
              onLongPress: () {
                HapticFeedback.selectionClick();
                Clipboard.setData(ClipboardData(text: token));
              },
              borderRadius: BorderRadius.circular(4),
              child: Text(token, textDirection: TextDirection.rtl,
                style: TextStyle(fontSize: widget.font, height: widget.lineHeight)),
            ),
      ]));
}
