import 'dart:async';

import 'package:arabic_academy/app.dart';
import 'package:arabic_academy/core/academy_state.dart';
import 'package:arabic_academy/main.dart' show AcademyBootstrap;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Flutter shows loading UI before slow local initialization', (tester) async {
    final pending = Completer<AcademyState>();
    await tester.pumpWidget(AcademyBootstrap(loader: () => pending.future));
    expect(find.text('Загрузка учебных материалов…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // Do not wait for the incomplete initialization future.
  });

  testWidgets('failed startup offers retry and preserves local data', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'welcome_seen': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final state = AcademyState(prefs, <String, dynamic>{
      'modules': <dynamic>[],
      'lessons': <dynamic>[],
    });
    addTearDown(state.dispose);
    var attempts = 0;
    await tester.pumpWidget(AcademyBootstrap(loader: () async {
      attempts++;
      if (attempts == 1) throw StateError('Synthetic corrupt asset');
      return state;
    }));
    await tester.pump();
    expect(find.text('Не удалось загрузить учебные материалы.'), findsOneWidget);
    expect(find.textContaining('Данные приложения не удалены'), findsOneWidget);
    await tester.tap(find.text('Повторить запуск'));
    // FutureBuilder first paints the waiting state; drain the resolved
    // asynchronous loader and the subsequent AcademyApp frame.
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.byType(AcademyApp), findsOneWidget);
    expect(prefs.getBool('welcome_seen'), isTrue);
  });
}
