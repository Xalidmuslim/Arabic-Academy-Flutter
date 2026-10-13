import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/academy_state.dart';
import 'core/bundled_catalog.dart';

export 'app.dart';
export 'core/academy_state.dart';
export 'features/learning/home_screen.dart';
export 'features/learning/course_screen.dart';
export 'features/learning/lesson_screen.dart';
export 'features/learning/progress_screen.dart';
export 'features/teacher/teacher_editor.dart';
export 'ui/components.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // Load files by explicit names; no positional JSON array indexes.
    // Never let a data parsing error silently strand Android on its splash.
    final loaded = await Future.wait<Object>([
      SharedPreferences.getInstance(),
      loadBundledAcademyCatalog(),
    ]);
    final state = AcademyState(
      loaded[0] as SharedPreferences,
      loaded[1] as Map<String, dynamic>,
    );
    await state.initialize();
    runApp(AcademyApp(state: state));
  } catch (error, stackTrace) {
    FlutterError.reportError(FlutterErrorDetails(
      exception: error,
      stack: stackTrace,
      library: 'academy startup',
    ));
    runApp(MaterialApp(
      title: 'Байна Ядайк',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8F4E8),
      ),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 42),
                  const SizedBox(height: 16),
                  const Text(
                    'Не удалось загрузить учебные материалы.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: main,
                    child: const Text('Повторить запуск'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ));
  }
}
