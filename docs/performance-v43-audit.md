# Байна Ядайк v43 — Flutter Performance Audit

**Дата:** 23 октября 2026. **База:** `codex/bayna-v42-textbook-gpu-ab-2026-10-23` at `af575ea7bba12dc1089cc076d8e084fb7d65740c`.
**Резерв:** `backup/bayna-v42-before-full-performance-20261023`. **Кандидат:** `codex/bayna-v43-full-performance-audit-2026-10-23`.
**Без слияния в основную ветку.**

## Что измерено ДО изменений

Только скриншоты с физического телефона, присланные пользователем. Это *разные маршруты/сценарии*, не лабораторные измерения cold/warm start и не доказательство FPS:

| Измерение | Версия и экран | UI p95 | Raster p95 | > 8,33 мс |
|---|---|---:|---:|---:|
| Screenshot #1 | v40, «Разговорные ситуации» | 1,0 мс | 17,2 мс | 171/175 |
| Screenshot #2 | v41, «Разговорные ситуации» | 0,7 мс | 8,6 мс | 11/174 |
| Screenshot #3 | v41, «Учебник» | 2,4 мс | 16,9 мс | 88/148 |
| v43 | *Физических замеров пока нет* | — | — | — |

UI/Raster timing не эквивалентны частоте фактического показа кадров. Кадровый бюджет 120 Гц равен ~8,33 мс; для 60 Гц — ~16,67 мс. В v42 встроен переключатель размытия «Тень ВКЛ/ВЫКЛ» для исследования raster bottleneck на том же устройстве и экране. **Текущее доказательство указывает на raster bottleneck, но не доказывает его единственную причину.**

## Подтвержденная проблема и фактические изменения v43

1. **RED тест:** `test/progress_immutable_catalog_cache_test.dart` падает на v42 при `visitLesson()`: любой progress/setting/bookmark write сбрасывал `_allLessonsSnapshot` и вынуждал заново расширять неизменный каталог при следующем чтении.
2. **GREEN реализация:** `lib/core/academy_state.dart` сохраняет кеш для обычного прогресса, истории, закладок и визуальных настроек. Только четыре операции с авторским каталогом (`save`, `remove`, `restoreLesson`, `reorderLessons`) вызывают `invalidatesLessons: true`. Исходные тексты, список уроков и права доступа не меняются.
3. **Холодный запуск:** при `initialize()` нормализованные данные уже проверены конструктором (`_ensureFields`). Вместо повторного `jsonEncode + jsonDecode` до сохранения выполняется безопасная no-op запись имеющегося снимка. Обычные изменения продолжают использовать transactional copy-on-write, сериализацию и последовательную очередь `_writes`.
4. **UI-тест:** `test/neumorphic_dashboard_test.dart` теперь прокручивает к видимой части интерактивной карточки и проверяет реальный `InkWell`, вместо нажатия по центру внешнего `AnimatedScale`, что ранее создавало фатальное предупреждение hit-test.
5. **Benchmark-инструмент:** `scripts/profile_android_performance.sh` поддерживает `PACKAGE` и `ACTIVITY`, проверяет установку и сохраняет `dumpsys display`. Это позволяет без удаления данных сравнить v42 и отдельно установленный v43.
6. **CI:** `.github/workflows/bayna-v43-full-performance.yml` запускает source-integrity checks, Python checks, analyzer, focused regression, **все** Dart Flutter тестовые файлы четырьмя воспроизводимыми шардами, затем собирает подписанный development ARM64 AOT/R8 APK с проверкой содержимого и package name.

## Архитектурные компоненты проверены, сохранены без лишних вмешательств

- `lib/main.dart`: `runApp` не ожидает сеть; prefs и bundled assets загружаются параллельно; JSON парсится в одном `compute` isolate. Экран загрузки отражает реальное ожидание данных, искусственных задержек нет.
- `lib/app.dart`: theme/locale rebuild только при изменении presentation settings; backend и оформление lazy init после кадра.
- `lib/ui/background_artwork_preloader.dart`: idle + post-frame warmup, max 7 из 9, последовательный decode, pause-on-scroll и отмена timer в dispose.
- `lib/features/learning/textbook_reader_screen.dart`: сохранены bounded 3-page/12 MiB page cache, one-neighbor prefetch, stale result handling, pinch zoom, PDF оригинал; никакого понижения разрешения PDF.
- `lib/ui/fitted_study_artwork.dart` / `lib/ui/course_unit_art.dart`: сохранены WebP, matte-depth, Gaussian silhouette shadow и режим сравнительной диагностики. Без реального blur ON/OFF замера нельзя безопасно удалять или заменять тени.
- `lib/features/learning/home_screen.dart`, `lib/ui/medicine_smooth_motion.dart`: логика Android back, bottom navigation, reduceMotion, scroll restoration оставлена без радикального изменения.
- Android: `isMinifyEnabled = true`, `isShrinkResources = true`, OCR JNI/ProGuard правила и resource verification сохранены.

## Ограничения и безопасность

- GitHub Linux Actions не подключён к физическому Xiaomi. Нельзя выполнить настоящий профиль 5 cold/5 warm, 20 интерактивных переходов, real FPS и memory RSS/leaks на телефоне. Эмулятор без KVM, описанный в предыдущем отчёте, ненадёжен для GPU-бенчмарков.
- `flutter test` **проверяет корректность и регрессии**, но не измеряет GPU raster p95 на устройстве.
- APK собирается с CI-only package `com.example.arabic_academy.perf43`, поэтому устанавливается **рядом с основной версией**, не переносит её progress и не требует удаления исходного приложения. Отдельная подпись development, **не Play Store production**. Не меняйте package ID в реальном релизе без решения задачи подписи/migration.
- Степень улучшения v43 *по физическим замерам* остаётся неизвестной, пока не выполнено сопоставимое измерение. Не утверждать 60/120 FPS без evidence.

## Рекомендуемые замеры на реальном Android

```bash
# Внешний компьютер с adb и подключённым телефоном; не очищает данные.
PACKAGE=com.example.arabic_academy.perf43 \
ACTIVITY=com.example.arabic_academy.MainActivity \
REPORT_DIR=build/performance/v43 \
bash scripts/profile_android_performance.sh
```

Снять минимум 5 cold, 5 warm запусков, 20 переходов (в том числе PDF/назад), UI/raster p50/p95, Memory before/after и framestats. Для сравнения v42 запустить на том же Xiaomi при аналогичных настройках, том же состоянии батареи, а на «Учебнике» выполнить A/B «Тень ВКЛ/ВЫКЛ» с одинаковой прокруткой, дождаться >120 кадров после переключения.
