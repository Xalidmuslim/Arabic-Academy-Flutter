import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/academy_state.dart';
import '../../services/teacher_word_image_store.dart';
import '../../ui/components.dart';
import '../../ui/design_tokens.dart';
import '../../ui/teacher_word_image_picker.dart';
import '../learning/illustrated_dictionary_screen.dart';
import '../learning/vocabulary_practice_screen.dart';

/// Compact teacher-owned image/word deck, saved as a published LOCAL lesson.
/// It is visible to the student study engine but never uploaded to a server.
class TeacherWordCardStudioScreen extends StatefulWidget {
  const TeacherWordCardStudioScreen({super.key, required this.state});
  final AcademyState state;

  @override
  State<TeacherWordCardStudioScreen> createState() =>
      _TeacherWordCardStudioScreenState();
}

class _TeacherWordCardStudioScreenState
    extends State<TeacherWordCardStudioScreen> {
  static const deckId = 'teacher_picture_cards_v1';
  static const deckTitle = 'Карточки учительницы';
  bool _saving = false;

  Map<String, dynamic>? get _deck {
    for (final lesson in widget.state.teacherLessons) {
      if (lesson['id'] == deckId) return lesson;
    }
    return null;
  }

  List<Map<String, dynamic>> get _cards {
    final source = _deck?['vocabulary'];
    if (source is! List) return <Map<String, dynamic>>[];
    return source.whereType<Map>().map((x) =>
      Map<String, dynamic>.from(x)).toList();
  }

  Future<void> _edit({Map<String, dynamic>? old}) async {
    if (_saving) return;
    final ar = TextEditingController(text: old?['ar'] as String? ?? '');
    final ru = TextEditingController(text: old?['ru'] as String? ?? '');
    final example = TextEditingController(
      text: old?['example_ar'] as String? ?? '');
    final form = GlobalKey<FormState>();
    Uint8List? photo;
    var clearPhoto = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(old == null ? 'Новая карточка слова' : 'Изменить карточку'),
        content: SizedBox(
          width: 430,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    key: const ValueKey('word-card-arabic'),
                    controller: ar,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(fontFamily: 'NotoNaskhArabic',
                      fontSize: 24),
                    decoration: const InputDecoration(
                      labelText: 'Арабское слово'),
                    validator: (v) => v?.trim().isEmpty != false
                        ? 'Введите слово' : null,
                  ),
                  const SizedBox(height: 9),
                  TextFormField(
                    key: const ValueKey('word-card-translation'),
                    controller: ru,
                    decoration: const InputDecoration(
                      labelText: 'Русский перевод'),
                    validator: (v) => v?.trim().isEmpty != false
                        ? 'Введите перевод' : null,
                  ),
                  const SizedBox(height: 9),
                  TextFormField(
                    controller: example,
                    textDirection: TextDirection.rtl,
                    decoration: const InputDecoration(
                      labelText: 'Пример (по желанию)'),
                  ),
                  const SizedBox(height: 15),
                  TeacherWordImagePicker(
                    initialPath: old?['image_path'] as String?,
                    onChanged: (bytes, removed) {
                      photo = bytes;
                      clearPhoto = removed;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Отмена')),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(dialog, true);
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    final arabic = ar.text.trim();
    final translation = ru.text.trim();
    final usage = example.text.trim();
    ar.dispose();
    ru.dispose();
    example.dispose();
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      var imagePath = clearPhoto ? '' :
          (old?['image_path'] as String? ?? '');
      if (photo != null) {
        imagePath = await TeacherWordImageStore.save(photo!);
      }
      final records = _cards;
      final item = <String, dynamic>{
        ...?old,
        'id': old?['id'] ?? AcademyState.newId(),
        'ar': arabic,
        'ru': translation,
        'example_ar': usage,
        'image_path': imagePath,
      };
      final index = records.indexWhere((x) => x['id'] == item['id']);
      if (index < 0) {
        records.add(item);
      } else {
        records[index] = item;
      }
      await _saveDeck(records);
      if (mounted) notice(context, 'Карточка сохранена и доступна для практики.');
    } catch (error) {
      if (mounted) notice(context, 'Не удалось сохранить карточку: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveDeck(List<Map<String, dynamic>> cards) =>
      widget.state.save({
        ...?_deck,
        'id': deckId,
        'title': deckTitle,
        'description': 'Слова и иллюстрации, созданные учительницей',
        'published': true,
        'free': true,
        'vocabulary': cards,
      });

  Future<void> _delete(Map<String, dynamic> card) async {
    final accept = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Удалить карточку?'),
        content: const Text('Карточка исчезнет из подборки. '
          'История изучения остальных слов сохранится.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Удалить')),
        ],
      ),
    );
    if (accept != true || !mounted) return;
    await guardedAction(context, () => _saveDeck(
      _cards.where((x) => x['id'] != card['id']).toList(),
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Карточки слов')),
    body: AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        final cards = _cards;
        final single = MediaQuery.sizeOf(context).width < 345 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.5;
        return CustomScrollView(slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 15),
            sliver: SliverToBoxAdapter(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${cards.length} карточек · локальная коллекция',
                  style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 7),
                const Text('Добавьте арабское слово, перевод и реальный рисунок. '
                  'Карточки сразу доступны ученице в иллюстрированном словаре '
                  'и системе запоминания.',
                  style: TextStyle(fontSize: 12, color: DesignTokens.secondary)),
                const SizedBox(height: 10),
                FilledButton.icon(
                  key: const ValueKey('word-card-add'),
                  onPressed: _saving ? null : () => _edit(),
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Добавить карточку'),
                ),
                const SizedBox(height: 7),
                if (cards.isNotEmpty)
                  FilledButton.tonalIcon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => VocabularyPracticeScreen(
                        state: widget.state, lessonId: deckId))),
                    icon: const Icon(Icons.play_arrow_outlined),
                    label: const Text('Проверить карточки'),
                  ),
              ],
            )),
          ),
          if (cards.isEmpty)
            const SliverToBoxAdapter(child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: EmptyState(
                title: 'Добавьте первое слово',
                message: 'Сначала выберите изображение и введите текст.'),
            )),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid.builder(
              itemCount: cards.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: single ? 1 : 2,
                crossAxisSpacing: 12, mainAxisSpacing: 12,
                childAspectRatio: single ? 1.55 : .64,
              ),
              itemBuilder: (context, index) {
                final card = cards[index];
                return InkWell(
                  onTap: () => _edit(old: card),
                  borderRadius: BorderRadius.circular(20),
                  child: Panel(child: Column(
                    children: [
                      Expanded(child: SemanticWordIllustration(
                        arabic: card['ar']?.toString() ?? '',
                        imagePath: card['image_path'] as String?,
                        size: single ? 90 : 80,
                      )),
                      NaskhText(card['ar']?.toString() ?? '',
                        size: 25, align: TextAlign.center),
                      Text(card['ru']?.toString() ?? '',
                        textAlign: TextAlign.center,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                      Align(alignment: Alignment.centerRight,
                        child: IconButton(
                          tooltip: 'Удалить карточку',
                          icon: const Icon(Icons.delete_outline),
                          iconSize: 20,
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _delete(card),
                        )),
                    ],
                  )),
                );
              },
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 140)),
        ]);
      },
    ),
  );
}
