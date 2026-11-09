import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/dictionary_data.dart';

/// A local one-session recall drill for favorite words. No account or network.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.words, required this.fontSize,
    this.animationsEnabled = true});
  final List<Word> words;
  final double fontSize;
  final bool animationsEnabled;
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late final List<Word> queue = List<Word>.of(widget.words);
  int cursor = 0;
  int remembered = 0;
  bool revealed = false;

  void answer(bool known) {
    HapticFeedback.selectionClick();
    setState(() {
      if (known) {
        remembered++;
      } else if (queue.length < widget.words.length * 3) {
        queue.add(queue[cursor]);
      }
      cursor++;
      revealed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final finished = cursor >= queue.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Повторение слов')),
      body: SafeArea(child: Padding(
        padding: const EdgeInsets.all(20),
        child: widget.words.isEmpty
            ? const Center(child: Text('Сначала добавьте слова в избранное'))
            : finished
                ? Center(child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.task_alt_rounded, size: 54,
                        color: scheme.primary),
                      const SizedBox(height: 16),
                      Text('Повторение завершено',
                        style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 10),
                      Text('Вспомнили слов: $remembered'),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Готово')),
                    ]))
                : Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Слово ${cursor + 1} из ${queue.length}',
                          style: TextStyle(color: scheme.onSurfaceVariant)),
                        Text('Помню: $remembered',
                          style: TextStyle(color: scheme.primary)),
                      ]),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: cursor / queue.length,
                      minHeight: 3,
                      borderRadius: BorderRadius.circular(4)),
                    const Spacer(),
                    Semantics(
                      label: 'Арабское слово для повторения',
                      child: Text(queue[cursor].arabic,
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(fontSize: widget.fontSize + 12,
                          height: 1.7, fontWeight: FontWeight.w700))),
                    const SizedBox(height: 24),
                    AnimatedSwitcher(
                      duration: widget.animationsEnabled
                        ? const Duration(milliseconds: 180) : Duration.zero,
                      child: revealed
                        ? Column(key: const ValueKey('arabic-meaning'), children: [
                            Text(queue[cursor].meaning,
                              textAlign: TextAlign.center,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(fontSize: widget.fontSize - 3,
                                height: 1.6)),
                          ])
                        : const Text('Попробуйте объяснить значение на арабском',
                            key: ValueKey('prompt')),
                    ),
                    const Spacer(),
                    if (!revealed)
                      SizedBox(width: double.infinity,
                        child: FilledButton(
                          onPressed: () => setState(() => revealed = true),
                          child: const Text('Показать ответ')))
                    else Row(children: [
                      Expanded(child: OutlinedButton(
                        onPressed: () => answer(false),
                        child: const Text('Повторить'))),
                      const SizedBox(width: 12),
                      Expanded(child: FilledButton(
                        onPressed: () => answer(true),
                        child: const Text('Помню'))),
                    ]),
                  ]),
      )),
    );
  }
}
