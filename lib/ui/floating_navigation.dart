import 'package:flutter/material.dart';
import '../core/app_strings.dart';
import 'design_tokens.dart';
import 'original_art.dart';

/// Lives *above* the Navigator, so navigating into lessons, settings,
/// dictionaries and teacher screens cannot remove it.
class FloatingStudyNavigation extends StatelessWidget {
  const FloatingStudyNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final labels = [
      tr(context, 'Главная'),
      tr(context, 'Уроки'),
      tr(context, 'Поиск'),
      tr(context, 'Профиль'),
    ];
    final icons = <Widget>[
      const ArtworkIcon('home', size: 26),
      const Icon(Icons.menu_book_outlined, size: 26),
      const ArtworkIcon('search', size: 26),
      const ArtworkIcon('profile', size: 26),
    ];
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 9),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 10),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: DecoratedBox(
          key: const ValueKey('floating-study-navigation'),
          decoration: BoxDecoration(
            color: const Color(0xFFF1E6D8),
            borderRadius: BorderRadius.circular(27),
            boxShadow: const [
              BoxShadow(color: Color(0x3B534133), offset: Offset(0, 5), blurRadius: 11, spreadRadius: -3),
              BoxShadow(color: Color(0x16534133), offset: Offset(0, 12), blurRadius: 23, spreadRadius: -7),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Row(
              children: [
                for (var index = 0; index < 4; index++)
                  Expanded(
                    child: Material(
                      color: selectedIndex == index
                          ? const Color(0xFFDEDCC7)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(23),
                      child: InkWell(
                        key: ValueKey('study-tab-$index'),
                        borderRadius: BorderRadius.circular(23),
                        onTap: () => onSelected(index),
                        child: Semantics(
                          selected: selectedIndex == index,
                          button: true,
                          label: labels[index],
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ExcludeSemantics(child: icons[index]),
                                const SizedBox(height: 3),
                                Text(
                                  labels[index],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: DesignTokens.ink,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        ),
        ),
      ),
    );
  }
}
