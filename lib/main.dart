import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

const paper = Color(0xFFF5F4EF);
const teal = Color(0xFF236D67);
const ink = Color(0xFF19302F);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BaynaDictionary());
}

class Word {
  const Word(this.id, this.arabic, this.meaning, this.synonyms, this.antonyms,
      this.grammar, this.collocations, this.examples, this.usage, this.additionalMeanings);
  final String id, arabic, meaning, usage;
  final List<String> synonyms, antonyms, grammar, collocations, examples, additionalMeanings;

  factory Word.fromJson(Map<String, dynamic> json) {
    List<String> strings(String key) =>
        ((json[key] as List<dynamic>?) ?? const []).cast<String>();
    return Word(
      json['id'] as String,
      json['arabic'] as String,
      json['meaning_ar'] as String,
      strings('synonyms'),
      strings('antonyms'),
      strings('grammar'),
      strings('collocations'),
      strings('examples_ar'),
      (json['usage_note_ar'] as String?) ?? '',
      strings('additional_meanings_ar'),
    );
  }
}

List<Word> decodeWords(String jsonText) {
  final object = jsonDecode(jsonText) as Map<String, dynamic>;
  return (object['entries'] as List<dynamic>)
      .map((dynamic item) => Word.fromJson(item as Map<String, dynamic>))
      .toList();
}

String normalizeArabic(String text) {
  return text.toLowerCase()
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED\u0640]'), '')
      .replaceAll(RegExp(r'[إأٱآ]'), 'ا')
      .replaceAll('ى', 'ي').trim();
}


/// Candidates preserve exact matches, then try common clitics and the article.
List<String> _candidateForms(String token) {
  final normalized = normalizeArabic(token)
      .replaceAll(RegExp(r'^[^ء-ي]+|[^ء-ي]+$'), '');
  if (normalized.isEmpty) return const [];
  final candidates = <String>[normalized];
  if (normalized.length > 2 &&
      (normalized.startsWith('و') || normalized.startsWith('ف'))) {
    candidates.add(normalized.substring(1));
  }
  for (final item in List<String>.of(candidates)) {
    if (item.length > 3 && item.startsWith('ال')) {
      candidates.add(item.substring(2));
    }
    if (item.length > 3 &&
        (item.startsWith('ب') || item.startsWith('ل') ||
         item.startsWith('ك'))) {
      final stem = item.substring(1);
      candidates.add(stem);
      if (stem.length > 3 && stem.startsWith('ال')) {
        candidates.add(stem.substring(2));
      }
    }
  }
  return candidates.toSet().toList();
}

Word? findWordForToken(String token, Iterable<Word> words) {
  final index = {for (final word in words) normalizeArabic(word.arabic): word};
  for (final candidate in _candidateForms(token)) {
    final matching = index[candidate];
    if (matching != null) return matching;
  }
  return null;
}

class BaynaDictionary extends StatelessWidget {
  const BaynaDictionary({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Словарь Байна Ядайк',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: paper,
        colorScheme: ColorScheme.fromSeed(seedColor: teal),
        appBarTheme: const AppBarTheme(backgroundColor: paper, foregroundColor: ink),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final search = TextEditingController();
  final tts = FlutterTts();
  late final Future<List<Word>> future = load();
  Set<String> favorites = <String>{};
  bool onlyFavorites = false;

  Future<List<Word>> load() async {
    final prefs = await SharedPreferences.getInstance();
    favorites = prefs.getStringList('dictionary_favorites')?.toSet() ?? {};
    final content = await rootBundle.loadString('assets/data/entries.json');
    if (mounted) setState(() {});
    return decodeWords(content);
  }

  Future<void> speak(String word) async {
    await tts.setLanguage('ar-SA');
    await tts.setSpeechRate(0.42);
    await tts.speak(word);
  }

  Future<void> toggleFavorite(String id) async {
    setState(() {
      if (!favorites.add(id)) favorites.remove(id);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('dictionary_favorites', favorites.toList());
  }


  void openWord(BuildContext context, Word word, List<Word> allWords) {
    Navigator.push<void>(context, MaterialPageRoute<void>(
      builder: (_) => WordScreen(
        word: word,
        saved: favorites.contains(word.id),
        onSound: () { speak(word.arabic); },
        onToggle: () => toggleFavorite(word.id),
        onTapWord: (token) {
          final found = findWordForToken(token, allWords);
          if (found != null) {
            openWord(context, found, allWords);
          } else {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Для этого слова статья пока не добавлена'),
              duration: Duration(seconds: 2),
            ));
          }
        },
      ),
    ));
  }

  @override
  void initState() {
    super.initState();
    search.addListener(refresh);
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    search.removeListener(refresh);
    search.dispose();
    tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Словарь Байна Ядайк',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: 'Избранное',
            icon: Icon(onlyFavorites ? Icons.bookmark : Icons.bookmark_outline),
            onPressed: () => setState(() => onlyFavorites = !onlyFavorites),
          ),
        ],
      ),
      body: FutureBuilder<List<Word>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Не удалось загрузить словарь'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final q = normalizeArabic(search.text);
          final shown = snapshot.data!.where((word) =>
            (q.isEmpty ||
             normalizeArabic(word.arabic).contains(q) ||
             normalizeArabic(word.meaning).contains(q)) &&
            (!onlyFavorites || favorites.contains(word.id))).toList();

          return CustomScrollView(slivers: [
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Арабско-арабский словарь',
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800,
                    color: ink)),
                const SizedBox(height: 6),
                const Text('7 разделов · Арабские объяснения',
                  style: TextStyle(color: Colors.blueGrey)),
                const SizedBox(height: 16),
                TextField(
                  controller: search,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Поиск на арабском',
                    suffixIcon: search.text.isEmpty ? null : IconButton(
                      tooltip: 'Очистить', icon: const Icon(Icons.close),
                      onPressed: search.clear),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Найдено слов: ${shown.length}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 5),
                const Text('Демонстрационная версия: 33 статьи',
                  style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
              ]),
            )),
            SliverList.builder(
              itemCount: shown.length,
              itemBuilder: (context, index) {
                final word = shown[index];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12,
                        vertical: 6),
                      leading: IconButton(
                        tooltip: 'Произнести',
                        icon: const Icon(Icons.volume_up_outlined, color: teal),
                        onPressed: () { speak(word.arabic); },
                      ),
                      title: Text(word.arabic, textDirection: TextDirection.rtl,
                        style: const TextStyle(fontSize: 23,
                          fontWeight: FontWeight.bold, color: ink)),
                      subtitle: Text(word.meaning, textDirection: TextDirection.rtl,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, height: 1.5)),
                      trailing: Icon(favorites.contains(word.id)
                        ? Icons.bookmark : Icons.chevron_right, color: teal),
                      onTap: () { openWord(context, word, snapshot.data!); },
                    ),
                  ),
                );
              },
            ),
          ]);
        },
      ),
    );
  }
}

class WordScreen extends StatefulWidget {
  const WordScreen({
    super.key,
    required this.word,
    required this.saved,
    required this.onSound,
    required this.onToggle,
    required this.onTapWord,
  });
  final Word word;
  final bool saved;
  final VoidCallback onSound;
  final Future<void> Function() onToggle;
  final void Function(String) onTapWord;

  @override
  State<WordScreen> createState() => _WordScreenState();
}

class _WordScreenState extends State<WordScreen> {
  late bool saved = widget.saved;

  Widget section(String title, List<String> content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: const TextStyle(fontSize: 15,
          fontWeight: FontWeight.w800, color: teal)),
        const SizedBox(height: 10),
        if (content.isEmpty) const Text('Нет данных',
          style: TextStyle(color: Colors.grey))
        else for (final phrase in content) Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Wrap(
              textDirection: TextDirection.rtl,
              spacing: 6,
              runSpacing: 5,
              children: [
                for (final token in phrase.split(RegExp(r'\s+')))
                  if (token.isNotEmpty)
                    InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: () => widget.onTapWord(token),
                      child: Text(token,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(fontSize: 22, height: 1.75, color: ink)),
                    ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final word = widget.word;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Карточка слова'),
        actions: [
          IconButton(
            tooltip: 'Избранное',
            icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
            onPressed: () async {
              await widget.onToggle();
              if (mounted) setState(() => saved = !saved);
            },
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(17, 10, 17, 28), children: [
        Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: const Color(0xFFE6EFEB),
            borderRadius: BorderRadius.circular(25)),
          child: Column(children: [
            Text(word.arabic, textDirection: TextDirection.rtl,
              style: const TextStyle(fontSize: 42, height: 1.8,
                fontWeight: FontWeight.w700, color: ink)),
            if (word.grammar.isNotEmpty)
              Text(word.grammar.first.split('؛').first,
                textDirection: TextDirection.rtl,
                style: const TextStyle(fontSize: 16, color: teal)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: widget.onSound,
              icon: const Icon(Icons.volume_up_outlined),
              label: const Text('Слушать'),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.only(bottom: 13, left: 5),
          child: Text('Нажмите на арабское слово, чтобы открыть его значение.',
            style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
        ),
        section('1. Значения слова', [word.meaning, ...word.additionalMeanings]),
        section('2. Синонимы', word.synonyms),
        section('3. Антонимы', word.antonyms),
        section('4. Грамматика', word.grammar),
        section('5. Словосочетания', word.collocations),
        section('6. Примеры в предложениях', word.examples),
        section('7. Особенности употребления',
          word.usage.isEmpty ? [] : [word.usage]),
      ]),
    );
  }
}
