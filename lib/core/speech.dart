import 'dart:io';

import 'package:flutter_tts/flutter_tts.dart';

/// Real Android TTS voice metadata, not a claim of a human recording.
class ArabicVoice {
  const ArabicVoice({
    required this.name,
    required this.locale,
    this.networkRequired = false,
    this.quality = 0,
  });
  final String name;
  final String locale;
  final bool networkRequired;
  final int quality;
  String get key => '$locale::$name';
  String get label => '$locale · $name${networkRequired ? ' · интернет' : ''}';
}

/// Device synthesis remains offline when the selected installed voice allows
/// it. Actual naturalness varies by Android TTS engine and Arabic voice pack.
class ArabicSpeech {
  static final FlutterTts _tts = FlutterTts();

  static Future<List<String>> availableEngines() async {
    if (!Platform.isAndroid) return [];
    final data = await _tts.getEngines;
    if (data is! List) return [];
    return data.whereType<String>().toList()..sort();
  }

  static Future<List<ArabicVoice>> availableVoices({String? engine}) async {
    if (engine != null && engine.isNotEmpty && Platform.isAndroid) {
      await _tts.stop();
      await _tts.setEngine(engine);
    }
    final voices = await _tts.getVoices;
    if (voices is! List) return [];
    final result = <ArabicVoice>[];
    for (final raw in voices) {
      if (raw is! Map) continue;
      final name = raw['name']?.toString() ?? '';
      final locale = raw['locale']?.toString() ?? '';
      if (name.isEmpty || !locale.toLowerCase().replaceAll('_', '-').startsWith('ar')) {
        continue;
      }
      final network = raw['network_required'];
      final quality = raw['quality'];
      result.add(ArabicVoice(
        name: name,
        locale: locale,
        networkRequired: network == true || network.toString() == 'true',
        quality: quality is num ? quality.toInt() : 0,
      ));
    }
    result.sort((a, b) {
      final arA = a.locale.toLowerCase().replaceAll('_', '-') == 'ar-sa' ? 0 : 1;
      final arB = b.locale.toLowerCase().replaceAll('_', '-') == 'ar-sa' ? 0 : 1;
      if (arA != arB) return arA.compareTo(arB);
      if (a.quality != b.quality) return b.quality.compareTo(a.quality);
      return a.name.compareTo(b.name);
    });
    return result;
  }

  static Future<void> speak(
    String text, {
    double speed = 0.50,
    String? engine,
    String? voiceName,
    String? voiceLocale,
  }) async {
    if (text.trim().isEmpty) return;
    await _tts.stop();
    if (Platform.isAndroid && engine != null && engine.isNotEmpty) {
      await _tts.setEngine(engine);
    }
    final locale = voiceLocale != null && voiceLocale.startsWith('ar')
        ? voiceLocale
        : 'ar-SA';
    final installed = await _tts.isLanguageAvailable(locale);
    if (installed != true && installed != 1) {
      final fallback = await _tts.isLanguageAvailable('ar');
      if (fallback != true && fallback != 1) {
        throw StateError(
          'Арабский голос не установлен. Установите его в настройках синтеза речи Android.',
        );
      }
      await _tts.setLanguage('ar');
    } else {
      await _tts.setLanguage(locale);
    }
    if (voiceName != null && voiceName.isNotEmpty &&
        voiceLocale != null && voiceLocale.isNotEmpty) {
      await _tts.setVoice({'name': voiceName, 'locale': voiceLocale});
    }
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(speed.clamp(0.38, 0.65));
    await _tts.speak(text);
  }

  static Future<void> stop() async {
    await _tts.stop();
  }
}
