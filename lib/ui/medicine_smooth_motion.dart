import 'package:flutter/material.dart';

/// Flutter equivalent of the verified Medicine Smooth Motion profile.
///
/// No second background is painted by this class; the outgoing page stays
/// stationary. Reading/texture-heavy routes can opt out of horizontal motion.
/// Keep transition durations short without replacing Material back handling.
abstract final class MedicineSmoothMotion {
  static const enter = Duration(milliseconds: 225);
  static const fadeIn = Duration(milliseconds: 205);
  static const exit = Duration(milliseconds: 175);
  static const tabEnter = Duration(milliseconds: 205);
  static const tabExit = Duration(milliseconds: 155);
  static const micro = Duration(milliseconds: 135);
  static const easing = Curves.fastOutSlowIn;

  static bool disabled(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  static Route<T> route<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool shift = false,
    RouteSettings? settings,
  }) => MedicineSmoothPageRoute<T>(
    builder: builder,
    settings: settings,
    reduceMotion: disabled(context),
    shift: shift,
  );
}

/// Uses an opaque MaterialPageRoute, preserving back-stack and gestures.
class MedicineSmoothPageRoute<T> extends MaterialPageRoute<T> {
  MedicineSmoothPageRoute({
    required super.builder,
    super.settings,
    this.reduceMotion = false,
    this.shift = false,
  });

  final bool reduceMotion;
  final bool shift;

  @override
  Duration get transitionDuration => reduceMotion
      ? Duration.zero
      : MedicineSmoothMotion.enter;

  @override
  Duration get reverseTransitionDuration => reduceMotion
      ? Duration.zero
      : MedicineSmoothMotion.exit;
}

/// PageTransitionsTheme adapter used for both light and dark themes.
/// MaterialPageRoutes outside the hand-picked navigation entry points also
/// gain subtle opacity transitions, without global changes to their duration.
class MedicineFadePageTransitionsBuilder extends PageTransitionsBuilder {
  const MedicineFadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (route.isFirst || MedicineSmoothMotion.disabled(context)) {
      return child;
    }

    // An explicit reader/contents route is alpha-only; sliding two textured
    // surfaces can produce a doubled page or edge ghosting.
    final shift = route is MedicineSmoothPageRoute<T> && route.shift;
    final opacity = animation.drive(CurveTween(
      curve: const Interval(0, 0.91, curve: MedicineSmoothMotion.easing),
    ));
    Widget result = child;
    if (shift) {
      result = SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.018, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: MedicineSmoothMotion.easing,
        )),
        child: result,
      );
    }
    return FadeTransition(opacity: opacity, child: result);
  }
}

/// A root-tab fade without two simultaneous page backdrops. The previous
/// content is deliberately not included in the layout; its removal prevents
/// double parchment/background exposure on a tab switch.
class MedicineTabSwitcher extends StatelessWidget {
  const MedicineTabSwitcher({
    super.key,
    required this.tabKey,
    required this.child,
  });

  final Object tabKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduced = MedicineSmoothMotion.disabled(context);
    return AnimatedSwitcher(
      duration: reduced ? Duration.zero : MedicineSmoothMotion.tabEnter,
      reverseDuration: reduced ? Duration.zero : MedicineSmoothMotion.tabExit,
      switchInCurve: MedicineSmoothMotion.easing,
      switchOutCurve: MedicineSmoothMotion.easing,
      layoutBuilder: (currentChild, previousChildren) =>
          currentChild ?? const SizedBox.shrink(),
      transitionBuilder: (page, animation) =>
          FadeTransition(opacity: animation, child: page),
      child: KeyedSubtree(key: ValueKey<Object>(tabKey), child: child),
    );
  }
}
