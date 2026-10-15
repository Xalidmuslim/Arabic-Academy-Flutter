import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('first six editorial dialogues use distinct standalone 3D illustrations', () async {
    const expected = <String, String>{
      'book1-u1-d1': 'dialogue_u1_d1_greeting',
      'book1-u1-d2': 'dialogue_u1_d2_origins',
      'book1-u1-d3': 'dialogue_u1_d3_teacher',
      'book1-u2-d1': 'dialogue_u2_d1_family',
      'book1-u3-d1': 'dialogue_u3_d1_apartment',
      'book1-u4-d1': 'dialogue_u4_d1_morning',
    };
    final catalog = jsonDecode(
      await rootBundle.loadString('assets/content/book1_original_dialogues.json'),
    ) as Map<String, dynamic>;
    final lessons = (catalog['lessons'] as List).cast<Map<String, dynamic>>();
    final mapped = <String>{};
    for (final entry in expected.entries) {
      final lesson = lessons.singleWhere((l) => l['id'] == entry.key);
      final asset = lesson['dialogue_illustration_asset'] as String?;
      expect(asset, 'assets/artwork/lesson_generated/${entry.value}.webp');
      expect(mapped.add(asset!), isTrue, reason: 'Never reuse images between dialogues');
      final bytes = await rootBundle.load(asset);
      expect(bytes.lengthInBytes, greaterThan(20000));
      expect(bytes.getUint8(0), 0x52, reason: 'Original WebP RIFF header');
      expect(bytes.getUint8(1), 0x49);
    }
  });
}
