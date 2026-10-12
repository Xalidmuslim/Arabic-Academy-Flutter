import 'package:flutter_tts/flutter_tts.dart';

/// Device synthesis is labelled as synthesis, never as a human recording or
/// pronunciation assessment. Requires an installed Arabic voice.
class ArabicSpeech {
  static final FlutterTts _tts = FlutterTts();
  static Future<void> speak(String text, {double speed = 0.45}) async {
    if (text.trim().isEmpty) return;
    final supported = await _tts.isLanguageAvailable('ar');
    if (supported != true && supported != 1) {
      throw StateError(
        'Установите арабский голос в настройках синтеза речи устройства.',
      );
    }
    await _tts.stop();
    await _tts.setLanguage('ar');
    await _tts.setSpeechRate(speed.clamp(0.2, 0.8));
    await _tts.speak(text);
  }

  static Future<void> stop() async {
    await _tts.stop();
  }
}
