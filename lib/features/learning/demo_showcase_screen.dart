import 'package:flutter/material.dart';

import '../../core/academy_state.dart';
import '../../core/practice_generator.dart';
import '../../services/backend_service.dart';
import '../../ui/components.dart';
import '../../ui/design_tokens.dart';
import '../../ui/premium_art.dart';
import '../teacher/demo_school_store.dart';
import '../teacher/demo_school_screen.dart';
import '../teacher/demo_student_screen.dart';
import '../teacher/teacher_word_card_studio_screen.dart';
import 'dialogue_journey_screen.dart';
import 'handwriting_screen.dart';
import 'illustrated_dictionary_screen.dart';
import 'practice_center_screen.dart';
import 'progress_screen.dart';
import 'pronunciation_comparison_screen.dart';
import 'smart_reader_screen.dart';
import 'study_calendar_screen.dart';
import 'vocabulary_practice_screen.dart';

/// Presentation navigation never touches purchase entitlements or server roles.
/// Paid online features are shown via offline simulations, never advertised as
/// activated, purchasable or connected to a real remote school.
class DemoShowcaseScreen extends StatelessWidget {
  const DemoShowcaseScreen({
    super.key, required this.learning, required this.school,
    required this.backend,
  });

  final AcademyState learning;
  final DemoSchoolStore school;
  final BackendService backend;

  void _go(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute<void>(
      builder: (_) => screen,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final examples = learning.allLessons;
    final dialogues = examples.where((lesson) {
      final data = lesson['dialogue'];
      return data is List && data.length >= 2;
    }).toList();
    final firstDialogue = dialogues.isEmpty ? null : dialogues.first;
    final compact = MediaQuery.sizeOf(context).width < 345 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.5;
    final entries = <({String title, String subtitle, String art, Widget? page})>[
      (title: 'Слова в образах', subtitle: 'Иллюстрации и переводы',
        art: 'vocabulary', page: IllustratedDictionaryScreen(state: learning)),
      (title: 'Произношение', subtitle: 'Слушать и записывать',
        art: 'microphone', page: PronunciationComparisonScreen(state: learning)),
      (title: 'Карта знаний', subtitle: 'Навыки и ошибки',
        art: 'analytics', page: LearnerProgressScreen(state: learning)),
      (title: 'Диалоги', subtitle: 'Разговорные ситуации',
        art: 'students', page: firstDialogue == null ? null :
            DialogueJourneyScreen(state: learning, lesson: firstDialogue)),
      (title: 'Арабское письмо', subtitle: 'Буквы и обводка',
        art: 'homework', page: HandwritingScreen(state: learning)),
      (title: 'Умное чтение', subtitle: 'Текст, звук, перевод',
        art: 'books', page: firstDialogue == null ? null :
            SmartReaderScreen(state: learning, lesson: firstDialogue)),
      (title: 'Учебный календарь', subtitle: 'Ритм занятий',
        art: 'homework', page: StudyCalendarScreen(state: learning)),
      (title: 'Работа над ошибками', subtitle: 'Разбор и повторение',
        art: 'tests', page: PracticeSessionScreen(
          state: learning, mode: PracticeMode.mistakes)),
      (title: 'Запоминание', subtitle: 'Интервальное повторение',
        art: 'vocabulary', page: VocabularyPracticeScreen(state: learning)),
      (title: 'Практика', subtitle: 'Викторины и контрольные',
        art: 'tests', page: Scaffold(
          appBar: AppBar(title: const Text('Практика')),
          body: PracticeCenterScreen(state: learning))),
      (title: 'Домашние и голосовые', subtitle: 'Работы ученицы',
        art: 'homework', page: DemoStudentSchoolScreen(
          school: school, learning: learning)),
      (title: 'Эфиры и группы', subtitle: 'Учебные встречи · симуляция',
        art: 'video', page: DemoStudentSchoolScreen(
          school: school, learning: learning, initialTab: 'sessions')),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Демонстрация академии')),
      body: CustomScrollView(slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          sliver: SliverToBoxAdapter(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Panel(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ПОЛНЫЙ ДЕМОНСТРАЦИОННЫЙ ОБЗОР',
                    style: TextStyle(fontWeight: FontWeight.w800,
                      color: DesignTokens.deepOlive)),
                  SizedBox(height: 6),
                  Text('Все локальные учебные инструменты доступны без оплаты. '
                    'Оценки и ученицы вымышлены. Платные серверные возможности '
                    'показываются только как симуляция — подписка, доступ '
                    'к чужим данным и настоящие эфиры не активируются.'),
                ],
              )),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: FilledButton.icon(
                  key: const ValueKey('showcase-teacher-dashboard'),
                  onPressed: () => _go(context, DemoSchoolScreen(
                    school: school, learning: learning, backend: backend)),
                  icon: const Icon(Icons.school_outlined),
                  label: const Text('Кабинет учительницы'),
                )),
              ]),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const ValueKey('showcase-word-cards'),
                onPressed: () => _go(context,
                  TeacherWordCardStudioScreen(state: learning)),
                icon: const Icon(Icons.collections_bookmark_outlined),
                label: const Text('Создать карточки слов'),
              ),
              const SizedBox(height: 14),
              Text('Все учебные возможности',
                style: Theme.of(context).textTheme.titleLarge),
            ],
          )),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid.builder(
            itemCount: entries.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: compact ? 1 : 2,
              crossAxisSpacing: 12, mainAxisSpacing: 12,
              childAspectRatio: compact ? 2.05 : .78,
            ),
            itemBuilder: (context, i) {
              final item = entries[i];
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  key: ValueKey('showcase-feature-$i'),
                  borderRadius: BorderRadius.circular(22),
                  onTap: () {
                    if (item.page == null) {
                      notice(context, 'Нет диалога в выбранных учебных материалах.');
                    } else {
                      _go(context, item.page!);
                    }
                  },
                  child: Panel(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(child: Center(child:
                        ArtworkIcon(item.art, size: compact ? 64 : 87))),
                      const SizedBox(height: 6),
                      Text(item.title, textAlign: TextAlign.center,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(item.subtitle, textAlign: TextAlign.center,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11,
                          color: DesignTokens.secondary)),
                    ],
                  )),
                ),
              );
            },
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 150)),
      ]),
    );
  }
}
