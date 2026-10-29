import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:arabic_academy/core/academy_state.dart';
import 'package:arabic_academy/features/exercises/exercises.dart';
import 'package:arabic_academy/features/learning/course_screen.dart';
import 'package:arabic_academy/features/learning/home_screen.dart';
import 'package:arabic_academy/features/learning/lesson_screen.dart';
import 'package:arabic_academy/features/learning/library_screens.dart';
import 'package:arabic_academy/features/learning/progress_screen.dart';
import 'package:arabic_academy/features/learning/settings_screen.dart';
import 'package:arabic_academy/features/teacher/teacher_editor.dart';
import 'package:arabic_academy/services/backend_service.dart';
import 'package:arabic_academy/ui/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Flutter's actual tester rasterizer, with production shadows enabled.
// These are NOT Android/device screenshots or pixel-difference goldens.
class _VisualBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

const _boundaryKey = ValueKey('visual-acceptance-boundary');
const _profiles = [
  (name: 'ru-390', language: 'ru', width: 390.0, height: 844.0, scale: 1.0),
  (name: 'ar-390', language: 'ar', width: 390.0, height: 844.0, scale: 1.0),
  (name: 'ru-320-2x', language: 'ru', width: 320.0, height: 800.0, scale: 2.0),
  (name: 'ar-320-2x', language: 'ar', width: 320.0, height: 800.0, scale: 2.0),
];
const _screens = [
  'home',
  'courses',
  'lesson',
  'exercise',
  'dictionary',
  'grammar',
  'progress',
  'settings',
  'localteacher',
  'editor',
  'lesson-dialogue',
  'dictionary-detail',
  'grammar-detail',
];
Map<String, dynamic> _catalog = {};
String? get _output => Platform.environment['VISUAL_ACCEPTANCE_DIR'];

Future<void> _writeJson(String name, Map<String, dynamic> data) async {
  if (_output == null) return;
  await Directory(_output!).create(recursive: true);
  await File(
    '$_output/$name.json',
  ).writeAsString('${const JsonEncoder.withIndent('  ').convert(data)}\n');
}

Future<void> _loadRealAssets() async {
  for (final font in {
    'Manrope': 'assets/fonts/Manrope.ttf',
    'NotoNaskhArabic': 'assets/fonts/NotoNaskhArabic.ttf',
    'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
  }.entries) {
    final loader = FontLoader(font.key)..addFont(rootBundle.load(font.value));
    await loader.load();
  }
  final data = await Future.wait([
    rootBundle.loadString('assets/content/level1.json'),
    rootBundle.loadString('assets/content/original_lessons.json'),
    rootBundle.loadString('assets/content/grammar.json'),
  ]);
  final level = jsonDecode(data[0]) as Map<String, dynamic>;
  final original = jsonDecode(data[1]) as Map<String, dynamic>;
  final grammar = jsonDecode(data[2]) as Map<String, dynamic>;
  // Same assembly as main.dart. No synthetic lessons, statistics or Arabic text.
  _catalog = {
    ...level,
    'lessons': [
      for (final lesson in level['lessons'] as List)
        {...lesson as Map, 'module_id': 'u1', 'source': 'original_editorial'},
      ...original['lessons'] as List,
    ],
    'grammar_topics': grammar['topics'],
  };
  expect((_catalog['lessons'] as List).length, 15);
  expect((_catalog['grammar_topics'] as List).length, 22);
  await _writeJson('run', {
    'renderer': 'Flutter widget tester engine; NOT Android/device screenshots',
    'expected_cases': _profiles.length * _screens.length,
    'screens': _screens,
    'profiles': [for (final profile in _profiles) profile.name],
    'lessons': 15,
    'grammar_topics': 22,
    'fonts': ['Manrope', 'NotoNaskhArabic', 'MaterialIcons'],
    'shadows': 'enabled',
    'backend': 'explicitly unconfigured; local screens only',
  });
}

Widget _screen(String name, AcademyState state, BackendService backend) {
  final lesson = state.allLessons.first;
  return switch (name) {
    'home' || 'localteacher' => HomeScreen(state: state, backend: backend),
    'courses' => UnitScreen(state: state, backend: backend),
    'lesson' || 'lesson-dialogue' => LessonScreen(
      state: state,
      lesson: lesson,
      backend: backend,
      initialTab: name == 'lesson-dialogue' ? 2 : 0,
    ),
    'exercise' => Scaffold(
      appBar: AppBar(title: const Text('Упражнение')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ExerciseRunner(
            exercise: Exercise.fromJson(
              Map<String, dynamic>.from(
                ((_catalog['grammar_topics'] as List).first
                        as Map)['exercises'][0]
                    as Map,
              ),
            ),
            onCompleted: (_, _) {},
          ),
        ],
      ),
    ),
    'dictionary' || 'dictionary-detail' => DictionaryScreen(state: state),
    'grammar' || 'grammar-detail' => GrammarScreen(state: state),
    'progress' => LearnerProgressScreen(state: state),
    'settings' => SettingsScreen(state: state, backend: backend),
    'editor' => TeacherEditor(state: state, original: lesson),
    _ => throw ArgumentError.value(name, 'screen'),
  };
}

Future<void> _settle(WidgetTester tester) async {
  // Apply navigation/setState before enumerating newly inserted image widgets.
  await tester.pump();
  // Preference writes and real image codecs must finish outside the fake clock.
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
    await Future<void>.delayed(Duration.zero);
  });
  await tester.pumpAndSettle(const Duration(milliseconds: 50));
}

Future<String?> _capture(WidgetTester tester, String name) async {
  if (_output == null) return null;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundaryKey),
  );
  expect(boundary.debugNeedsPaint, isFalse);
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) throw StateError('Flutter engine produced no PNG bytes');
      await File('$_output/$name.png').writeAsBytes(
        png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
      );
    } finally {
      image.dispose();
    }
  });
  return '$name.png';
}

ScrollableState? _verticalScroller() {
  for (final element in find.byType(Scrollable).evaluate()) {
    final state = (element as StatefulElement).state as ScrollableState;
    if (axisDirectionToAxis(state.axisDirection) == Axis.vertical &&
        state.position.hasContentDimensions) {
      return state;
    }
  }
  return null;
}

void main() {
  _VisualBinding();
  final previousHitTestPolicy = WidgetController.hitTestWarningShouldBeFatal;
  WidgetController.hitTestWarningShouldBeFatal = true;
  tearDownAll(
    () => WidgetController.hitTestWarningShouldBeFatal = previousHitTestPolicy,
  );
  setUpAll(_loadRealAssets);
  for (final profile in _profiles) {
    for (final name in _screens) {
      testWidgets('visual ${profile.name} $name', (tester) async {
        final caseName = '${profile.name}-$name';
        final errors = <Map<String, String>>[];
        final captures = <String>[];
        var phase = 'mount';
        var reachedEnd = false;
        var scrollSteps = 0;
        final previousErrorHandler = FlutterError.onError;
        FlutterError.onError = (details) {
          errors.add({'phase': phase, 'details': details.toString()});
          previousErrorHandler?.call(details);
        };
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(profile.width, profile.height);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        AcademyState? state;
        final backend = BackendService(
          config: const IntegrationConfig(supabaseUrl: '', supabaseAnonKey: ''),
        );
        void drainExceptions() {
          // Preserve normal Flutter test logging, then fail with all diagnostics.
          while (tester.takeException() != null) {}
        }

        try {
          await tester.runAsync(() async {
            SharedPreferences.setMockInitialValues({'welcome_seen': true});
            state = AcademyState(
              await SharedPreferences.getInstance(),
              jsonDecode(jsonEncode(_catalog)) as Map<String, dynamic>,
            );
            await state!.initialize();
            await state!.setSetting('language', profile.language);
          });
          await tester.pumpWidget(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: DesignTokens.theme().copyWith(
                platform: TargetPlatform.android,
              ),
              locale: Locale(profile.language),
              supportedLocales: const [Locale('ru'), Locale('ar')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(profile.scale),
                  disableAnimations: true,
                ),
                child: RepaintBoundary(key: _boundaryKey, child: child),
              ),
              home: _screen(name, state!, backend),
            ),
          );
          await _settle(tester);
          drainExceptions();
          if (name == 'localteacher') {
            // v29 uses a bottom sheet rather than the old PopupMenuButton.
            final switcher = find.byKey(const ValueKey('home-switch-role'));
            await tester.ensureVisible(switcher);
            await tester.tap(switcher);
            await _settle(tester);
            await tester.tap(find.text('Учительница').last);
            await _settle(tester);
          } else if (name == 'dictionary-detail') {
            final target = find.byKey(
              ValueKey('word:${state!.allLessons.first['id']}:0'),
            );
            // The dictionary deliberately uses lazy slivers: a word below
            // the viewport is not in the tree until scrolled into view.
            if (target.evaluate().isEmpty) {
              await tester.scrollUntilVisible(
                target, 160, scrollable: find.byType(Scrollable).first,
              );
            } else {
              await tester.ensureVisible(target);
            }
            await _settle(tester);
            await tester.tap(target);
            await _settle(tester);
            expect(
              find.byKey(const ValueKey('dictionary-search')),
              findsNothing,
              reason: 'Dictionary detail must open before it is captured',
            );
            expect(
              find.byTooltip('Синтез речи устройства — арабский голос'),
              findsOneWidget,
            );
          } else if (name == 'grammar-detail') {
            final topic = (_catalog['grammar_topics'] as List).first as Map;
            final target = find.byKey(ValueKey('grammar:${topic['id']}'));
            await tester.ensureVisible(target);
            await _settle(tester);
            await tester.tap(target);
            await _settle(tester);
            expect(
              find.byKey(const ValueKey('grammar-search')),
              findsNothing,
              reason: 'Grammar detail must open before it is captured',
            );
            expect(find.text(topic['theory'] as String), findsOneWidget);
          }
          drainExceptions();
          final context = tester.element(find.byKey(_boundaryKey));
          expect(
            Directionality.of(context),
            profile.language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          );
          expect(
            MediaQuery.textScalerOf(context).scale(16),
            16 * profile.scale,
          );
          phase = 'start';
          final first = await _capture(tester, '$caseName-start');
          if (first != null) captures.add(first);
          // Walk every lazy vertical row, not just the initially visible frame.
          for (; scrollSteps < 80; scrollSteps++) {
            final scroller = _verticalScroller();
            if (scroller == null || scroller.position.extentAfter < 1) {
              reachedEnd = true;
              break;
            }
            phase = 'scroll-$scrollSteps';
            final position = scroller.position;
            position.jumpTo(
              (position.pixels + position.viewportDimension * 0.7).clamp(
                position.minScrollExtent,
                position.maxScrollExtent,
              ),
            );
            await _settle(tester);
            drainExceptions();
            if (scrollSteps == 0) {
              final middle = await _capture(tester, '$caseName-scroll');
              if (middle != null) captures.add(middle);
            }
          }
          phase = 'end';
          final last = await _capture(tester, '$caseName-end');
          if (last != null) captures.add(last);
          expect(
            reachedEnd,
            isTrue,
            reason: 'Lazy content inspection exceeded 80 scroll steps',
          );
        } catch (error, stack) {
          errors.add({'phase': phase, 'details': '$error\n$stack'});
          rethrow;
        } finally {
          phase = 'dispose';
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          drainExceptions();
          state?.dispose();
          backend.dispose();
          FlutterError.onError = previousErrorHandler;
          await tester.runAsync(
            () => _writeJson(caseName, {
              'renderer':
                  'Flutter widget tester engine; NOT Android/device screenshot',
              'screen': name,
              'profile': profile.name,
              'width': profile.width,
              'height': profile.height,
              'device_pixel_ratio': 1,
              'text_scale': profile.scale,
              'locale': profile.language,
              'direction': profile.language == 'ar' ? 'rtl' : 'ltr',
              'status': errors.isEmpty && reachedEnd ? 'passed' : 'failed',
              'scroll_steps': scrollSteps,
              'reached_end': reachedEnd,
              'captures': captures,
              'errors': errors,
            }),
          );
        }
        expect(
          errors,
          isEmpty,
          reason:
              '$caseName has runtime/layout errors; inspect its capture and JSON report',
        );
      });
    }
  }
}
