import 'package:arabic_academy/core/speech.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_tts');

  test('fallback speaks with installed ar-EG when ar-SA and ar are absent',
      () async {
    final commands = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      commands.add('${call.method}:${call.arguments}');
      switch (call.method) {
        case 'isLanguageAvailable':
          return call.arguments == 'ar-EG';
        case 'getVoices':
          return [
            {'name': 'ar-eg-installed', 'locale': 'ar-EG',
             'network_required': false, 'quality': 400},
          ];
        case 'speak':
        case 'setLanguage':
        case 'setPitch':
        case 'setSpeechRate':
        case 'stop':
          return 1;
        default:
          return 1;
      }
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance
        .defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
    await ArabicSpeech.speak('مَرْحَبًا');
    expect(commands, contains('setLanguage:ar-EG'));
    expect(commands.any((c) => c.startsWith('speak:')), isTrue);
  });

  test('native synth returning failure must not pretend audio played',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'isLanguageAvailable':
          return true;
        case 'speak':
          return 0;
        default:
          return 1;
      }
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance
        .defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
    await expectLater(
      ArabicSpeech.speak('السَّلَامُ'),
      throwsA(isA<ArabicSpeechException>()),
    );
  });
}
