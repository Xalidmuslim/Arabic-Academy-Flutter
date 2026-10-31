import 'dart:io';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart';

/// A readable failure, not a raw PlatformException hidden under navigation.
class ArabicSpeechException implements Exception {
  const ArabicSpeechException(this.message);
  final String message;
  @override
  String toString() => message;
}


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
    void Function(int start, int end, String word)? onProgress,
    void Function()? onCompleted,
    void Function(String message)? onError,
  }) async {
    if (text.trim().isEmpty) return;
    await _tts.stop();
    // Android reports UTF-16 offsets for the currently spoken word.
    // Handlers are replaced for every new utterance; old route callbacks
    // cannot keep modifying the highlight after another screen speaks.
    _tts.setProgressHandler((String spoken, int start, int end, String word) {
      onProgress?.call(start, end, word);
    });
    _tts.setCompletionHandler(() {
      onCompleted?.call();
    });
    // Android can accept a speak request and reject the utterance later.
    // Surface that asynchronous error instead of silently showing no sound.
    _tts.setErrorHandler((message) {
      onError?.call(
        'Ошибка арабской озвучки Android: $message. '
        'Проверьте установленный голос и громкость мультимедиа.',
      );
    });
    if (Platform.isAndroid && engine != null && engine.isNotEmpty) {
      await _tts.setEngine(engine);
    }
    try {
      final preferred = voiceLocale != null &&
              voiceLocale.toLowerCase().startsWith('ar')
          ? voiceLocale
          : 'ar-SA';
      // ar-SA is not guaranteed to be installed. Some Android engines only
      // expose ar-EG, ar-AE, etc. Try the language default and the actually
      // installed voices before reporting a missing Arabic synthesizer.
      String? locale;
      for (final candidate in {preferred, 'ar'}) {
        final available = await _tts.isLanguageAvailable(candidate);
        if (available == true || available == 1) {
          locale = candidate;
          break;
        }
      }
      if (locale == null) {
        final voices = await availableVoices();
        // Prefer offline speech to avoid surprises on restricted networks.
        voices.sort((a, b) {
          if (a.networkRequired != b.networkRequired) {
            return a.networkRequired ? 1 : -1;
          }
          return b.quality.compareTo(a.quality);
        });
        for (final voice in voices) {
          final available = await _tts.isLanguageAvailable(voice.locale);
          if (available == true || available == 1) {
            locale = voice.locale;
            break;
          }
        }
      }
      if (locale == null) {
        throw const ArabicSpeechException(
          'Арабский голос не найден. В настройках телефона откройте '
          '«Синтез речи», установите арабский язык и повторите.',
        );
      }
      final languageSet = await _tts.setLanguage(locale);
      if (languageSet == false || languageSet == 0) {
        throw const ArabicSpeechException(
          'Не удалось включить арабский голос. Проверьте языковые данные '
          'в настройках синтеза речи Android.',
        );
      }
      // A previously saved voice can disappear after an Android TTS update.
      // If it fails, keep the selected language and let Android choose a voice.
      if (voiceName != null && voiceName.isNotEmpty &&
          voiceLocale != null && voiceLocale == locale) {
        final selected = await _tts.setVoice({
          'name': voiceName,
          'locale': voiceLocale,
        });
        if (selected == false || selected == 0) {
          await _tts.setLanguage(locale);
        }
      }
      await _tts.setPitch(1.0);
      await _tts.setSpeechRate(speed.clamp(0.38, 0.65));
      final played = await _tts.speak(text);
      if (played == false || played == 0) {
        throw const ArabicSpeechException(
          'Синтез речи не запустился. Проверьте арабский голос в настройках '
          'Android и громкость мультимедиа.',
        );
      }
    } on ArabicSpeechException {
      rethrow;
    } on PlatformException catch (error) {
      throw ArabicSpeechException(
        'Не удалось воспроизвести арабский текст (TTS: ${error.code}). '
        'Проверьте настройки синтеза речи Android и выбранный голос.',
      );
    }
  }

  static Future<void> stop() async {
    await _tts.stop();
  }
}
