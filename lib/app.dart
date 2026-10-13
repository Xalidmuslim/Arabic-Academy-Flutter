import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/academy_state.dart';
import 'services/backend_service.dart';
import 'services/purchase_service.dart';
import 'ui/purchase_scope.dart';
import 'ui/design_tokens.dart';
import 'ui/floating_navigation.dart';
import 'ui/welcome_screen.dart';
import 'features/learning/home_screen.dart';

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
  final _selectedTab = ValueNotifier<int>(0);
  late bool _welcomeSeen;

  void _selectTab(int index) {
    _selectedTab.value = index;
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }
  @override
  void initState() {
    super.initState();
    _welcomeSeen = widget.state.prefs.getBool('welcome_seen') == true;
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
    _purchases.dispose();
    _selectedTab.dispose();
    if (widget.backend == null) {
      _backend.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.state,
    builder: (context, _) => MaterialApp(
      title: 'Байна Ядайк',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: DesignTokens.theme(),
      locale: Locale(widget.state.settings['language'] as String? ?? 'ru'),
      supportedLocales: const [Locale('ru'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final size = (widget.state.settings['russianScale'] as num? ?? 1)
            .toDouble()
            .clamp(0.85, 1.6);
        return PurchaseScope(
          service: _purchases,
          child: MediaQuery(
            data: media.copyWith(
              disableAnimations:
                  media.disableAnimations ||
                  widget.state.settings['reduceMotion'] == true,
              textScaler: _CombinedTextScaler(media.textScaler, size),
            ),
            child: _welcomeSeen
                ? Scaffold(
                    // Reserve real scroll viewport ABOVE the floating bar.
                    // The navigation widget itself is transparent in its margins.
                    extendBody: true,
                    backgroundColor: DesignTokens.ivory,
                    body: child!,
                    bottomNavigationBar: ValueListenableBuilder<int>(
                      valueListenable: _selectedTab,
                      builder: (context, selected, _) => FloatingStudyNavigation(
                        selectedIndex: selected,
                        onSelected: _selectTab,
                      ),
                    ),
                  )
                : child!,
          ),
        );
      },
      home: _welcomeSeen
          ? HomeScreen(
              state: widget.state,
              backend: _backend,
              navigationTab: _selectedTab,
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

class _CombinedTextScaler extends TextScaler {
  const _CombinedTextScaler(this.system, this.preference);
  final TextScaler system;
  final double preference;
  @override
  double scale(double fontSize) => system.scale(fontSize) * preference;
  @override
  double get textScaleFactor => system.scale(14) / 14 * preference;
}
