import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/teacher_word_image_store.dart';
import 'fitted_study_artwork.dart';

/// Edits only a local lesson image reference. Saving the lesson is a separate
/// explicit action; cancelled cards never overwrite an existing picture.
class TeacherWordImagePicker extends StatefulWidget {
  const TeacherWordImagePicker({
    super.key, this.initialPath, required this.onChanged,
  });
  final String? initialPath;
  final void Function(Uint8List? bytes, bool cleared) onChanged;

  @override
  State<TeacherWordImagePicker> createState() => _TeacherWordImagePickerState();
}

class _TeacherWordImagePickerState extends State<TeacherWordImagePicker> {
  Uint8List? _chosen;
  bool _removed = false;
  bool _busy = false;

  Future<void> _choose() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final selection = await FilePicker.platform.pickFiles(
        type: FileType.image, allowMultiple: false, withData: false,
      );
      if (selection == null || selection.files.isEmpty) return;
      final picked = selection.files.single;
      if (picked.size > TeacherWordImageStore.maxBytes) {
        throw const FormatException('Изображение больше 2 МБ. Уменьшите его.');
      }
      final path = picked.path;
      if (path == null) {
        throw const FormatException('Не удалось открыть выбранный файл.');
      }
      final bytes = await File(path).readAsBytes();
      TeacherWordImageStore.extension(bytes);
      if (!mounted) return;
      setState(() {
        _chosen = bytes;
        _removed = false;
      });
      widget.onChanged(bytes, false);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Изображение: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _clear() {
    setState(() {
      _chosen = null;
      _removed = true;
    });
    widget.onChanged(null, true);
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.initialPath;
    final hasOriginal = !_removed && initial != null && initial.isNotEmpty;
    final hasPicture = _chosen != null || hasOriginal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Иллюстрация слова', style: TextStyle(
          fontWeight: FontWeight.w700,
        )),
        const SizedBox(height: 6),
        const Text('Выберите фото или рисунок JPG, PNG, WebP до 2 МБ. '
          'Файл сохраняется только на этом телефоне.',
          style: TextStyle(fontSize: 12)),
        const SizedBox(height: 10),
        if (hasPicture)
          FittedStudyArtwork(
            size: 132,
            image: _chosen != null
                ? MemoryImage(_chosen!)
                : FileImage(File(initial!)) as ImageProvider,
          ),
        const SizedBox(height: 9),
        Wrap(spacing: 8, runSpacing: 6, children: [
          OutlinedButton.icon(
            key: const ValueKey('teacher-word-pick-image'),
            onPressed: _busy ? null : _choose,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(hasPicture ? 'Заменить рисунок' : 'Загрузить рисунок'),
          ),
          if (hasPicture)
            TextButton.icon(
              onPressed: _clear,
              icon: const Icon(Icons.close),
              label: const Text('Убрать'),
            ),
        ]),
      ],
    );
  }
}
