import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

const green = Color(0xFF123F35);
const cream = Color(0xFFF7F3EA);
const bronze = Color(0xFFB69A72);
const muted = Color(0xFF60766C);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final jsonText = await rootBundle.loadString('assets/content/level1.json');
  runApp(AcademyApp(state: AcademyState(prefs, jsonDecode(jsonText) as Map<String, dynamic>)));
}

class AcademyState extends ChangeNotifier {
  AcademyState(this.prefs, this.catalog) {
    completed.addAll(prefs.getStringList('completed') ?? []);
    final jsonText = prefs.getString('teacher_lessons') ?? '[]';
    teacherLessons.addAll((jsonDecode(jsonText) as List).cast<Map<String, dynamic>>());
  }
  final SharedPreferences prefs;
  final Map<String, dynamic> catalog;
  final Set<String> completed = {};
  final List<Map<String, dynamic>> teacherLessons = [];
  List get units => catalog['modules'] as List;
  List get lessons => catalog['lessons'] as List;
  List<Map<String, dynamic>> get published => teacherLessons.where((x) => x['published'] == true).toList();

  Future<void> finish(String id) async {
    completed.add(id);
    await prefs.setStringList('completed', completed.toList());
    notifyListeners();
  }

  Future<void> save(Map<String, dynamic> data) async {
    final index = teacherLessons.indexWhere((x) => x['id'] == data['id']);
    if (index < 0) {
      teacherLessons.add(data);
    } else {
      teacherLessons[index] = data;
    }
    await _persist();
  }

  Future<void> remove(String id) async {
    teacherLessons.removeWhere((x) => x['id'] == id);
    await _persist();
  }

  Future<void> _persist() async {
    await prefs.setString('teacher_lessons', jsonEncode(teacherLessons));
    notifyListeners();
  }
}

class AcademyApp extends StatelessWidget {
  const AcademyApp({super.key, required this.state});
  final AcademyState state;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Арабская академия',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: cream,
      colorScheme: ColorScheme.fromSeed(seedColor: green, surface: cream),
      textTheme: GoogleFonts.manropeTextTheme().apply(bodyColor: green),
      appBarTheme: const AppBarTheme(backgroundColor: cream, foregroundColor: green),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
        backgroundColor: green, foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      )),
    ),
    home: HomeScreen(state: state),
  );
}

class NaskhText extends StatelessWidget {
  const NaskhText(this.value, {super.key, this.size = 24, this.color = green});
  final String value;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Text(value, textAlign: TextAlign.right, style: GoogleFonts.notoNaskhArabic(
      fontSize: size, height: 1.8, color: color,
    )),
  );
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFE9E0D4)),
      boxShadow: const [BoxShadow(color: Color(0x0B173F32), blurRadius: 20, offset: Offset(0, 8))],
    ),
    child: child,
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.state});
  final AcademyState state;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool teacher = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Арабская академия', style: TextStyle(fontWeight: FontWeight.w800)),
      actions: [
        PopupMenuButton<bool>(
          tooltip: 'Переключить демо-роль',
          icon: const Icon(Icons.swap_horiz_rounded),
          onSelected: (v) => setState(() => teacher = v),
          itemBuilder: (_) => const [
            PopupMenuItem(value: false, child: Text('Демо: ученица')),
            PopupMenuItem(value: true, child: Text('Демо: учительница')),
          ],
        ),
      ],
    ),
    body: AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) => teacher ? _teacherView(context) : _learnerView(context),
    ),
    bottomNavigationBar: Container(
      color: const Color(0xFFEDE6D9), padding: const EdgeInsets.all(10),
      child: Text(
        'ДЕМО · ${teacher ? 'учительница' : 'ученица'} · нет серверных аккаунтов и оплаты',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11, color: muted),
      ),
    ),
  );

  Widget _learnerView(BuildContext context) => ListView(
    padding: const EdgeInsets.all(17), children: [
      const NaskhText('السَّلَامُ عَلَيْكِ', size: 21),
      Text('Моё обучение', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(23),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [green, Color(0xFF2B6B59)]),
          borderRadius: BorderRadius.circular(25),
          boxShadow: const [BoxShadow(color: Color(0x33123F35), blurRadius: 25, offset: Offset(0, 9))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('ПЕРВЫЙ УРОВЕНЬ', style: TextStyle(color: bronze, letterSpacing: 2)),
          const NaskhText('اللُّغَةُ الْعَرَبِيَّةُ', color: Colors.white, size: 35),
          Text('Пройдено уроков: ${widget.state.completed.length} из 3',
            style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: (widget.state.completed.length / 3).clamp(0, 1).toDouble(),
            minHeight: 6, color: bronze, backgroundColor: Colors.white24),
          const SizedBox(height: 17),
          FilledButton(
            onPressed: () => _openLesson(context, widget.state.lessons.first as Map<String, dynamic>),
            style: FilledButton.styleFrom(backgroundColor: cream, foregroundColor: green),
            child: const Text('Начать обучение'),
          ),
        ]),
      ),
      const SizedBox(height: 22),
      const Text('Программа обучения', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      ...widget.state.units.asMap().entries.map((entry) {
        final unit = entry.value as Map<String, dynamic>;
        final free = unit['access_default'] == 'free';
        return Padding(
          padding: const EdgeInsets.only(bottom: 11),
          child: Panel(child: InkWell(
            onTap: () {
              if (free) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => UnitScreen(state: widget.state)));
              } else {
                _notice(context, 'Покупки ещё не подключены. Это демонстрация закрытого раздела.');
              }
            },
            child: Row(children: [
              CircleAvatar(backgroundColor: cream, child: Text((entry.key + 1).toString(),
                style: const TextStyle(color: green, fontWeight: FontWeight.bold))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(unit['title_ru'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                NaskhText(unit['title_ar'] as String, size: 17),
              ])),
              Icon(free ? Icons.chevron_right : Icons.lock_outline, color: muted),
            ]),
          )),
        );
      }),
      const SizedBox(height: 14),
      const Text('Дополнительные уроки', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      if (widget.state.published.isEmpty)
        const Panel(child: Text('Когда учительница опубликует урок, он появится здесь на этом же устройстве.')),
      ...widget.state.published.map((item) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Panel(child: ListTile(
          title: Text(item['title'] as String),
          subtitle: Text(item['free'] == true ? 'Бесплатно' : 'Платно — демо-блокировка'),
          trailing: Icon(item['free'] == true ? Icons.play_circle_outline : Icons.lock),
          onTap: () {
            if (item['free'] == true) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ExtraLessonScreen(data: item)));
            } else {
              _notice(context, 'Платный доступ будет подключён позже.');
            }
          },
        )),
      )),
    ],
  );

  Widget _teacherView(BuildContext context) => ListView(
    padding: const EdgeInsets.all(17),
    children: [
      const NaskhText('الْعِلْمُ نُورٌ', size: 31),
      const Text('Кабинет учительницы', style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      const Panel(child: Text('Это демонстрационный редактор. Уроки сохраняются только на текущем телефоне.')),
      const SizedBox(height: 15),
      FilledButton.icon(
        onPressed: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => TeacherEditor(state: widget.state))),
        icon: const Icon(Icons.add_circle_outline), label: const Text('Добавить урок'),
      ),
      const SizedBox(height: 22),
      const Text('Материалы учительницы', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      if (widget.state.teacherLessons.isEmpty)
        const Panel(child: Text('Уроков пока нет. Создайте первый материал.')),
      ...widget.state.teacherLessons.map((item) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Panel(child: Row(children: [
          Icon(item['published'] == true ? Icons.check_circle_outline : Icons.edit_note, color: green),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(item['published'] == true ? 'Опубликован · локально' : 'Черновик',
              style: const TextStyle(fontSize: 12, color: muted)),
          ])),
          IconButton(tooltip: 'Изменить', icon: const Icon(Icons.edit), onPressed: () =>
            Navigator.push(context, MaterialPageRoute(builder: (_) =>
              TeacherEditor(state: widget.state, original: item)))),
          IconButton(tooltip: 'Удалить', icon: const Icon(Icons.delete_outline),
            onPressed: () => widget.state.remove(item['id'] as String)),
        ])),
      )),
      const SizedBox(height: 15),
      const Panel(child: Column(children: [
        ListTile(leading: Icon(Icons.groups), title: Text('Ученицы и группы'),
          subtitle: Text('Подключим вместе с сервером')),
        Divider(),
        ListTile(leading: Icon(Icons.assignment_turned_in_outlined),
          title: Text('Проверка заданий'), subtitle: Text('Пока не подключена')),
        Divider(),
        ListTile(leading: Icon(Icons.payment), title: Text('Платежи'),
          subtitle: Text('Пока не подключены')),
      ])),
    ],
  );

  void _openLesson(BuildContext context, Map<String, dynamic> data) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => LessonScreen(state: widget.state, lesson: data)));
}

class UnitScreen extends StatelessWidget {
  const UnitScreen({super.key, required this.state});
  final AcademyState state;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Раздел 1 · Знакомство')),
    body: ListView(padding: const EdgeInsets.all(17), children: [
      ...state.lessons.map((item) {
        final lesson = item as Map<String, dynamic>;
        return Padding(padding: const EdgeInsets.only(bottom: 10), child: Panel(child: ListTile(
          title: Text(lesson['title'] as String),
          subtitle: NaskhText(lesson['title_ar'] as String, size: 20),
          trailing: Icon(state.completed.contains(lesson['id']) ? Icons.check_circle : Icons.chevron_right,
            color: green),
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => LessonScreen(state: state, lesson: lesson))),
        )));
      }),
    ]),
  );
}

class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key, required this.state, required this.lesson});
  final AcademyState state;
  final Map<String, dynamic> lesson;
  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  int? selected;
  bool checked = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.lesson;
    final items = data['dialogue'] as List;
    final words = data['vocabulary'] as List;
    final answers = data['options'] as List;
    return Scaffold(
      appBar: AppBar(title: Text(data['title'] as String)),
      body: ListView(padding: const EdgeInsets.all(17), children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: green, borderRadius: BorderRadius.circular(24)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('УЧЕБНЫЙ УРОК · ЧЕРНОВИК', style: TextStyle(color: bronze, fontSize: 11)),
            NaskhText(data['title_ar'] as String, size: 30, color: Colors.white),
            Text(data['goal'] as String, style: const TextStyle(color: Colors.white)),
          ]),
        ),
        const SizedBox(height: 20),
        const Text('Диалог', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
        ...items.map((entry) {
          final line = entry as Map<String, dynamic>;
          return Padding(padding: const EdgeInsets.only(top: 9),
            child: Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              NaskhText(line['ar'] as String, size: 24),
              Text(line['ru'] as String),
            ])));
        }),
        const SizedBox(height: 20),
        const Text('Словарь', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
        Panel(child: Column(children: [
          ...words.map((entry) {
            final line = entry as Map<String, dynamic>;
            return Row(children: [
              Expanded(child: Text(line['ru'] as String)),
              Flexible(child: NaskhText(line['ar'] as String, size: 24)),
            ]);
          }),
        ])),
        const SizedBox(height: 20),
        const Text('Грамматика', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
        Panel(child: Text(data['grammar'] as String)),
        const SizedBox(height: 20),
        const Text('Проверка знаний', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(data['question'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
          RadioGroup<int>(
            groupValue: selected,
            onChanged: (value) => setState(() { selected = value; checked = false; }),
            child: Column(children: [
              ...answers.asMap().entries.map((x) => RadioListTile<int>(
                value: x.key, contentPadding: EdgeInsets.zero,
                title: Text(x.value.toString()),
              )),
            ]),
          ),
          if (checked)
            Text(selected == data['correct'] ? 'Правильно!' : 'Неверно, повторите материал.',
              style: const TextStyle(color: green, fontWeight: FontWeight.bold)),
          FilledButton(
            onPressed: selected == null ? null : () => setState(() => checked = true),
            child: const Text('Проверить ответ'),
          ),
        ])),
        const SizedBox(height: 18),
        const Text('Домашнее задание', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
        Panel(child: Text(data['homework'] as String)),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: checked && selected == data['correct'] ? () async {
            await widget.state.finish(data['id'] as String);
            if (context.mounted) _notice(context, 'Урок отмечен как изученный на этом телефоне.');
          } : null,
          icon: const Icon(Icons.check_circle_outline), label: const Text('Завершить урок'),
        ),
        const SizedBox(height: 16),
        const Text('Черновые тексты и огласовки требуют редакторской проверки перед публикацией.',
          style: TextStyle(fontSize: 12, color: muted)),
      ]),
    );
  }
}

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

  @override
  void initState() {
    super.initState();
    final old = widget.original ?? {};
    title = TextEditingController(text: old['title'] as String? ?? '');
    arabic = TextEditingController(text: old['arabic'] as String? ?? '');
    description = TextEditingController(text: old['description'] as String? ?? '');
    assignment = TextEditingController(text: old['assignment'] as String? ?? '');
    video = TextEditingController(text: old['video'] as String? ?? '');
    published = old['published'] == true;
    free = old['free'] != false;
  }

  @override
  void dispose() {
    title.dispose(); arabic.dispose(); description.dispose();
    assignment.dispose(); video.dispose(); super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Редактор урока')),
    body: Form(key: formKey, child: ListView(padding: const EdgeInsets.all(17), children: [
      const Panel(child: Text('Сохранение только на текущем устройстве. Загрузка видеофайлов с телефона появится после подключения сервера.')),
      const SizedBox(height: 15),
      TextFormField(controller: title, maxLength: 100,
        decoration: const InputDecoration(labelText: 'Название урока'),
        validator: (v) => v == null || v.trim().isEmpty ? 'Введите название' : null),
      const SizedBox(height: 10),
      TextFormField(controller: arabic, textDirection: TextDirection.rtl,
        decoration: const InputDecoration(labelText: 'Арабский заголовок')),
      const SizedBox(height: 10),
      TextFormField(controller: description, maxLines: 5,
        decoration: const InputDecoration(labelText: 'Текст урока')),
      const SizedBox(height: 10),
      TextFormField(controller: assignment, maxLines: 4,
        decoration: const InputDecoration(labelText: 'Домашнее задание')),
      const SizedBox(height: 10),
      TextFormField(controller: video,
        decoration: const InputDecoration(labelText: 'Прямая HTTPS-ссылка на видео (MP4/HLS)'),
        validator: (value) {
          if (value == null || value.trim().isEmpty) return null;
          final uri = Uri.tryParse(value.trim());
          return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
              ? null : 'Укажите корректную HTTPS-ссылку';
        }),
      SwitchListTile(title: const Text('Бесплатный урок'),
        subtitle: const Text('Платная проверка пока не подключена'),
        value: free, onChanged: (v) => setState(() => free = v)),
      SwitchListTile(title: const Text('Опубликовать'),
        subtitle: const Text('Показывать в демо-кабинете ученицы'),
        value: published, onChanged: (v) => setState(() => published = v)),
      const SizedBox(height: 17),
      FilledButton.icon(
        icon: const Icon(Icons.save_outlined), label: const Text('Сохранить'),
        onPressed: () async {
          if (!formKey.currentState!.validate()) return;
          await widget.state.save({
            'id': widget.original?['id'] ?? DateTime.now().microsecondsSinceEpoch.toString(),
            'title': title.text.trim(), 'arabic': arabic.text.trim(),
            'description': description.text.trim(), 'assignment': assignment.text.trim(),
            'video': video.text.trim(), 'published': published, 'free': free,
          });
          if (context.mounted) Navigator.pop(context);
        },
      ),
    ])),
  );
}

class ExtraLessonScreen extends StatefulWidget {
  const ExtraLessonScreen({super.key, required this.data});
  final Map<String, dynamic> data;
  @override State<ExtraLessonScreen> createState() => _ExtraLessonScreenState();
}

class _ExtraLessonScreenState extends State<ExtraLessonScreen> {
  VideoPlayerController? controller;
  String? error;
  @override
  void initState() { super.initState(); _load(); }

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
  void dispose() { controller?.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final ready = controller?.value.isInitialized ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(widget.data['title'] as String)),
      body: ListView(padding: const EdgeInsets.all(17), children: [
        NaskhText(widget.data['arabic'] as String? ?? '', size: 30),
        const SizedBox(height: 14),
        if ((widget.data['video'] as String? ?? '').isNotEmpty)
          Panel(child: Column(children: [
            if (ready) AspectRatio(aspectRatio: controller!.value.aspectRatio,
              child: VideoPlayer(controller!))
            else Container(height: 140, alignment: Alignment.center,
              child: Text(error ?? 'Загрузка видео...')),
            if (ready)
              TextButton.icon(
                icon: Icon(controller!.value.isPlaying ? Icons.pause : Icons.play_arrow),
                label: Text(controller!.value.isPlaying ? 'Пауза' : 'Воспроизвести'),
                onPressed: () {
                  if (controller!.value.isPlaying) { controller!.pause(); } else { controller!.play(); }
                  setState(() {});
                },
              ),
          ])),
        const SizedBox(height: 15),
        Panel(child: Text(widget.data['description'] as String? ?? '')),
        const SizedBox(height: 15),
        const Text('Домашнее задание', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
        Panel(child: Text(widget.data['assignment'] as String? ?? '')),
      ]),
    );
  }
}

void _notice(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}
