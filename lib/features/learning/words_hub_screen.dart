import 'package:flutter/material.dart';

import '../../core/academy_state.dart';
import '../../core/app_strings.dart';
import '../../core/practice_generator.dart';
import '../../core/speech.dart';
import '../../core/vocabulary_practice.dart';
import 'practice_center_screen.dart';
import '../../ui/components.dart';
import '../../ui/design_tokens.dart';
import 'illustrated_dictionary_screen.dart';
import 'library_screens.dart' show DictionaryScreen;
import 'vocabulary_practice_screen.dart';

/// One learner entry for exploring, recalling and spaced-reviewing vocabulary.
/// Does not change word IDs or persisted review history.
class WordsHubScreen extends StatefulWidget {
  const WordsHubScreen({super.key, required this.state, this.lessonId});
  final AcademyState state;
  final String? lessonId;

  @override
  State<WordsHubScreen> createState() => _WordsHubScreenState();
}

class _WordsHubScreenState extends State<WordsHubScreen> {
  final _query = TextEditingController();
  String _phase = 'learn';

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _practice() => Navigator.push(context, MaterialPageRoute<void>(
    builder: (_) => VocabularyPracticeScreen(
      state: widget.state, lessonId: widget.lessonId),
  ));

  void _intensive() => Navigator.push(context,
      MaterialPageRoute<void>(builder: (_) => PracticeSessionScreen(
        state: widget.state,
        mode: PracticeMode.intensive,
        lessonId: widget.lessonId,
      )));

  Future<void> _speak(String arabic) => guardedAction(context,
      () => ArabicSpeech.speak(arabic));

  void _showWord(VocabularyPracticeWord word) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 6, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (word.imagePath?.isNotEmpty == true ||
                  IllustratedTerm.hasIllustration(word.ar))
                Center(child: SemanticWordIllustration(
                  arabic: word.ar, imagePath: word.imagePath, size: 150)),
              const SizedBox(height: 12),
              NaskhText(word.ar, size: 34, align: TextAlign.center),
              const SizedBox(height: 7),
              Text(word.ru, textAlign: TextAlign.center,
                style: Theme.of(sheet).textTheme.titleLarge),
              const SizedBox(height: 7),
              Text(word.lessonTitle, textAlign: TextAlign.center,
                style: const TextStyle(color: DesignTokens.secondary)),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _speak(word.ar),
                icon: const Icon(Icons.volume_up_outlined),
                label: const Text('Прослушать'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr(context, 'Слова'))),
    body: AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        final all = VocabularyPractice.words(widget.state,
          lessonId: widget.lessonId);
        final review = VocabularyPractice.plan(widget.state,
          lessonId: widget.lessonId);
        final search = _query.text.trim().toLowerCase();
        final shown = <VocabularyPracticeWord>[];
        final seen = <String>{};
        for (final word in all) {
          if (search.isNotEmpty &&
              !word.ru.toLowerCase().contains(search) &&
              !word.ar.toLowerCase().contains(search)) {
            continue;
          }
          final key = '${word.ar}:${word.ru}'.toLowerCase();
          if (seen.add(key)) {
            shown.add(word);
          }
        }
        final oneColumn = MediaQuery.sizeOf(context).width < 345 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.45;
        return CustomScrollView(slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            sliver: SliverToBoxAdapter(child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(tr(context, 'Учу слово → вспоминаю → возвращаюсь к нему позже'),
                  style: TextStyle(color: DesignTokens.secondary,
                    fontSize: 12)),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<String>(
                    segments: [
                      ButtonSegment(value: 'learn', label: Text(tr(context, 'Изучаю'))),
                      ButtonSegment(value: 'test', label: Text(tr(context, 'Проверяю'))),
                      ButtonSegment(value: 'review', label: Text(tr(context, 'Повторяю'))),
                    ],
                    selected: {_phase},
                    onSelectionChanged: (next) =>
                        setState(() => _phase = next.single),
                  ),
                ),
                const SizedBox(height: 12),
                if (_phase == 'learn') ...[
                  FilledButton.icon(
                    key: const ValueKey('words-intensive-workout'),
                    onPressed: _intensive,
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: const Text('Тренировать слова и диалоги'),
                  ),
                  const SizedBox(height: 10),
                ],
                if (_phase == 'learn') ...[
                  OutlinedButton.icon(
                    key: const ValueKey('words-dialogue-dictionary'),
                    onPressed: () => Navigator.push(context,
                      MaterialPageRoute<void>(builder: (_) => DictionaryScreen(
                        state: widget.state,
                        lessonId: widget.lessonId,
                        initialDialogueOnly: true,
                      )),
                    ),
                    icon: const Icon(Icons.menu_book_outlined),
                    label: const Text('Словарь из диалогов'),
                  ),
                  const SizedBox(height: 10),
                ],
                if (_phase == 'learn')
                  TextField(
                    key: const ValueKey('words-unified-search'),
                    controller: _query,
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: tr(context, 'Найти арабское слово или перевод'),
                    ),
                  )
                else
                  Panel(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(_phase == 'test'
                          ? 'Вспомни слово без подсказки'
                          : 'Слова, которые пора закрепить',
                        style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 7),
                      Text(_phase == 'test'
                          ? 'Вопросы на перевод, письмо и восприятие на слух. '
                            'Правильность проверяется после ответа.'
                          : 'К повторению: ${review.due} · '
                            'Новых: ${review.newWords}. '
                            'Трудные слова появятся снова.',
                        style: const TextStyle(
                          fontSize: 12, color: DesignTokens.secondary)),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        key: const ValueKey('words-start-practice'),
                        onPressed: _practice,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(tr(context, _phase == 'test'
                            ? 'Проверить себя' : 'Начать повторение')),
                      ),
                    ],
                  )),
                const SizedBox(height: 7),
                if (_phase == 'learn')
                  Text('${shown.length} слов · касание — звук, удержание — подробнее',
                    style: const TextStyle(
                      fontSize: 12, color: DesignTokens.secondary)),
              ],
            )),
          ),
          if (_phase == 'learn' && shown.isEmpty)
            const SliverToBoxAdapter(child: Padding(
              padding: EdgeInsets.all(18),
              child: EmptyState(
                title: 'Слова не найдены',
                message: 'Попробуйте другое слово или откройте урок.',
              ),
            )),
          if (_phase == 'learn')
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid.builder(
                itemCount: shown.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: oneColumn ? 1 : 2,
                  crossAxisSpacing: 12, mainAxisSpacing: 12,
                  childAspectRatio: oneColumn ? 1.6 : .80,
                ),
                itemBuilder: (context, index) {
                  final word = shown[index];
                  final hasPicture = (word.imagePath?.isNotEmpty ?? false) ||
                      IllustratedTerm.hasIllustration(word.ar);
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: ValueKey('unified-word-${word.id}'),
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _speak(word.ar),
                      onLongPress: () => _showWord(word),
                      child: Panel(child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (hasPicture)
                            Expanded(child: Center(
                              child: SemanticWordIllustration(
                                arabic: word.ar,
                                imagePath: word.imagePath,
                                size: oneColumn ? 105 : 96,
                              ),
                            ))
                          else
                            const SizedBox(height: 12),
                          NaskhText(word.ar, size: 25,
                            align: TextAlign.center,
                            color: DesignTokens.emerald),
                          Text(word.ru, textAlign: TextAlign.center,
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 5),
                          const Icon(Icons.volume_up_outlined, size: 19,
                            color: DesignTokens.deepOlive),
                        ],
                      )),
                    ),
                  );
                },
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 150)),
        ]);
      },
    ),
  );
}
