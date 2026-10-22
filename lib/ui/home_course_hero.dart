import 'package:flutter/material.dart';

import 'neumorphic_components.dart';

/// Reference-style learner hero with actual AcademyState progress.
/// The four established feature tiles and their artwork remain unchanged.
class HomeCourseHero extends StatelessWidget {
  const HomeCourseHero({
    super.key,
    required this.progress,
    required this.completed,
    required this.total,
    required this.onContinue,
    this.nextLessonTitle,
  });

  final double progress;
  final int completed;
  final int total;
  final VoidCallback onContinue;
  final String? nextLessonTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = progress.clamp(0.0, 1.0).toDouble();
    return NeumorphicSurface(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      emphasized: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 74,
                height: 80,
                child: Image.asset(
                  'assets/artwork/home_quick/course.webp',
                  fit: BoxFit.contain,
                  cacheWidth: 256,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.auto_stories_rounded,
                    color: NeumorphicPalette.olive,
                    size: 57,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Мой курс',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Базовый уровень 1',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'serif',
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 16.5,
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Пройдено $completed из $total уроков',
                      maxLines: 2,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 42,
                height: 42,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: value,
                        strokeWidth: 4,
                        strokeCap: StrokeCap.round,
                        color: theme.colorScheme.primary,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                    Text(
                      '${(value * 100).round()}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 6,
              color: theme.colorScheme.primary,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 7),
          SizedBox(
            height: 44,
            child: FilledButton(
              key: const ValueKey('home-continue-button'),
              onPressed: onContinue,
              style: FilledButton.styleFrom(
                backgroundColor: theme.brightness == Brightness.dark
                    ? theme.colorScheme.primary
                    : const Color(0xFF465A34),
                foregroundColor: theme.colorScheme.onPrimary,
                textStyle: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Продолжить'),
                  SizedBox(width: 7),
                  Icon(Icons.chevron_right, size: 21),
                ],
              ),
            ),
          ),
          if (nextLessonTitle != null && nextLessonTitle!.isNotEmpty) ...[
            const SizedBox(height: 7),
            Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.55)),
            InkWell(
              key: const ValueKey('home-next-lesson'),
              onTap: onContinue,
              child: Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 0),
                child: Row(
                  children: [
                    Icon(Icons.menu_book_outlined,
                        size: 23, color: theme.colorScheme.primary),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Следующий урок: $nextLessonTitle',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.25,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(Icons.chevron_right, size: 20,
                        color: theme.colorScheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
