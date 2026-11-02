import 'package:flutter/material.dart';
import 'ui/dictionary_shell.dart';
import 'ui/startup_frame_trace.dart';

export 'core/dictionary_data.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(startupTraceEnabled
      ? const StartupFrameTrace(child: DictionaryApp())
      : const DictionaryApp());
}
