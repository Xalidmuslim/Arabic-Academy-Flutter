import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:arabic_academy/services/teacher_word_image_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:arabic_academy/core/academy_state.dart';
import 'package:arabic_academy/core/vocabulary_practice.dart';
import 'package:arabic_academy/features/teacher/demo_school_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('demo showcase fills all nine pupils without overwriting real demo edits',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final school = DemoSchoolStore(prefs);
    addTearDown(school.dispose);
    expect(school.students.length, 9);
    expect(school.skillAssessments, isEmpty);
    final original = school.submissions.first['grade'];

    await school.populateShowcase();
    expect(school.skillAssessmentsFor('s1').length, 7);
    expect(school.skillAssessmentsFor('s9').length, 7);
    expect(school.submissions.first['grade'], original);
    expect(school.assignments.length, greaterThan(2));
    expect(school.submissions.length, greaterThan(1));

    final gradeCount = school.submissions.length;
    final rubricCount = school.skillAssessments.length;
    await school.populateShowcase();
    expect(school.submissions.length, gradeCount);
    expect(school.skillAssessments.length, rubricCount);

    final restored = DemoSchoolStore(prefs);
    addTearDown(restored.dispose);
    expect(restored.skillAssessments.length, rubricCount);
  });

  test('picture import validates actual image bytes and rejects oversized files', () {
    expect(TeacherWordImageStore.extension(Uint8List.fromList(
      [137, 80, 78, 71, 13, 10, 26, 10, 0, 0])), 'png');
    expect(TeacherWordImageStore.extension(Uint8List.fromList(
      [255, 216, 255, 224])), 'jpg');
    expect(() => TeacherWordImageStore.extension(Uint8List.fromList(
      [47, 47, 47, 0, 0])), throwsFormatException);
    expect(() => TeacherWordImageStore.extension(Uint8List(2 * 1024 * 1024 + 1)),
      throwsFormatException);
  });

  test('teacher card picture path is propagated into vocabulary practice', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final learning = AcademyState(prefs, {'modules': [], 'lessons': []});
    await learning.initialize();
    addTearDown(learning.dispose);
    await learning.save({
      'id': 'teacher_cards',
      'title': 'Карточки учительницы',
      'published': true,
      'vocabulary': [
        {'id': 'word-1', 'ar': 'كِتَابٌ', 'ru': 'Книга',
         'image_path': '/local/teacher_cards/book.webp'},
      ],
    });
    final words = VocabularyPractice.words(learning);
    expect(words, hasLength(1));
    expect(words.first.imagePath, '/local/teacher_cards/book.webp');
  });
}
