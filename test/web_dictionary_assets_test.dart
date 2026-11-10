import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('web and Android share the same UTF-8 dictionary asset manifest', () async {
    final raw = await rootBundle.loadString('assets/data/corpus_manifest.json');
    final manifest = jsonDecode(raw) as Map<String, dynamic>;
    expect(manifest['schema_version'], 1);

    final files = (manifest['files'] as List<dynamic>).cast<String>();
    expect(files, isNotEmpty);
    expect(files.toSet().length, files.length);
    for (final file in files) {
      expect(file, startsWith('assets/data/'));
      expect(file, endsWith('.json'));
      expect(file, isNot(contains('..')));
    }

    // The first and last published files must be parseable by both targets.
    for (final file in {files.first, files.last}) {
      final corpus = jsonDecode(await rootBundle.loadString(file))
          as Map<String, dynamic>;
      final entries = corpus['entries'] as List<dynamic>;
      expect(entries, isNotEmpty, reason: '$file must contain articles');
      final entry = entries.first as Map<String, dynamic>;
      expect(entry['id'], isA<String>());
      expect(entry['arabic'], isA<String>());
      expect(entry['meaning_ar'], isA<String>());
    }
  });
}
