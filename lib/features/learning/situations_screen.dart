import 'package:flutter/material.dart';

import '../../core/academy_state.dart';
import '../../core/performance_probe.dart';
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

  /// The diagnostic toggle updates only visible illustrated cards, avoiding
  /// a full catalog rebuild. Ordinary releases retain the blurred 3D relief.
  Widget _artwork(String path, String? format) {
    final width = format == 'square' ? 218.0 :
        format == 'four_by_three' ? 280.0 : 295.0;
    final height = format == 'square' ? 218.0 :
        format == 'four_by_three' ? 210.0 : 166.0;
    Widget image(bool blur) => FittedStudyArtwork(
      image: AssetImage(path),
      width: width,
      height: height,
      blurSilhouette: blur,
    );
    if (!PerformanceProbe.enabled) return image(true);
    return ValueListenableBuilder<bool>(
      valueListenable: PerformanceProbe.silhouetteBlurEnabled,
      builder: (context, blur, _) => image(blur),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lessons = state.allLessons.where((lesson) {
      final dialog = lesson['dialogue'];
      return dialog is List && dialog.whereType<Map>()
          .where((row) => (row['ar']?.toString() ?? '').isNotEmpty).length >= 2;
    }).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Разговорные ситуации'),
        actions: [
          if (PerformanceProbe.enabled)
            ValueListenableBuilder<bool>(
              valueListenable: PerformanceProbe.silhouetteBlurEnabled,
              builder: (context, blur, _) => IconButton(
                icon: Icon(blur ? Icons.blur_on : Icons.blur_off),
                tooltip: blur
                    ? 'GPU-тест: выключить размытие 3D-тени'
                    : 'GPU-тест: вернуть размытие 3D-тени',
                onPressed: PerformanceProbe.toggleSilhouetteBlur,
              ),
            ),
        ],
      ),
      body: ListView.builder(
        key: const PageStorageKey<String>('situations-dialogue-scroll'),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 150),
        // Long illustrated catalogs should not construct every card in one
        // build. Flutter keeps a repaint boundary around each lazy child.
        cacheExtent: 180,
        itemCount: lessons.isEmpty ? 2 : lessons.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: Text(
                'Оригинал открывается только из вашего личного PDF. '
                'Тренировочные диалоги приложения написаны отдельно и не являются текстом издательства.',
                style: TextStyle(
                  fontSize: 12,
                  color: DesignTokens.secondary,
                ),
              ),
            );
          }
          if (lessons.isEmpty) {
            return const EmptyState(
              title: 'Диалоги не найдены',
              message: 'Добавьте в урок как минимум две реплики.',
            );
          }

          final lesson = lessons[index - 1];
          return Padding(
            key: ValueKey('dialogue-card-${lesson['id']}'),
            padding: const EdgeInsets.only(bottom: 10),
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    lesson['title']?.toString() ?? 'Диалог',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (StudyArtAsset.valid(lesson['dialogue_illustration_asset'])
                      case final imagePath?) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: _artwork(
                        imagePath,
                        lesson['dialogue_illustration_format'] as String?,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    '${(lesson['dialogue'] as List).length} реплик · '
                    'Авторский тренировочный диалог',
                    style: const TextStyle(
                      fontSize: 12,
                      color: DesignTokens.secondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (lesson['pdf_page'] is int) ...[
                    FilledButton.icon(
                      key: ValueKey('original-situation-${lesson['id']}'),
                      icon: const Icon(Icons.menu_book_outlined),
                      label: const Text('Оригинал · мой PDF'),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => OriginalDialogueScreen(lesson: lesson),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.chrome_reader_mode_outlined),
                        label: const Text('Авторский текст'),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => SmartReaderScreen(
                              state: state,
                              lesson: lesson,
                            ),
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        icon: const Icon(Icons.alt_route_outlined),
                        label: const Text('Авторская практика'),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => DialogueJourneyScreen(
                              state: state,
                              lesson: lesson,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
