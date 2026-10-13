import 'package:flutter/material.dart';

import 'textbook_reader_screen.dart';

/// Direct jump from an independently written dialogue to its exact page in
/// the user's privately imported scanned textbook. Zero-based page index.
class OriginalTextbookLink extends StatelessWidget {
  const OriginalTextbookLink({super.key, required this.pageIndex});

  final int pageIndex;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    key: const ValueKey('open-original-pdf-page'),
    icon: const Icon(Icons.picture_as_pdf_outlined),
    label: Text('Оригинальный учебник · страница ${pageIndex + 1}'),
    onPressed: () => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TextbookReaderScreen(initialPage: pageIndex),
      ),
    ),
  );
}
