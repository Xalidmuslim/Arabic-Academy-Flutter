import 'package:flutter/material.dart';

import '../../core/academy_state.dart';
import '../../core/speech.dart';
import '../../core/vocabulary_key.dart';
import '../../features/exercises/arabic_normalization.dart';
import '../../ui/components.dart';
import '../../ui/design_tokens.dart';

/// Uses only the selected catalog lesson; no synthetic or unverified
/// translations are shown for words missing from that lesson's vocabulary.
class SmartReaderScreen extends StatefulWidget {
  const SmartReaderScreen({
    super.key, required this.state, required this.lesson,
  });
  final AcademyState state;
  final Map<String, dynamic> lesson;

  @override
  State<SmartReaderScreen> createState() => _SmartReaderScreenState();
}

class _SmartReaderScreenState extends State<SmartReaderScreen> {
  bool _translations = false;
  int? _activeLine;
  double _speed = .50;

  List<Map<String, dynamic>> get _lines {
    final rows = widget.lesson['dialogue'];
    if (rows is! List) return [];
    return rows.whereType<Map>()
        .map((r) => Map<String, dynamic>.from(r)).toList();
  }

  ({String ar, String ru, String id})? _findWord(String token) {
    final raw = ArabicNormalization.forGrading(token,
      ignoreDiacritics: true).replaceAll(
        RegExp(r'[^\u0621-\u064A]'), '');
    if (raw.isEmpty) return null;
    final vocabulary = widget.lesson['vocabulary'];
    if (vocabulary is! List) return null;
    for (var i = 0; i < vocabulary.length; i++) {
      final item = vocabulary[i];
      if (item is! Map) continue;
      final word = item['ar']?.toString() ?? '';
      final normalized = ArabicNormalization.forGrading(
        word, ignoreDiacritics: true).replaceAll(
        RegExp(r'[^\u0621-\u064A]'), '');
      if (normalized == raw) {
        return (
          ar: word,
          ru: item['ru']?.toString() ?? '',
          id: vocabularyKey(widget.lesson['id'].toString(), i, item),
        );
      }
    }
    return null;
  }

  Future<void> _speak(String arabic) => guardedAction(context, () =>
      ArabicSpeech.speak(
        arabic,
        speed: _speed,
        engine: widget.state.settings['audioEngine'] as String?,
        voiceName: widget.state.settings['audioVoiceName'] as String?,
        voiceLocale: widget.state.settings['audioVoiceLocale'] as String?,
      ));

  void _wordSheet(String raw) {
    final word = _findWord(raw);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: DesignTokens.cardSurface,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NaskhText(word?.ar ?? raw,
                size: 34, align: TextAlign.center),
              const SizedBox(height: 8),
              Text(word == null || word.ru.isEmpty
                ? 'Для этого слова нет подтверждённого отдельного перевода.'
                : word.ru, textAlign: TextAlign.center),
              const SizedBox(height: 15),
              OutlinedButton.icon(
                icon: const Icon(Icons.volume_up_outlined),
                onPressed: () => _speak(word?.ar ?? raw),
                label: const Text('Произнести'),
              ),
              if (word != null)
                FilledButton.icon(
                  icon: Icon(widget.state.bookmarks.contains(word.id)
                    ? Icons.favorite : Icons.favorite_border),
                  onPressed: () async {
                    await guardedAction(context,
                      () => widget.state.toggleBookmark(word.id));
                    if (context.mounted) Navigator.pop(context);
                  },
                  label: const Text('Сохранить / убрать из избранного'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    ArabicSpeech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Умное чтение')),
    body: AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 150),
        children: [
          Text(widget.lesson['title']?.toString() ?? '',
            style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('Нажмите слово для перевода и произношения. '
            'Для незнакомых слов перевод не выдумывается.',
            style: TextStyle(color: DesignTokens.secondary, fontSize: 12)),
          SwitchListTile.adaptive(
            title: const Text('Показывать перевод фраз'),
            value: _translations,
            onChanged: (v) => setState(() => _translations = v),
            contentPadding: EdgeInsets.zero,
          ),
          Text('Скорость воспроизведения: '
            '${(_speed * 100).round()}%',
            style: const TextStyle(fontSize: 12,
              color: DesignTokens.secondary)),
          Slider(
            value: _speed, min: .4, max: .65, divisions: 5,
            onChanged: (value) => setState(() => _speed = value),
          ),
          const Text('Озвучка — синтезатор телефона. Качество зависит '
            'от установленного арабского голоса.',
            style: TextStyle(fontSize: 11, color: DesignTokens.secondary)),
          const SizedBox(height: 10),
          for (var i = 0; i < _lines.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Panel(child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Text('Реплика ${i + 1}',
                      style: TextStyle(
                        fontWeight: _activeLine == i
                          ? FontWeight.w800 : FontWeight.w500,
                        color: DesignTokens.deepOlive)),
                    const Spacer(),
                    IconButton(
                      key: ValueKey('reader-audio-$i'),
                      tooltip: 'Повторить реплику',
                      onPressed: () {
                        setState(() => _activeLine = i);
                        _speak(_lines[i]['ar']?.toString() ?? '');
                      },
                      icon: const Icon(Icons.record_voice_over_outlined),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: Wrap(
                      spacing: 6, runSpacing: 8,
                      children: [
                        for (final token in (_lines[i]['ar']?.toString() ?? '')
                          .split(RegExp(r'\s+')).where((s) => s.isNotEmpty))
                          InkWell(
                            onTap: () => _wordSheet(token),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2, vertical: 3),
                              child: NaskhText(token, size: 26,
                                color: DesignTokens.emerald),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_translations)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(_lines[i]['ru']?.toString() ?? ''),
                    ),
                ],
              )),
            ),
          if (_lines.isEmpty)
            const EmptyState(title: 'Диалог пока не добавлен',
              message: 'Откройте урок с диалогом для умного чтения.'),
        ],
      ),
    ),
  );
}
