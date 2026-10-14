import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/academy_state.dart';
import '../../core/practice_generator.dart';
import '../../core/speech.dart';
import '../../core/vocabulary_practice.dart';
import '../../ui/components.dart';
import '../../ui/design_tokens.dart';

/// Each image cue is deliberately tied to a known concept; unsupported words
/// remain in the regular dictionary and are never illustrated incorrectly.
class SemanticWordIllustration extends StatelessWidget {
  const SemanticWordIllustration({super.key, required this.arabic,
    this.size = 132, this.imagePath});
  final String arabic;
  final double size;
  final String? imagePath;

  static const symbols = <String, IconData>{
    'book': Icons.menu_book_outlined, 'pen': Icons.edit_outlined,
    'door': Icons.door_front_door_outlined, 'house': Icons.home_outlined,
    'school': Icons.school_outlined, 'bag': Icons.backpack_outlined,
    'car': Icons.directions_car_outlined, 'tree': Icons.park_outlined,
    'mosque': Icons.account_balance_outlined, 'market': Icons.storefront_outlined,
    'clock': Icons.watch_later_outlined, 'water': Icons.water_drop_outlined,
    'bread': Icons.bakery_dining_outlined, 'apple': Icons.apple_outlined,
    'sun': Icons.wb_sunny_outlined, 'moon': Icons.nightlight_round,
    'plane': Icons.flight_outlined, 'cat': Icons.pets_outlined,
    'chair': Icons.chair_outlined, 'phone': Icons.phone_android_outlined,
    'computer': Icons.laptop_outlined, 'key': Icons.key_outlined,
    'window': Icons.window_outlined, 'flower': Icons.local_florist_outlined,
    'fish': Icons.set_meal_outlined, 'food': Icons.restaurant_outlined,
    'shirt': Icons.checkroom_outlined, 'cow': Icons.pets_outlined,
    'horse': Icons.pets_outlined, 'doctor': Icons.medical_services_outlined,
    'hospital': Icons.local_hospital_outlined, 'cup': Icons.local_cafe_outlined,
    'kitchen': Icons.kitchen_outlined,
  };

  @override
  Widget build(BuildContext context) {
    if (imagePath != null && imagePath!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.file(
          File(imagePath!), width: size, height: size,
          fit: BoxFit.cover, cacheWidth: (size * 2).round(),
          errorBuilder: (context, error, stack) => _semanticFallback(),
        ),
      );
    }
    return _semanticFallback();
  }

  Widget _semanticFallback() {
    final concept = IllustratedTerm.concept(arabic);
    return Semantics(
      label: 'Предметный рисунок: ${concept ?? 'нет рисунка'}',
      child: Center(
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFFCF5), Color(0xFFE3E4D5)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.white, width: 1.6),
            boxShadow: const [
              BoxShadow(color: Color(0x245A4D3D),
                offset: Offset(0, 7), blurRadius: 18, spreadRadius: -3),
              BoxShadow(color: Color(0x105A4D3D),
                offset: Offset(0, 13), blurRadius: 25),
            ],
          ),
          child: Icon(symbols[concept] ?? Icons.help_outline,
            size: size * .56,
            color: DesignTokens.deepOlive),
        ),
      ),
    );
  }
}

class IllustratedDictionaryScreen extends StatefulWidget {
  const IllustratedDictionaryScreen({super.key, required this.state});
  final AcademyState state;
  @override
  State<IllustratedDictionaryScreen> createState() =>
      _IllustratedDictionaryScreenState();
}

class _IllustratedDictionaryScreenState extends State<IllustratedDictionaryScreen> {
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Слова в рисунках')),
    body: AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        final all = VocabularyPractice.words(widget.state)
            .where((word) => IllustratedTerm.hasIllustration(word.ar) ||
                (word.imagePath?.isNotEmpty ?? false))
            .toList();
        final term = _search.text.toLowerCase().trim();
        final seen = <String>{};
        final matching = all.where((word) =>
            (term.isEmpty ||
              word.ru.toLowerCase().contains(term) ||
              word.ar.toLowerCase().contains(term)) &&
            seen.add('${word.ar.toLowerCase()}:${word.ru.toLowerCase()}')
          ).toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
          children: [
            const Text('Карточки с проверенными образами и рисунками учительницы. '
              'Новые изображения добавляются в конструкторе карточек.',
              style: TextStyle(fontSize: 12, color: DesignTokens.secondary)),
            const SizedBox(height: 12),
            TextField(
              controller: _search,
              key: const ValueKey('illustrated-dictionary-search'),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Поиск слова'),
            ),
            const SizedBox(height: 15),
            if (matching.isEmpty)
              const EmptyState(
                title: 'Иллюстрация не найдена',
                message: 'В словаре остаются все слова, даже без рисунков.',
              ),
            for (var i = 0; i < matching.length; i += 2)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _card(context, matching[i])),
                    const SizedBox(width: 12),
                    Expanded(child: i + 1 < matching.length
                        ? _card(context, matching[i + 1])
                        : const SizedBox()),
                  ],
                ),
              ),
          ],
        );
      },
    ),
  );

  Widget _card(BuildContext context, VocabularyPracticeWord word) =>
      Panel(child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SemanticWordIllustration(arabic: word.ar, size: 110,
            imagePath: word.imagePath),
          const SizedBox(height: 9),
          NaskhText(word.ar, size: 25, align: TextAlign.center,
              color: DesignTokens.emerald),
          const SizedBox(height: 4),
          Text(word.ru, textAlign: TextAlign.center,
            maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 7),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(
              tooltip: 'Произнести по-арабски',
              icon: const Icon(Icons.volume_up_outlined,
                color: DesignTokens.deepOlive),
              onPressed: () => guardedAction(context, () => ArabicSpeech.speak(
                word.ar,
                speed: (widget.state.settings['audioSpeed'] as num? ?? .5)
                    .toDouble(),
              )),
            ),
            IconButton(
              tooltip: 'Сохранить в избранное',
              icon: Icon(widget.state.bookmarks.contains(word.id)
                  ? Icons.favorite : Icons.favorite_border,
                color: DesignTokens.deepOlive),
              onPressed: () => guardedAction(context,
                () => widget.state.toggleBookmark(word.id)),
            ),
          ]),
        ],
      ));
}
