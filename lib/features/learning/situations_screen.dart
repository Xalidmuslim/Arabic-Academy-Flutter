import 'package:flutter/material.dart';

import '../../core/academy_state.dart';
import '../../ui/components.dart';
import '../../ui/design_tokens.dart';
import '../../ui/fitted_study_artwork.dart';
import '../../ui/study_art_asset.dart';
import 'smart_reader_screen.dart';
import 'dialogue_journey_screen.dart';
import 'original_dialogue_screen.dart';

/// Conversation scenarios follow real editorial dialogues already present in
/// the student's lesson library. No unverified AI responses are invented.
class SituationsScreen extends StatelessWidget {
  const SituationsScreen({super.key, required this.state});
  final AcademyState state;

  @override
  Widget build(BuildContext context) {
    final lessons = state.allLessons.where((lesson) {
      final dialog = lesson['dialogue'];
      return dialog is List && dialog.whereType<Map>()
          .where((row) => (row['ar']?.toString() ?? '').isNotEmpty).length >= 2;
    }).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Разговорные ситуации')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 150),
        children: [
          const Text(
            'Оригинал открывается только из вашего личного PDF. '
            'Тренировочные диалоги приложения написаны отдельно и не являются текстом издательства.',
            style: TextStyle(fontSize: 12, color: DesignTokens.secondary),
          ),
          const SizedBox(height: 14),
          if (lessons.isEmpty)
            const EmptyState(title: 'Диалоги не найдены',
              message: 'Добавьте в урок как минимум две реплики.'),
          for (final lesson in lessons)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(lesson['title']?.toString() ?? 'Диалог',
                      style: Theme.of(context).textTheme.titleMedium),
                    if (StudyArtAsset.valid(lesson['dialogue_illustration_asset']) case final imagePath?) ...[
                      const SizedBox(height: 8),
                      Center(child: FittedStudyArtwork(
                        image: AssetImage(imagePath),
            width: lesson['dialogue_illustration_format'] == 'square' ? 218 :
                lesson['dialogue_illustration_format'] == 'four_by_three' ? 280 : 295,
            height: lesson['dialogue_illustration_format'] == 'square' ? 218 :
                lesson['dialogue_illustration_format'] == 'four_by_three' ? 210 : 166,
                      )),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      '${(lesson['dialogue'] as List).length} реплик · '
                      'Авторский тренировочный диалог',
                      style: const TextStyle(
                        fontSize: 12, color: DesignTokens.secondary),
                    ),
                    const SizedBox(height: 10),
                    if (lesson['pdf_page'] is int) ...[
                      FilledButton.icon(
                        key: ValueKey('original-situation-${lesson['id']}'),
                        icon: const Icon(Icons.menu_book_outlined),
                        label: const Text('Оригинал · мой PDF'),
                        onPressed: () => Navigator.push(context,
                          MaterialPageRoute<void>(
                            builder: (_) => OriginalDialogueScreen(
                              lesson: lesson),
                          )),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.chrome_reader_mode_outlined),
                        label: const Text('Авторский текст'),
                        onPressed: () => Navigator.push(context,
                          MaterialPageRoute<void>(
                            builder: (_) => SmartReaderScreen(
                              state: state, lesson: lesson),
                          )),
                      ),
                      FilledButton.icon(
                        icon: const Icon(Icons.alt_route_outlined),
                        label: const Text('Авторская практика'),
                        onPressed: () => Navigator.push(context,
                          MaterialPageRoute<void>(
                            builder: (_) => DialogueJourneyScreen(
                              state: state,
                              lesson: lesson,
                            ),
                          )),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
