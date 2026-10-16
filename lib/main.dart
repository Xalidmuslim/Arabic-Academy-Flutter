import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/academy_state.dart';
import 'core/bundled_catalog.dart';
import 'core/performance_probe.dart';

export 'app.dart';
export 'core/academy_state.dart';
export 'features/learning/home_screen.dart';
export 'features/learning/course_screen.dart';
export 'features/learning/lesson_screen.dart';
export 'features/learning/progress_screen.dart';
export 'features/teacher/teacher_editor.dart';
export 'ui/components.dart';

/// Paint the first Flutter frame immediately; never keep the Android system
/// splash on screen while waiting for preferences or bundled JSON assets.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  runApp(const AcademyBootstrap());
}

class AcademyBootstrap extends StatefulWidget {
  const AcademyBootstrap({super.key, this.loader});

  /// Injectable so startup error/retry states are tested without Android.
  final Future<AcademyState> Function()? loader;

  @override
  State<AcademyBootstrap> createState() => _AcademyBootstrapState();
}

class _AcademyBootstrapState extends State<AcademyBootstrap> {
  late Future<AcademyState> _loading;

  @override
  void initState() {
    super.initState();
    _loading = _loadState();
  }

  Future<AcademyState> _loadState() async {
    if (widget.loader != null) {
      return widget.loader!();
    }
    try {
      final resources = await Future.wait<Object>([
        SharedPreferences.getInstance(),
        loadBundledAcademyCatalog(),
      ]).timeout(const Duration(seconds: 25));
      final state = AcademyState(
        resources[0] as SharedPreferences,
        resources[1] as Map<String, dynamic>,
      );
      await state.initialize().timeout(const Duration(seconds: 25));
      return state;
    } catch (error, trace) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: trace,
        library: 'Bayna startup',
      ));
      rethrow;
    }
  }

  void _retry() {
    setState(() {
      _loading = _loadState();
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AcademyState>(
    future: _loading,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return AcademyApp(state: snapshot.requireData);
      }
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Байна Ядайк',
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF8F4E8),
          colorSchemeSeed: const Color(0xFF566B44),
        ),
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: snapshot.hasError
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 42),
                          const SizedBox(height: 18),
                          const Text(
                            'Не удалось загрузить учебные материалы.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Данные приложения не удалены. '
                            'Попробуйте повторить запуск.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 22),
                          FilledButton(
                            onPressed: _retry,
                            child: const Text('Повторить запуск'),
                          ),
                        ],
                      )
                    : const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 18),
                          Text('Загрузка учебных материалов…'),
                        ],
                      ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
