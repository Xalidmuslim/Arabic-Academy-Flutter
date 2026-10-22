import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/academy_state.dart';
import 'services/backend_service.dart';
import 'services/purchase_service.dart';
import 'ui/purchase_scope.dart';
import 'ui/appearance_theme.dart';
import 'ui/floating_navigation.dart';
import 'ui/welcome_screen.dart';
import 'ui/background_artwork_preloader.dart';
import 'ui/study_art_asset.dart';
import 'ui/medicine_smooth_motion.dart';
import 'features/learning/home_screen.dart';

// Only settings that affect the MaterialApp theme, locale or inherited
// typography may rebuild the app shell. Lesson completion, answer saves,
// notes and progress updates must rebuild their own listeners, not routes.
typedef _AppPresentation = ({
  String appearance,
  String language,
  String russianFont,
  String arabicFont,
  double russianScale,
  bool reduceMotion,
});

_AppPresentation _readPresentation(AcademyState state) {
  final settings = state.settings;
  return (
    appearance: settings['appearance'] as String? ?? 'system',
    language: settings['language'] as String? ?? 'ru',
    russianFont: settings['russianFont'] as String? ?? 'Manrope',
    arabicFont: settings['arabicFont'] as String? ?? 'NotoNaskhArabic',
    russianScale: (settings['russianScale'] as num? ?? 1)
        .toDouble().clamp(0.85, 1.6).toDouble(),
    reduceMotion: settings['reduceMotion'] == true,
  );
}

class AcademyApp extends StatefulWidget {
  const AcademyApp({super.key, required this.state, this.backend});
  final AcademyState state;
  final BackendService? backend;
  @override
  State<AcademyApp> createState() => _AcademyAppState();
}

class _AcademyAppState extends State<AcademyApp> {
  late final BackendService _backend = widget.backend ?? BackendService();
  late final PurchaseService _purchases = PurchaseService(_backend);
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final ValueNotifier<_AppPresentation> _presentation =
      ValueNotifier(_readPresentation(widget.state));

  void _onAcademyStateChanged() {
    final next = _readPresentation(widget.state);
    if (_presentation.value != next) _presentation.value = next;
  }

  @override
  void didUpdateWidget(covariant AcademyApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.state, widget.state)) {
      oldWidget.state.removeListener(_onAcademyStateChanged);
      widget.state.addListener(_onAcademyStateChanged);
      _onAcademyStateChanged();
    }
  }

  late final List<String> _nextArtworkToWarm = _collectNextArtwork();

  List<String> _collectNextArtwork() {
    // The immediately visible hero and high-priority cards come before
    // optional lesson art. These images decode in background after first frame.
    final paths = <String>{
      'assets/artwork/home_quick/course.webp',
      'assets/artwork/home_quick/review.webp',
      'assets/artwork/home_quick/next.webp',
      'assets/artwork/vocabulary.webp',
    };
    for (final source in [
      widget.state.catalog['lessons'],
      widget.state.catalog['modules'],
    ]) {
      if (source is! List) continue;
      for (final item in source) {
        if (item is! Map) continue;
        final image = StudyArtAsset.valid(
          item['dialogue_illustration_asset'] ?? item['illustration_asset'],
        );
        if (image != null) paths.add(image);
        if (paths.length >= 6) return paths.toList(growable: false);
      }
    }
    return paths.toList(growable: false);
  }
  final _selectedTab = ValueNotifier<int>(0);
  int _tabChangeGeneration = 0;
  late final _teacherMode = ValueNotifier<bool>(
    widget.state.prefs.getBool('demo_role_teacher') == true,
  );
  final _showFloatingNav = ValueNotifier<bool>(true);
  late final _routeObserver = _FloatingNavRouteObserver((visible) {
    if (_showFloatingNav.value != visible) _showFloatingNav.value = visible;
  });
  late bool _welcomeSeen;

  void _selectTab(int index) {
    final generation = ++_tabChangeGeneration;
    final navigator = _navigatorKey.currentState;
    if (navigator == null || !navigator.canPop()) {
      _selectedTab.value = index;
      return;
    }

    // Wait for the route's actual reverse transition to finish. Updating the
    // root tab while Settings/Reader is fading out makes two backgrounds
    // change at once, which looks like a double jump.
    Route<dynamic>? leaving;
    navigator.popUntil((route) {
      if (!route.isFirst) leaving ??= route;
      return route.isFirst;
    });
    final poppedRoute = leaving;
    if (poppedRoute == null) {
      _selectedTab.value = index;
      return;
    }
    unawaited(poppedRoute.completed.then((_) {
      if (!mounted || generation != _tabChangeGeneration) return;
      _selectedTab.value = index;
    }));
  }
  @override
  void initState() {
    super.initState();
    _welcomeSeen = widget.state.prefs.getBool('welcome_seen') == true;
    widget.state.addListener(_onAcademyStateChanged);
    _backend.addListener(_connectStore);
    // Local learning paints immediately; optional online setup never gates it.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_backend.initialize()),
    );
  }

  void _connectStore() {
    if (_backend.isAuthenticated &&
        _backend.config.storeProductIds.isNotEmpty) {
      unawaited(_initializeStore());
    }
  }

  Future<void> _initializeStore() async {
    try {
      await _purchases.initialize();
    } catch (_) {
      // The purchase screen exposes retry; no access is granted on failure.
    }
  }

  @override
  void dispose() {
    _backend.removeListener(_connectStore);
    widget.state.removeListener(_onAcademyStateChanged);
    _presentation.dispose();
    _purchases.dispose();
    _selectedTab.dispose();
    _teacherMode.dispose();
    _showFloatingNav.dispose();
    if (widget.backend == null) {
      _backend.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<_AppPresentation>(
    valueListenable: _presentation,
    builder: (context, presentation, _) => MaterialApp(
      title: 'Байна Ядайк',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      navigatorObservers: [_routeObserver],
      theme: academyTheme(
        dark: false,
        latinFont: presentation.russianFont,
      ).copyWith(pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: MedicineFadePageTransitionsBuilder(),
          TargetPlatform.iOS: MedicineFadePageTransitionsBuilder(),
          TargetPlatform.linux: MedicineFadePageTransitionsBuilder(),
          TargetPlatform.macOS: MedicineFadePageTransitionsBuilder(),
          TargetPlatform.windows: MedicineFadePageTransitionsBuilder(),
          TargetPlatform.fuchsia: MedicineFadePageTransitionsBuilder(),
        },
      )),
      darkTheme: academyTheme(
        dark: true,
        latinFont: presentation.russianFont,
      ).copyWith(pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: MedicineFadePageTransitionsBuilder(),
          TargetPlatform.iOS: MedicineFadePageTransitionsBuilder(),
          TargetPlatform.linux: MedicineFadePageTransitionsBuilder(),
          TargetPlatform.macOS: MedicineFadePageTransitionsBuilder(),
          TargetPlatform.windows: MedicineFadePageTransitionsBuilder(),
          TargetPlatform.fuchsia: MedicineFadePageTransitionsBuilder(),
        },
      )),
      themeMode: switch (presentation.appearance) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      locale: Locale(presentation.language),
      supportedLocales: const [Locale('ru'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        final media = MediaQuery.of(context);
        final size = (widget.state.settings['russianScale'] as num? ?? 1)
            .toDouble()
            .clamp(0.85, 1.6);
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarContrastEnforced: false,
            statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
            systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          ),
          child: ReadingFontScope(
            arabicFamily: presentation.arabicFont,
            child: PurchaseScope(
          service: _purchases,
          child: MediaQuery(
            data: media.copyWith(
              disableAnimations:
                  media.disableAnimations ||
                  presentation.reduceMotion,
              textScaler: _CombinedTextScaler(media.textScaler, size),
            ),
            child: _welcomeSeen
                ? BackgroundArtworkPreloader(
                    artworkPaths: _nextArtworkToWarm,
                    maxImages: 4,
                    child: ColoredBox(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: Stack(
                    // Let pages paint behind the pill: the outside of the
                    // floating navigation is genuinely transparent.
                    fit: StackFit.expand,
                    children: [
                      child!,
                      ValueListenableBuilder<bool>(
                        valueListenable: _showFloatingNav,
                        builder: (context, visible, _) => visible
                            ? Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: ValueListenableBuilder<bool>(
                                  valueListenable: _teacherMode,
                                  builder: (context, isTeacher, _) =>
                                      ValueListenableBuilder<int>(
                                    valueListenable: _selectedTab,
                                    builder: (context, selected, _) =>
                                        FloatingStudyNavigation(
                                          selectedIndex: selected,
                                          onSelected: _selectTab,
                                          teacherMode: isTeacher,
                                        ),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  )),
                  )
                : child!,
          ),
        )));
      },
      home: _welcomeSeen
          ? HomeScreen(
              state: widget.state,
              backend: _backend,
              navigationTab: _selectedTab,
              teacherNavigationMode: _teacherMode,
              showEmbeddedNavigation: false,
            )
          : Builder(
              builder: (context) => ReferenceWelcomeScreen(
                backend: _backend,
                onStart: () async {
                  await widget.state.prefs.setBool('welcome_seen', true);
                  if (context.mounted) {
                    setState(() => _welcomeSeen = true);
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => HomeScreen(
                          state: widget.state,
                          backend: _backend,
                          navigationTab: _selectedTab,
                          teacherNavigationMode: _teacherMode,
                          showEmbeddedNavigation: false,
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
    ),
  );
}

/// The floating pill remains across ordinary routes; modal popup routes
/// temporarily hide it so dialogs and bottom sheets receive all touches.
class _FloatingNavRouteObserver extends NavigatorObserver {
  _FloatingNavRouteObserver(this.onVisibilityChanged);
  final ValueChanged<bool> onVisibilityChanged;

  void _update(Route<dynamic>? top) =>
      // Keep the floating bar across pushed screens; only modal overlays
      // (dialogs / sheets) must be above and unobstructed by navigation.
      onVisibilityChanged(top == null || top is! PopupRoute);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _update(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _update(previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _update(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _update(newRoute);
  }
}

class _CombinedTextScaler extends TextScaler {
  const _CombinedTextScaler(this.system, this.preference);
  final TextScaler system;
  final double preference;
  @override
  double scale(double fontSize) => system.scale(fontSize) * preference;
  @override
  double get textScaleFactor => system.scale(14) / 14 * preference;
}
