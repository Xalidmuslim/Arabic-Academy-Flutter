import 'package:arabic_academy/core/academy_state.dart';
import 'package:arabic_academy/core/bundled_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('actual bundled materials bootstrap without mixing book and grammar', () async {
    final catalog = await loadBundledAcademyCatalog();
    final modules = catalog['modules'] as List;
    final lessons = catalog['lessons'] as List;
    final grammarTopics = catalog['grammar_topics'] as List;
    expect(modules, hasLength(16));
    expect(lessons.length, greaterThan(24));
    expect(grammarTopics, hasLength(22));
    expect((lessons.first as Map)['id'], 'book1-u1-d1');
    expect((modules.first as Map)['id'], 'u1');

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final state = AcademyState(prefs, catalog);
    addTearDown(state.dispose);
    await state.initialize();
    expect(state.units, hasLength(16));
    expect(state.allLessons.length, lessons.length);
  });
}
