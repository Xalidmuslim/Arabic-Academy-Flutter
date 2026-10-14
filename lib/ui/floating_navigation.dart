import 'package:flutter/material.dart';
import '../core/app_strings.dart';
import 'design_tokens.dart';
import 'original_art.dart';

/// Visible on root tabs only; NavigatorObserver hides it for detail routes.
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
      tr(context, 'Практика'),
      tr(context, 'Профиль'),
    ];
    final icons = <Widget>[
      const ArtworkIcon('home', size: 26),
      const Icon(Icons.menu_book_outlined, size: 26),
      const Icon(Icons.psychology_alt_outlined, size: 26),
      const ArtworkIcon('profile', size: 26),
    ];
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 6),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: DecoratedBox(
          key: const ValueKey('floating-study-navigation'),
          decoration: BoxDecoration(
            color: DesignTokens.navSurface,
            borderRadius: BorderRadius.circular(29),
            border: Border.all(color: DesignTokens.cardHighlight, width: 0.8),
            boxShadow: const [
              BoxShadow(color: Color(0x28534133), offset: Offset(0, 6), blurRadius: 15, spreadRadius: -3),
              BoxShadow(color: Color(0x19534133), offset: Offset(0, 15), blurRadius: 28, spreadRadius: -8),
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
