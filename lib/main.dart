import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'core/academy_state.dart';

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
  final loaded = await Future.wait([
    SharedPreferences.getInstance(),
    rootBundle.loadString('assets/content/level1.json'),
    rootBundle.loadString('assets/content/original_lessons.json'),
    rootBundle.loadString('assets/content/grammar.json'),
  ]);
  final catalog = jsonDecode(loaded[1] as String) as Map<String, dynamic>;
  final original = jsonDecode(loaded[2] as String) as Map<String, dynamic>;
  final grammar = jsonDecode(loaded[3] as String) as Map<String, dynamic>;
  catalog['lessons'] = [
    ...(catalog['lessons'] as List).map(
      (x) => {...x as Map, 'module_id': 'u1', 'source': 'original_editorial'},
    ),
    ...original['lessons'] as List,
  ];
  catalog['grammar_topics'] = grammar['topics'];
  final state = AcademyState(loaded[0] as SharedPreferences, catalog);
  await state.initialize();
  runApp(AcademyApp(state: state));
}
