import 'package:flutter/material.dart';

/// Only the two new home quick actions use this card.
/// Existing feature tiles keep their established three-layer matte depth.
class HomeQuickActionTile extends StatelessWidget {
  const HomeQuickActionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.image,
    required this.onTap,
  });

  static const sageBorder = Color(0xFFC7D7C1);

  final String title;
  final String subtitle;
  final String image;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(19);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF303E35) : const Color(0xFFF9F9F1),
        borderRadius: radius,
        border: Border.all(
          color: dark ? const Color(0xFF73896C) : sageBorder,
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x175B604B),
            blurRadius: 14,
            offset: Offset(0, 5),
            spreadRadius: -3,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 70),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 5, 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 35,
                    height: 42,
                    child: Image.asset(
                      image,
                      fit: BoxFit.contain,
                      cacheWidth: 144,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.auto_stories_outlined,
                        size: 35,
                      ),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 10.8,
                            height: 1.13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 9.2,
                            height: 1.18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 1),
                  Icon(Icons.chevron_right, size: 16,
                      color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
