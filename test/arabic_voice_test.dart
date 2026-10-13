import 'package:arabic_academy/core/speech.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Arabic voice choices preserve the actual Android voice identifiers', () {
    const offline = ArabicVoice(name: 'ar-sa-test', locale: 'ar-SA', quality: 400);
    const network = ArabicVoice(
      name: 'ar-eg-online', locale: 'ar-EG', networkRequired: true,
    );
    expect(offline.key, 'ar-SA::ar-sa-test');
    expect(network.label, contains('интернет'));
    expect(offline.label, isNot(contains('интернет')));
  });
}
