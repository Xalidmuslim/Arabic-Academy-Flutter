import 'package:flutter/material.dart';
import 'design_tokens.dart';
import 'appearance_theme.dart';
import 'neumorphic_components.dart';

const green = DesignTokens.emerald;
const cream = DesignTokens.ivory;
const bronze = DesignTokens.bronze;
const muted = DesignTokens.secondary;

class NaskhText extends StatelessWidget {
  const NaskhText(
    this.value, {
    super.key,
    this.size = 26,
    this.color = green,
    this.height = 1.8,
    this.align = TextAlign.right,
  });
  final String value;
  final double size, height;
  final Color color;
  final TextAlign align;
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Text(
      value,
      textAlign: align,
      style: TextStyle(
        fontFamily: ReadingFontScope.arabicFontOf(context),
        fontSize: size,
        height: height,
        color: color == green && Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFFB7D3AE) : color,
      ),
      textHeightBehavior: const TextHeightBehavior(
        applyHeightToFirstAscent: true,
        applyHeightToLastDescent: true,
      ),
    ),
  );
}

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) =>
      NeumorphicSurface(padding: padding, child: child);
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (trailing != null) trailing!,
      ],
    ),
  );
}

class ProgressRing extends StatelessWidget {
  const ProgressRing({super.key, required this.value, this.size = 94});
  final double value, size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Прогресс ${(value * 100).round()} процентов',
    child: SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: DesignTokens.ivory,
              boxShadow: DesignTokens.shadows,
            ),
          ),
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: value.clamp(0, 1),
              strokeWidth: size / 10,
              strokeCap: StrokeCap.round,
              color: DesignTokens.olive,
              backgroundColor: DesignTokens.beige,
            ),
          ),
          Text(
            '${(value * 100).round()}%',
            style: TextStyle(
              fontSize: size / 4,
              fontWeight: FontWeight.w800,
              fontVariations: [FontVariation('wght', 800)],
              color: green,
            ),
          ),
        ],
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.auto_stories_outlined,
    this.action,
  });
  final String title, message;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      children: [
        Icon(icon, size: 42, color: DesignTokens.olive),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 7),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (action != null) ...[const SizedBox(height: 12), action!],
      ],
    ),
  );
}

void notice(BuildContext context, String message) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(message)));

Future<void> guardedAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (error) {
    if (context.mounted) notice(context, error.toString());
  }
}
