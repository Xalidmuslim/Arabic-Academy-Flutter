import 'package:flutter/material.dart';
import 'ui/dictionary_shell.dart';

export 'core/dictionary_data.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DictionaryApp());
}
