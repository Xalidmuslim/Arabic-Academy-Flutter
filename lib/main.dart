import 'package:flutter/material.dart';
import 'ui/dictionary_shell.dart';
import 'ui/startup_diagnostics.dart';

export 'core/dictionary_data.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  StartupFrameDiagnostics.instance.initialize();
  runApp(const DictionaryApp());
}
