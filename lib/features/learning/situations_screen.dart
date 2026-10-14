import 'package:flutter/material.dart';

import '../../core/academy_state.dart';
import '../../ui/components.dart';
import '../../ui/design_tokens.dart';
import '../../ui/dialogue_scene_illustration.dart';
import 'smart_reader_screen.dart';
import 'dialogue_journey_screen.dart';

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
            'Практикуйте настоящие диалоги из материалов вашего курса. '
            'Каждая следующая реплика проверяется по учебному тексту.',
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
                    if (DialogueSceneIllustration.sceneFor(
                        lesson['title']?.toString() ?? '') != null) ...[
                      const SizedBox(height: 8),
                      DialogueSceneIllustration(
                        setting: lesson['title']?.toString() ?? ''),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      '${(lesson['dialogue'] as List).length} реплик · '
                      'Практика по учебному материалу',
                      style: const TextStyle(
                        fontSize: 12, color: DesignTokens.secondary),
                    ),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.chrome_reader_mode_outlined),
                        label: const Text('Читать и слушать'),
                        onPressed: () => Navigator.push(context,
                          MaterialPageRoute<void>(
                            builder: (_) => SmartReaderScreen(
                              state: state, lesson: lesson),
                          )),
                      ),
                      FilledButton.icon(
                        icon: const Icon(Icons.alt_route_outlined),
                        label: const Text('Диалог с вариантами'),
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
