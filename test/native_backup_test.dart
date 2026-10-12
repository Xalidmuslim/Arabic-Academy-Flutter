import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Android backup retains learning preferences but excludes secure session keys',
    () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(
        manifest,
        contains('android:fullBackupContent="@xml/backup_rules"'),
      );
      expect(
        manifest,
        contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
      );
      for (final file in ['backup_rules', 'data_extraction_rules']) {
        final rules = File(
          'android/app/src/main/res/xml/$file.xml',
        ).readAsStringSync();
        expect(rules, contains('FlutterSecureStorage.xml'));
        expect(rules, isNot(contains('FlutterSharedPreferences.xml')));
        expect(rules, isNot(contains('path="."')));
      }
    },
  );
}
