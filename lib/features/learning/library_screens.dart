import 'package:flutter/material.dart';

import '../../core/academy_state.dart';
import '../../core/arabic.dart';
import '../../core/speech.dart';
import '../../core/vocabulary_key.dart';
import '../../ui/components.dart';
import '../exercises/exercises.dart';

typedef OpenLibraryLesson =
    void Function(BuildContext context, Map<String, dynamic> lesson);

String _text(dynamic value) => value is String ? value : '';
List<dynamic> _list(dynamic value) => value is List ? value : const [];
List<Map<String, dynamic>> _maps(dynamic value) => [
  for (final item in _list(value))
    if (item is Map) Map<String, dynamic>.from(item),
];

Iterable<String> _strings(dynamic value) sync* {
  if (value is String) {
    yield value;
  } else if (value is List) {
    for (final item in value) {
      yield* _strings(item);
    }
  } else if (value is Map) {
    for (final item in value.values) {
      yield* _strings(item);
    }
  }
}

List<Map<String, dynamic>> _topics(AcademyState state) =>
    _maps(state.catalog['grammar_topics']);

class _Word {
  const _Word(this.lesson, this.data, this.index);
  final Map<String, dynamic> lesson, data;
  final int index;
  String get id => vocabularyKey(lesson['id'] as String, index, data);
  String get ar => _text(data['ar']);
  String get ru => _text(data['ru']);
  Iterable<String> get searchValues => [
    ar,
    ru,
    ..._strings(data['root']),
    _text(data['part_of_speech']),
    ..._strings(data['forms']),
    ..._strings(data['example']),
    ..._strings(data['examples']),
  ];
}

List<_Word> _words(AcademyState state, {String? lessonId}) {
  final words = <_Word>[];
  for (final lesson in state.allLessons) {
    if (_text(lesson['id']).isEmpty ||
        (lessonId != null && lesson['id'] != lessonId)) {
      continue;
    }
    final vocabulary = _list(lesson['vocabulary']);
    for (var index = 0; index < vocabulary.length; index++) {
      final data = vocabulary[index];
      if (data is Map && _text(data['ar']).trim().isNotEmpty) {
        words.add(_Word(lesson, Map<String, dynamic>.from(data), index));
      }
    }
  }
  return words;
}

Map<dynamic, dynamic> _review(AcademyState state, _Word word) {
  final value = state.reviews[word.id];
  return value is Map ? value : const {};
}

bool _due(Map<dynamic, dynamic> review) {
  final due = DateTime.tryParse(_text(review['due_at']));
  return due == null || !due.isAfter(DateTime.now());
}

double _setting(
  AcademyState state,
  String name,
  double fallback,
  double minimum,
  double maximum,
) {
  final value = state.settings[name];
  return value is num && value.isFinite
      ? value.toDouble().clamp(minimum, maximum)
      : fallback;
}

class _Arabic extends StatelessWidget {
  const _Arabic(this.text, this.state);
  final String text;
  final AcademyState state;
  @override
  Widget build(BuildContext context) => NaskhText(
    text,
    size: _setting(state, 'arabicSize', 28, 16, 44),
    height: _setting(state, 'arabicHeight', 1.8, 1.65, 2.5),
    color: Theme.of(context).colorScheme.onSurface,
  );
}

class _SpeechButton extends StatelessWidget {
  const _SpeechButton(this.state, this.text);
  final AcademyState state;
  final String text;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Синтез речи устройства — арабский голос',
    onPressed: () => guardedAction(
      context,
      () => ArabicSpeech.speak(
        text,
        speed: _setting(state, 'audioSpeed', 0.45, 0.2, 0.8),
      ),
    ),
    icon: const Icon(Icons.volume_up_outlined),
  );
}

class _BookmarkButton extends StatelessWidget {
  const _BookmarkButton(this.state, this.id, {this.legacyId});
  final AcademyState state;
  final String id;
  final String? legacyId;
  @override
  Widget build(BuildContext context) {
    final keys = state.bookmarks;
    final marked =
        keys.contains(id) || (legacyId != null && keys.contains(legacyId));
    return IconButton(
      key: ValueKey('bookmark-$id'),
      tooltip: marked ? 'Убрать из закладок' : 'Добавить в закладки',
      isSelected: marked,
      onPressed: () => guardedAction(context, () async {
        if (marked) {
          if (keys.contains(id)) await state.toggleBookmark(id);
          if (legacyId != null && keys.contains(legacyId)) {
            await state.toggleBookmark(legacyId!);
          }
        } else {
          await state.toggleBookmark(id);
        }
      }),
      icon: const Icon(Icons.bookmark_border),
      selectedIcon: const Icon(Icons.bookmark),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.fieldKey, required this.onChanged});
  final String fieldKey;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => TextField(
    key: ValueKey(fieldKey),
    onChanged: onChanged,
    decoration: const InputDecoration(
      labelText: 'Поиск на арабском или русском',
      prefixIcon: Icon(Icons.search),
      border: OutlineInputBorder(),
    ),
  );
}

void _openWord(
  BuildContext context,
  AcademyState state,
  _Word word,
  OpenLibraryLesson? onOpenLesson,
) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          _WordDetail(state: state, word: word, onOpenLesson: onOpenLesson),
    ),
  );
}

void _openTopic(
  BuildContext context,
  AcademyState state,
  Map<String, dynamic> topic,
) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _TopicDetail(state: state, topic: topic),
    ),
  );
}

enum _WordFilter { all, favorite, difficult, due }

/// Vocabulary retains its source spelling. Bookmark/review IDs use
/// `word:<lessonId>:<stableId>`; older index IDs remain valid during migration.
class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({
    super.key,
    required this.state,
    this.lessonId,
    this.onOpenLesson,
  });
  final AcademyState state;
  final String? lessonId;
  final OpenLibraryLesson? onOpenLesson;
  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  String _query = '';
  _WordFilter _filter = _WordFilter.all;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.state,
    builder: (context, _) {
      final state = widget.state;
      final words = _words(state, lessonId: widget.lessonId);
      final reviews = state.reviews;
      final favorites = state.bookmarks;
      Map<dynamic, dynamic> review(_Word word) =>
          reviews[word.id] is Map ? reviews[word.id] as Map : const {};
      final visible = words.where((word) {
        final included = switch (_filter) {
          _WordFilter.all => true,
          _WordFilter.favorite => favorites.contains(word.id),
          _WordFilter.difficult => review(word)['difficult'] == true,
          _WordFilter.due => _due(review(word)),
        };
        return included && matchesSearch(_query, word.searchValues);
      }).toList();
      return Scaffold(
        appBar: AppBar(title: const Text('Словарь')),
        body: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SearchField(
                      fieldKey: 'dictionary-search',
                      onChanged: (value) => setState(() => _query = value),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final entry in const {
                          _WordFilter.all: 'Все слова',
                          _WordFilter.favorite: 'Избранное',
                          _WordFilter.difficult: 'Трудные',
                          _WordFilter.due: 'К повторению',
                        }.entries)
                          FilterChip(
                            label: Text(entry.value),
                            selected: _filter == entry.key,
                            onSelected: (_) =>
                                setState(() => _filter = entry.key),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Слов: ${words.length} · Избранных: ${words.where((w) => favorites.contains(w.id)).length}',
                    ),
                    Text(
                      'К повторению: ${words.where((w) => _due(review(w))).length} · Трудных: ${words.where((w) => review(w)['difficult'] == true).length}',
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: visible.isEmpty
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    _Flashcards(state: state, words: visible),
                              ),
                            ),
                      icon: const Icon(Icons.style_outlined),
                      label: const Text('Карточки'),
                    ),
                  ],
                ),
              ),
            ),
            if (visible.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: EmptyState(
                    title: words.isEmpty
                        ? 'Словарь пока пуст'
                        : 'Ничего не найдено',
                    message: words.isEmpty
                        ? 'В этих уроках ещё нет словарных записей.'
                        : 'Измените запрос или выберите другой фильтр.',
                  ),
                ),
              )
            else
              SliverList.builder(
                itemCount: visible.length,
                itemBuilder: (context, index) {
                  final word = visible[index];
                  return _ResultTile(
                    itemKey: word.id,
                    title: word.ru,
                    arabic: word.ar,
                    subtitle: _text(word.lesson['title']),
                    state: state,
                    onTap: () =>
                        _openWord(context, state, word, widget.onOpenLesson),
                  );
                },
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 142))
          ],
        ),
      );
    },
  );
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.itemKey,
    required this.title,
    required this.state,
    required this.onTap,
    this.subtitle = '',
    this.arabic = '',
    this.legacyBookmark,
  });
  final String itemKey, title, subtitle, arabic;
  final AcademyState state;
  final VoidCallback onTap;
  final String? legacyBookmark;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Panel(
      padding: EdgeInsets.zero,
      child: ListTile(
        key: ValueKey(itemKey),
        contentPadding: const EdgeInsets.all(16),
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (arabic.isNotEmpty) _Arabic(arabic, state),
            if (subtitle.isNotEmpty) Text(subtitle),
          ],
        ),
        trailing: _BookmarkButton(state, itemKey, legacyId: legacyBookmark),
        onTap: onTap,
      ),
    ),
  );
}

class _WordDetail extends StatelessWidget {
  const _WordDetail({
    required this.state,
    required this.word,
    this.onOpenLesson,
  });
  final AcademyState state;
  final _Word word;
  final OpenLibraryLesson? onOpenLesson;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: state,
    builder: (context, _) {
      final data = word.data;
      final review = _review(state, word);
      final examples = <dynamic>[
        if (data['example'] != null) data['example'],
        ..._list(data['examples']),
      ];
      final forms = _list(data['forms']);
      final root = _strings(data['root']).join(' ');
      final due = DateTime.tryParse(_text(review['due_at']));
      final metadata = <String, dynamic>{
        'Часть речи': data['part_of_speech'],
        'Уровень': data['level'],
        'Род': data['gender'],
        'Единственное число': data['singular'],
        'Множественное число': data['plural'],
      };
      return Scaffold(
        appBar: AppBar(
          title: Text(word.ru.isEmpty ? 'Слово' : word.ru),
          actions: [_BookmarkButton(state, word.id)],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Arabic(word.ar, state),
                  if (word.ru.isNotEmpty)
                    Text(
                      word.ru,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _SpeechButton(state, word.ar),
                  ),
                  const Text(
                    'Озвучивание синтезируется устройством и требует установленного арабского голоса.',
                  ),
                ],
              ),
            ),
            for (final entry in metadata.entries)
              if (_strings(entry.value).isNotEmpty) ...[
                SectionTitle(entry.key),
                _LocalValue(value: entry.value, state: state),
              ],
            if (root.isNotEmpty) ...[
              const SectionTitle('Корень'),
              _Arabic(root, state),
            ],
            if (forms.isNotEmpty) ...[
              const SectionTitle('Формы'),
              for (final form in forms) _LocalValue(value: form, state: state),
            ],
            if (examples.isNotEmpty) ...[
              const SectionTitle('Примеры'),
              for (final example in examples)
                _LocalValue(value: example, state: state),
            ],
            const SectionTitle('Повторение'),
            Text(
              'Повторений: ${review['reviews'] is int ? review['reviews'] : 0} · Этап: ${review['stage'] is int ? review['stage'] : 0}',
            ),
            Text(
              review['difficult'] == true
                  ? 'Трудное слово'
                  : 'Без отметки сложности',
            ),
            Text(
              due == null
                  ? 'Ещё не повторялось'
                  : _due(review)
                  ? 'Пора повторить'
                  : 'Следующее повторение: ${_date(due)}',
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => guardedAction(
                context,
                () => state.reviewWord(word.id, false),
              ),
              child: const Text('Отметить трудным и повторить сегодня'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _Flashcards(state: state, words: [word]),
                ),
              ),
              child: const Text('Повторить карточку'),
            ),
            const SectionTitle('Источник'),
            Text(_text(word.lesson['title'])),
            if (onOpenLesson != null)
              TextButton(
                onPressed: () => onOpenLesson!(context, word.lesson),
                child: const Text('Открыть урок'),
              ),
          ],
        ),
      );
    },
  );
}

String _date(DateTime date) {
  final local = date.toLocal();
  return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
}

/// Renders only fields actually supplied by editorial content.
class _LocalValue extends StatelessWidget {
  const _LocalValue({required this.value, required this.state});
  final dynamic value;
  final AcademyState state;
  @override
  Widget build(BuildContext context) {
    if (value is String) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: RegExp(r'[\u0600-\u06FF]').hasMatch(value as String)
            ? _Arabic(value as String, state)
            : Text(value as String),
      );
    }
    if (value is List) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in value as List)
            _LocalValue(value: item, state: state),
        ],
      );
    }
    if (value is Map) {
      final map = value as Map;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_text(map['ar']).isNotEmpty)
              _Arabic(map['ar'] as String, state),
            if (_text(map['ru']).isNotEmpty) Text(map['ru'] as String),
            for (final key in ['label', 'text', 'translation'])
              if (_text(map[key]).isNotEmpty) Text(map[key] as String),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _Flashcards extends StatefulWidget {
  const _Flashcards({required this.state, required this.words});
  final AcademyState state;
  final List<_Word> words;
  @override
  State<_Flashcards> createState() => _FlashcardsState();
}

class _FlashcardsState extends State<_Flashcards> {
  int _index = 0;
  bool _revealed = false;
  bool _saving = false;

  Future<void> _reviewCard(bool remembered) async {
    if (_saving || !_revealed) return;
    setState(() => _saving = true);
    try {
      await widget.state.reviewWord(widget.words[_index].id, remembered);
      if (mounted) {
        setState(() {
          _index++;
          _revealed = false;
        });
      }
    } catch (error) {
      if (mounted) notice(context, 'Повторение не сохранено: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final finished = _index >= widget.words.length;
    final word = finished ? null : widget.words[_index];
    return Scaffold(
      appBar: AppBar(title: const Text('Карточки')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (finished)
            EmptyState(
              title: 'Карточки завершены',
              message: 'Сохранено повторений: $_index',
              action: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Вернуться в словарь'),
              ),
            )
          else ...[
            Text('Карточка ${_index + 1} из ${widget.words.length}'),
            const SizedBox(height: 16),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Arabic(word!.ar, widget.state),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _SpeechButton(widget.state, word.ar),
                  ),
                  if (_revealed) ...[
                    const Divider(),
                    Text(
                      word.ru,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (!_revealed)
              FilledButton(
                onPressed: () => setState(() => _revealed = true),
                child: const Text('Показать перевод'),
              )
            else ...[
              const Text(
                'Оцените, вспомнили ли вы слово до раскрытия перевода.',
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _saving ? null : () => _reviewCard(true),
                child: const Text('Помню'),
              ),
              OutlinedButton(
                onPressed: _saving ? null : () => _reviewCard(false),
                child: const Text('Повторить'),
              ),
              if (_saving) const LinearProgressIndicator(),
            ],
          ],
        ],
      ),
    );
  }
}

/// Topics are supplied by `state.catalog['grammar_topics']`; no synthetic theory.
class GrammarScreen extends StatefulWidget {
  const GrammarScreen({super.key, required this.state});
  final AcademyState state;
  @override
  State<GrammarScreen> createState() => _GrammarScreenState();
}

class _GrammarScreenState extends State<GrammarScreen> {
  String _query = '';
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.state,
    builder: (context, _) {
      final all = _topics(widget.state);
      final topics = all
          .where((topic) => matchesSearch(_query, _topicText(topic)))
          .toList();
      return Scaffold(
        appBar: AppBar(title: const Text('Грамматика')),
        body: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SearchField(
                      fieldKey: 'grammar-search',
                      onChanged: (value) => setState(() => _query = value),
                    ),
                    const SizedBox(height: 12),
                    Text('Тем: ${all.length}'),
                  ],
                ),
              ),
            ),
            if (topics.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: EmptyState(
                    title: all.isEmpty
                        ? 'Темы пока не добавлены'
                        : 'Ничего не найдено',
                    message: all.isEmpty
                        ? 'Теория появится после добавления материалов.'
                        : 'Попробуйте название правила или арабский пример.',
                  ),
                ),
              )
            else
              SliverList.builder(
                itemCount: topics.length,
                itemBuilder: (context, index) {
                  final topic = topics[index];
                  return _ResultTile(
                    itemKey: 'grammar:${topic['id']}',
                    title: _text(topic['title']),
                    subtitle: _text(topic['theory']),
                    state: widget.state,
                    onTap: () => _openTopic(context, widget.state, topic),
                  );
                },
              ),
          ],
        ),
      );
    },
  );
}

Iterable<String> _topicText(Map<String, dynamic> topic) => [
  _text(topic['title']),
  _text(topic['theory']),
  ..._strings(topic['examples']),
  ..._strings(topic['table']),
];

class _TopicDetail extends StatelessWidget {
  const _TopicDetail({required this.state, required this.topic});
  final AcademyState state;
  final Map<String, dynamic> topic;
  @override
  Widget build(BuildContext context) {
    final examples = _list(topic['examples']);
    final table = topic['table'] is Map ? topic['table'] as Map : const {};
    final rows = _list(table['rows']);
    final columns = _list(table['columns']).map(_text).toList();
    final exercises = _maps(topic['exercises']);
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(_text(topic['title'])),
          actions: [_BookmarkButton(state, 'grammar:${topic['id']}')],
        ),
        body: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: Panel(child: Text(_text(topic['theory']))),
              ),
            ),
            if (examples.isNotEmpty) ...[
              const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(child: SectionTitle('Примеры')),
              ),
              SliverList.builder(
                itemCount: examples.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _LocalValue(value: examples[index], state: state),
                ),
              ),
            ],
            if (rows.isNotEmpty) ...[
              const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(child: SectionTitle('Таблица')),
              ),
              SliverList.builder(
                itemCount: rows.length,
                itemBuilder: (context, index) => _GrammarRow(
                  columns: columns,
                  row: _list(rows[index]),
                  state: state,
                ),
              ),
            ],
            if (exercises.isNotEmpty) ...[
              const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(child: SectionTitle('Упражнения')),
              ),
              SliverList.builder(
                itemCount: exercises.length,
                itemBuilder: (context, index) {
                  final data = exercises[index];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Panel(
                      padding: EdgeInsets.zero,
                      child: ListTile(
                        key: ValueKey('exercise-${data['id']}'),
                        title: Text(_text(data['prompt'])),
                        subtitle: const Text('Открыть упражнение'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          try {
                            final expectedExercise = Exercise.fromJson(data);
                            if (expectedExercise.id.isEmpty) {
                              throw const FormatException(
                                'У упражнения нет идентификатора.',
                              );
                            }
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => _GrammarExercise(
                                  state: state,
                                  topicId: _text(topic['id']),
                                  expectedExercise: expectedExercise,
                                ),
                              ),
                            );
                          } catch (error) {
                            notice(
                              context,
                              'Не удалось открыть упражнение: $error',
                            );
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 142))
          ],
        ),
      ),
    );
  }
}

class _GrammarRow extends StatelessWidget {
  const _GrammarRow({
    required this.columns,
    required this.row,
    required this.state,
  });
  final List<String> columns;
  final List<dynamic> row;
  final AcademyState state;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Panel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cells = <Widget>[
            for (var index = 0; index < row.length; index++)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (index < columns.length)
                      Text(
                        columns[index],
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    _LocalValue(value: row[index], state: state),
                  ],
                ),
              ),
          ];
          if (constraints.maxWidth < 560 ||
              MediaQuery.textScalerOf(context).scale(16) > 22) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: cells,
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final cell in cells) Expanded(child: cell)],
          );
        },
      ),
    ),
  );
}

class _GrammarExercise extends StatefulWidget {
  const _GrammarExercise({
    required this.state,
    required this.topicId,
    required this.expectedExercise,
  });
  final AcademyState state;
  final String topicId;
  final Exercise expectedExercise;
  @override
  State<_GrammarExercise> createState() => _GrammarExerciseState();
}

class _GrammarExerciseState extends State<_GrammarExercise> {
  final List<({ExerciseResult result, dynamic answer})> _pending = [];
  ExerciseResult? _completed;
  int _savedChecks = 0;
  String? _error;
  bool _saving = false;
  late final dynamic _initialAnswer;
  String get _lessonId => 'grammar:${widget.topicId}';
  String get _draftId => '$_lessonId:${widget.expectedExercise.id}';

  @override
  void initState() {
    super.initState();
    final draft = widget.state.drafts[_draftId];
    _initialAnswer = draft is Map ? draft['answer'] : null;
  }

  void _onAttempt(ExerciseResult result, dynamic answer) {
    _pending.add((result: result, answer: copyExerciseValue(answer)));
    if (_error == null) _save();
  }

  Future<void> _save() async {
    if (_saving || _pending.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      while (_pending.isNotEmpty) {
        final check = _pending.first;
        // Identity comes from the assigned exercise, never submitted JSON.
        final verified = ExerciseEvaluator.evaluate(
          widget.expectedExercise,
          check.answer,
        );
        final status =
            verified.status == ExerciseStatus.needsReview ||
                check.result.status == ExerciseStatus.correct
            ? verified.status
            : check.result.status;
        final points = status == ExerciseStatus.correct && verified.passed
            ? verified.points
            : 0;
        await widget.state.recordAttempt(
          lessonId: _lessonId,
          exerciseId: widget.expectedExercise.id,
          answer: check.answer,
          status: status.name,
          points: points,
        );
        _pending.removeAt(0);
        _savedChecks++;
        if (mounted) setState(() {});
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'Ответ не сохранён: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Практика грамматики')),
    body: Column(
      children: [
        Expanded(
          child: ExerciseRunner(
            exercise: widget.expectedExercise,
            initialAnswer: _initialAnswer,
            onDraft: (answer) => guardedAction(
              context,
              () => widget.state.saveDraft(_draftId, {'answer': answer}),
            ),
            onAttempt: _onAttempt,
            onCompleted: (result, answer) =>
                setState(() => _completed = result),
          ),
        ),
        if (_saving) const LinearProgressIndicator(),
        if (_savedChecks > 0)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('Сохранено проверок: $_savedChecks'),
          ),
        if (_completed != null && !_saving && _pending.isEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Semantics(
              liveRegion: true,
              child: Text(switch (_completed!.status) {
                ExerciseStatus.correct => 'Практика завершена',
                ExerciseStatus.incorrect => 'Практика завершена без зачёта',
                ExerciseStatus.needsReview => 'Ожидает ручной проверки',
              }),
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text(_error!),
                TextButton(
                  onPressed: _save,
                  child: const Text('Повторить сохранение'),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

enum _ItemKind { lesson, word, grammar }

class _Item {
  const _Item({required this.kind, required this.data, this.word});
  final _ItemKind kind;
  final Map<String, dynamic> data;
  final _Word? word;
  String get id => switch (kind) {
    _ItemKind.lesson => 'lesson:${data['id']}',
    _ItemKind.word => word!.id,
    _ItemKind.grammar => 'grammar:${data['id']}',
  };
  Iterable<String> get searchValues => switch (kind) {
    _ItemKind.lesson => [
      _text(data['title']),
      _text(data['title_ar']),
      _text(data['goal']),
      _text(data['grammar']),
      ..._strings(data['dialogue']),
    ],
    _ItemKind.word => word!.searchValues,
    _ItemKind.grammar => _topicText(data),
  };
}

List<_Item> _items(AcademyState state) => [
  for (final lesson in state.allLessons)
    if (_text(lesson['id']).isNotEmpty)
      _Item(kind: _ItemKind.lesson, data: lesson),
  for (final word in _words(state))
    _Item(kind: _ItemKind.word, data: word.data, word: word),
  for (final topic in _topics(state))
    if (_text(topic['id']).isNotEmpty)
      _Item(kind: _ItemKind.grammar, data: topic),
];

Widget _itemTile(
  BuildContext context,
  AcademyState state,
  _Item item,
  OpenLibraryLesson onOpenLesson,
) {
  final title = item.kind == _ItemKind.word
      ? item.word!.ru
      : _text(item.data['title']);
  final arabic = item.kind == _ItemKind.word
      ? item.word!.ar
      : _text(item.data['title_ar']);
  final label = switch (item.kind) {
    _ItemKind.lesson => 'Урок',
    _ItemKind.word => 'Слово · ${_text(item.word!.lesson['title'])}',
    _ItemKind.grammar => 'Грамматика',
  };
  return _ResultTile(
    itemKey: item.id,
    title: title,
    arabic: arabic,
    subtitle: label,
    state: state,
    legacyBookmark: item.kind == _ItemKind.lesson
        ? _text(item.data['id'])
        : null,
    onTap: () {
      switch (item.kind) {
        case _ItemKind.lesson:
          onOpenLesson(context, item.data);
        case _ItemKind.word:
          _openWord(context, state, item.word!, onOpenLesson);
        case _ItemKind.grammar:
          _openTopic(context, state, item.data);
      }
    },
  );
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.state,
    required this.onOpenLesson,
  });
  final AcademyState state;
  final OpenLibraryLesson onOpenLesson;
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _query = '';
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.state,
    builder: (context, _) {
      final emptyQuery = normalizeSearch(_query).isEmpty;
      final results = emptyQuery
          ? <_Item>[]
          : _items(widget.state)
                .where((item) => matchesSearch(_query, item.searchValues))
                .toList();
      return Scaffold(
        appBar: AppBar(title: const Text('Поиск')),
        body: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: _SearchField(
                  fieldKey: 'library-search',
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
            ),
            if (results.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: EmptyState(
                    title: emptyQuery
                        ? 'Поиск по библиотеке'
                        : 'Ничего не найдено',
                    message: emptyQuery
                        ? 'Найдите урок, слово или грамматическую тему. Огласовки в запросе необязательны.'
                        : 'Проверьте запрос на арабском или русском.',
                  ),
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                sliver: SliverToBoxAdapter(
                  child: Text('Найдено: ${results.length}'),
                ),
              ),
              SliverList.builder(
                itemCount: results.length,
                itemBuilder: (context, index) => _itemTile(
                  context,
                  widget.state,
                  results[index],
                  widget.onOpenLesson,
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 142))
          ],
        ),
      );
    },
  );
}

/// Known bookmark types resolve against current content. Unavailable IDs remain
/// visible for explicit removal; browsing never silently deletes saved keys.
class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({
    super.key,
    required this.state,
    required this.onOpenLesson,
  });
  final AcademyState state;
  final OpenLibraryLesson onOpenLesson;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: state,
    builder: (context, _) {
      final bookmarks = state.bookmarks;
      final items = _items(state)
          .where(
            (item) =>
                bookmarks.contains(item.id) ||
                (item.kind == _ItemKind.lesson &&
                    bookmarks.contains(item.data['id'])),
          )
          .toList();
      final resolved = <String>{
        for (final item in items) item.id,
        for (final item in items)
          if (item.kind == _ItemKind.lesson) _text(item.data['id']),
      };
      final unavailable = bookmarks.difference(resolved).toList()..sort();
      return Scaffold(
        appBar: AppBar(title: const Text('Закладки')),
        body: bookmarks.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  EmptyState(
                    title: 'Нет закладок',
                    message:
                        'Сохраните урок, слово или правило кнопкой закладки.',
                  ),
                ],
              )
            : ListView.builder(
                itemCount: items.length + unavailable.length,
                itemBuilder: (context, index) {
                  if (index < items.length) {
                    return _itemTile(
                      context,
                      state,
                      items[index],
                      onOpenLesson,
                    );
                  }
                  final id = unavailable[index - items.length];
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Сохранённый материал недоступен'),
                          Text(id),
                          TextButton(
                            onPressed: () => guardedAction(
                              context,
                              () => state.toggleBookmark(id),
                            ),
                            child: const Text('Удалить закладку'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      );
    },
  );
}
