import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bayna_dictionary/core/dictionary_data.dart';
import 'package:bayna_dictionary/ui/dictionary_shell.dart';

const captureUxGoldens = bool.fromEnvironment('CAPTURE_UX_GOLDENS');

const preview = [
  Word('book', 'كِتَابٌ', 'مَجْمُوعَةٌ مِنَ الصَّفَحَاتِ',
      [], [], ['اِسْمٌ'], [], [], '', [],
      bookNumber: 1, chapterNumber: 1),
  Word('home', 'بَيْتٌ', 'مَكَانٌ يَسْكُنُ فِيهِ النَّاسُ',
      [], [], ['اِسْمٌ'], [], ['هٰذَا بَيْتٌ جَمِيلٌ'], '', [],
      bookNumber: 1, chapterNumber: 1),
  Word('school', 'مَدْرَسَةٌ', 'مَكَانٌ لِلتَّعْلِيمِ',
      [], [], ['اِسْمٌ'], [], [], '', [],
      bookNumber: 1, chapterNumber: 2),
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Generate representative UX screenshots at phone size',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const DictionaryApp(previewWords: preview));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp),
      matchesGoldenFile('goldens/ux-home-light.png'));

    await tester.tap(find.byKey(const Key('all-words-tile')));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp),
      matchesGoldenFile('goldens/ux-list-light.png'));

    await tester.tap(find.byType(WordTile).first);
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp),
      matchesGoldenFile('goldens/ux-reader-light.png'));
  }, skip: !captureUxGoldens);

  testWidgets('Generate dark theme home screenshot',
      (tester) async {
    SharedPreferences.setMockInitialValues({'dictionary_theme_v2': 'dark'});
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const DictionaryApp(previewWords: preview));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp),
      matchesGoldenFile('goldens/ux-home-dark.png'));
  }, skip: !captureUxGoldens);
}
