import 'package:arabic_academy/core/academy_state.dart';
import 'package:arabic_academy/features/learning/settings_screen.dart';
import 'package:arabic_academy/services/backend_service.dart';
import 'package:arabic_academy/services/integration_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('reading options can expand without changing saved settings', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final state = AcademyState(await SharedPreferences.getInstance(), <String, dynamic>{
      'modules': <dynamic>[],
      'lessons': <dynamic>[],
    });
    final backend = BackendService(
      config: const IntegrationConfig(supabaseUrl: '', supabaseAnonKey: ''),
    );
    addTearDown(() { state.dispose(); backend.dispose(); });
    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(state: state, backend: backend),
    ));
    expect(find.byKey(const ValueKey('reading-preferences')), findsOneWidget);
    expect(find.text('Размер русского текста'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('reading-preferences')));
    await tester.pumpAndSettle();
    expect(find.text('Размер русского текста'), findsOneWidget);
    expect(find.text('Размер арабского текста'), findsOneWidget);
    expect(state.settings['reduceMotion'] == true, isFalse);
  });
}
