import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Map<String, dynamic> catalog;
  setUpAll(() {
    catalog = jsonDecode(File('assets/content/level1.json').readAsStringSync()) as Map<String, dynamic>;
  });

  test('Eight units, first free, seven restricted', () {
    final units = catalog['modules'] as List;
    expect(units.length, 8);
    expect(units.where((x) => x['access_default'] == 'free').length, 1);
  });

  test('Three original draft lessons have core educational elements', () {
    final lessons = catalog['lessons'] as List;
    expect(lessons.length, 3);
    for (final dynamic item in lessons) {
      final lesson = item as Map<String, dynamic>;
      expect((lesson['dialogue'] as List), isNotEmpty);
      expect((lesson['vocabulary'] as List), isNotEmpty);
      expect((lesson['options'] as List), isNotEmpty);
      expect(lesson['title_ar'], isNotEmpty);
      final answer = lesson['correct'] as int;
      expect(answer, inInclusiveRange(0, (lesson['options'] as List).length - 1));
    }
  });
}
