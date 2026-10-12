import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../core/academy_state.dart';
import '../../ui/components.dart';
import '../../ui/premium_art.dart';
import 'content_editor.dart';

class TeacherEditor extends StatefulWidget {
  const TeacherEditor({super.key, required this.state, this.original});
  final AcademyState state;
  final Map<String, dynamic>? original;
  @override
  State<TeacherEditor> createState() => _TeacherEditorState();
}

class _TeacherEditorState extends State<TeacherEditor> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController title;
  late final TextEditingController arabic;
  late final TextEditingController description;
  late final TextEditingController assignment;
  late final TextEditingController video;
  late bool published;
  late bool free;
  late final LessonContentDraft content;

  @override
  void initState() {
    super.initState();
    final old = widget.original ?? {};
    content = LessonContentDraft(old);
    title = TextEditingController(text: old['title'] as String? ?? '');
    arabic = TextEditingController(
      text: (old['arabic'] ?? old['title_ar']) as String? ?? '',
    );
    description = TextEditingController(
      text: old['description'] as String? ?? '',
    );
    assignment = TextEditingController(
      text: old['assignment'] as String? ?? '',
    );
    video = TextEditingController(text: old['video'] as String? ?? '');
    published = old['published'] == true;
    free = old['free'] != false;
  }

  @override
  void dispose() {
    title.dispose();
    arabic.dispose();
    description.dispose();
    assignment.dispose();
    video.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Редактор урока')),
    body: Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.all(17),
        children: [
          const Row(
            children: [
              ArtworkIcon('homework', size: 64),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Конструктор уроков',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        fontVariations: [FontVariation('wght', 800)],
                        color: green,
                      ),
                    ),
                    Text(
                      'Текст, задание и видеоматериал',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Panel(
            child: Text(
              'Демо: уроки сохраняются только на этом устройстве. Для загрузки видео с телефона и публикации другим ученицам требуется сервер.',
            ),
          ),
          const SizedBox(height: 15),
          TextFormField(
            controller: title,
            maxLength: 100,
            decoration: const InputDecoration(labelText: 'Название урока'),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Введите название' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: arabic,
            textDirection: TextDirection.rtl,
            decoration: const InputDecoration(labelText: 'Арабский заголовок'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: description,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Текст урока'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: assignment,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Домашнее задание'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: video,
            decoration: const InputDecoration(
              labelText: 'Прямая HTTPS-ссылка на видео (MP4/HLS)',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return null;
              final uri = Uri.tryParse(value.trim());
              return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
                  ? null
                  : 'Укажите корректную HTTPS-ссылку';
            },
          ),
          LessonContentEditor(draft: content),
          const SizedBox(height: 14),
          SwitchListTile(
            title: const Text('Бесплатный урок'),
            subtitle: const Text('Платная проверка пока не подключена'),
            value: free,
            onChanged: (v) => setState(() => free = v),
          ),
          SwitchListTile(
            title: const Text('Опубликовать'),
            subtitle: const Text('Показывать в демо-кабинете ученицы'),
            value: published,
            onChanged: (v) => setState(() => published = v),
          ),
          const SizedBox(height: 17),
          FilledButton.icon(
            icon: const Icon(Icons.save_outlined),
            label: const Text('Сохранить'),
            onPressed: () => guardedAction(context, () async {
              if (!formKey.currentState!.validate()) return;
              await widget.state.save({
                'id': widget.original?['id'] ?? AcademyState.newId(),
                'title': title.text.trim(),
                'arabic': arabic.text.trim(),
                'description': description.text.trim(),
                'assignment': assignment.text.trim(),
                'video': video.text.trim(),
                'published': published,
                'free': free,
                ...content.toJson(),
              });
              if (context.mounted) Navigator.pop(context);
            }),
          ),
        ],
      ),
    ),
  );
}

class ExtraLessonScreen extends StatefulWidget {
  const ExtraLessonScreen({super.key, required this.data});
  final Map<String, dynamic> data;
  @override
  State<ExtraLessonScreen> createState() => _ExtraLessonScreenState();
}

class _ExtraLessonScreenState extends State<ExtraLessonScreen> {
  VideoPlayerController? controller;
  String? error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final link = widget.data['video'] as String? ?? '';
    if (link.isEmpty) return;
    final uri = Uri.tryParse(link);
    if (uri == null || uri.scheme != 'https') return;
    final player = VideoPlayerController.networkUrl(uri);
    controller = player;
    try {
      await player.initialize();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => error = 'Не удалось открыть видео.');
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = controller?.value.isInitialized ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(widget.data['title'] as String)),
      body: ListView(
        padding: const EdgeInsets.all(17),
        children: [
          NaskhText(widget.data['arabic'] as String? ?? '', size: 30),
          const SizedBox(height: 14),
          if ((widget.data['video'] as String? ?? '').isNotEmpty)
            Panel(
              child: Column(
                children: [
                  if (ready)
                    AspectRatio(
                      aspectRatio: controller!.value.aspectRatio,
                      child: VideoPlayer(controller!),
                    )
                  else
                    Container(
                      height: 140,
                      alignment: Alignment.center,
                      child: Text(error ?? 'Загрузка видео...'),
                    ),
                  if (ready)
                    TextButton.icon(
                      icon: Icon(
                        controller!.value.isPlaying
                            ? Icons.pause
                            : Icons.play_arrow,
                      ),
                      label: Text(
                        controller!.value.isPlaying ? 'Пауза' : 'Воспроизвести',
                      ),
                      onPressed: () {
                        if (controller!.value.isPlaying) {
                          controller!.pause();
                        } else {
                          controller!.play();
                        }
                        setState(() {});
                      },
                    ),
                ],
              ),
            ),
          const SizedBox(height: 15),
          Panel(child: Text(widget.data['description'] as String? ?? '')),
          const SizedBox(height: 15),
          const Text(
            'Домашнее задание',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          Panel(child: Text(widget.data['assignment'] as String? ?? '')),
        ],
      ),
    );
  }
}
