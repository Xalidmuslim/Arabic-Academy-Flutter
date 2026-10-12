import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'ui/premium_art.dart';

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
      fontSize: size, height: 1.65, color: color,
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
      color: Colors.white, borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE9E0D4)),
      boxShadow: const [BoxShadow(color: Color(0x16173F32), blurRadius: 18, offset: Offset(0, 7))],
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
      toolbarHeight: 68,
      titleSpacing: 18,
      title: Row(children: [
        Container(
          width: 41, height: 41,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: green,
            borderRadius: BorderRadius.circular(13),
            boxShadow: const [BoxShadow(
              color: Color(0x30123F35), blurRadius: 12, offset: Offset(0, 5))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(PremiumArt.emblem, width: 41, height: 41,
              fit: BoxFit.cover, filterQuality: FilterQuality.medium),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('АРАБСКАЯ АКАДЕМИЯ',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15, color: green, fontWeight: FontWeight.w800,
                letterSpacing: 0.35)),
            Text(teacher ? 'Кабинет учительницы' : 'Пространство обучения',
              style: const TextStyle(fontSize: 11, color: muted)),
          ],
        )),
      ]),
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
        const SizedBox(width: 7),
      ],
    ),
    body: ArtworkBackdrop(
      child: AnimatedBuilder(
        animation: widget.state,
        builder: (context, _) => teacher ? _teacherView(context) : _learnerView(context),
      ),
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Container(
        color: const Color(0xFFECE6D9),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.science_outlined, size: 15, color: muted),
            const SizedBox(width: 7),
            Flexible(child: Text(
              'ДЕМО · ${teacher ? 'учительница' : 'ученица'} · без сервера и оплаты',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: muted),
            )),
          ],
        ),
      ),
    ),
  );

  Widget _learnerView(BuildContext context) {
    final completedCount = widget.state.completed.length.clamp(0, 3);
    final progress = completedCount / 3.0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 25),
      children: [
        Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Добро пожаловать',
                style: TextStyle(fontSize: 12, color: muted)),
              Text('Моё обучение', style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(color: green, fontWeight: FontWeight.w800, fontSize: 24)),
            ],
          )),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE5ECE4),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const NaskhText('السَّلَامُ عَلَيْكِ', size: 16),
          ),
        ]),
        const SizedBox(height: 17),
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF123F35), Color(0xFF205948), Color(0xFF2F705B)],
            ),
            borderRadius: BorderRadius.circular(26),
            boxShadow: const [BoxShadow(
              color: Color(0x30123F35), blurRadius: 27, offset: Offset(0, 12))],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(children: [
            const ArtworkHeroLayer(),
            const Positioned(
              right: -35, top: -42,
              child: Icon(Icons.auto_stories_rounded,
                color: Color(0x0EFFFFFF), size: 195),
            ),
            Positioned(
              right: -70, bottom: -115,
              child: Container(
                width: 215, height: 215,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0x26FFFFFF)),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(21),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0x24FFFFFF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text('ПЕРВЫЙ УРОВЕНЬ',
                        style: TextStyle(fontSize: 10, letterSpacing: 1.4,
                          fontWeight: FontWeight.w700, color: Color(0xFFE1CCAD))),
                    ),
                    const Spacer(),
                    const Icon(Icons.stars_rounded,
                      size: 20, color: Color(0xFFE1CCAD)),
                  ]),
                  const SizedBox(height: 14),
                  const NaskhText('اللُّغَةُ الْعَرَبِيَّةُ',
                    size: 33, color: Colors.white),
                  const SizedBox(height: 2),
                  const Text('Ваш путь к арабскому языку',
                    style: TextStyle(fontSize: 12, color: Color(0xFFE1EAE4))),
                  const SizedBox(height: 20),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Пройдено $completedCount из 3 уроков',
                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                    Text('${(progress * 100).round()}%',
                      style: const TextStyle(color: Color(0xFFE1CCAD),
                        fontWeight: FontWeight.w800, fontSize: 13)),
                  ]),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 7,
                      color: const Color(0xFFDEC9A5),
                      backgroundColor: Colors.white24,
                    ),
                  ),
                  const SizedBox(height: 19),
                  FilledButton.icon(
                    onPressed: () {
                      final lessons = widget.state.lessons.cast<Map<String, dynamic>>();
                      final next = lessons.firstWhere(
                        (x) => !widget.state.completed.contains(x['id']),
                        orElse: () => lessons.first,
                      );
                      _openLesson(context, next);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: cream,
                      foregroundColor: green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                    ),
                    icon: const Icon(Icons.play_circle_outline_rounded),
                    label: Text(completedCount == 0
                      ? 'Начать обучение' : 'Продолжить обучение',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
          ]),
        ),
        const SizedBox(height: 25),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Программа обучения',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: green)),
          Text('${widget.state.units.length} разделов',
            style: const TextStyle(fontSize: 11, color: muted)),
        ]),
        const SizedBox(height: 12),
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
              ArtworkIcon(PremiumArt.icons[entry.key % PremiumArt.icons.length], size: 62),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(unit['title_ru'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                NaskhText(unit['title_ar'] as String, size: 17),
              ])),
              Icon(free ? Icons.chevron_right_rounded : Icons.lock_outline_rounded,
                color: muted, size: 21),
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
  }

  Widget _teacherView(BuildContext context) {
    final total = widget.state.teacherLessons.length;
    final published = widget.state.teacherLessons
      .where((item) => item['published'] == true).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 25),
      children: [
        Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Панель преподавателя',
                style: TextStyle(color: muted, fontSize: 12)),
              Text('Моя академия', style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontSize: 24, fontWeight: FontWeight.w800, color: green)),
            ],
          )),
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFE4EBE3),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const ArtworkIcon('books', size: 48),
          ),
        ]),
        const SizedBox(height: 17),
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [green, Color(0xFF286B56)],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [BoxShadow(
              color: Color(0x26123F35), blurRadius: 20, offset: Offset(0, 9))],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(children: [
            const ArtworkHeroLayer(),
            const Positioned(
              right: -30, top: -30,
              child: Icon(Icons.local_library_outlined,
                size: 155, color: Color(0x13FFFFFF)),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 21, vertical: 19),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('УПРАВЛЕНИЕ ОБУЧЕНИЕМ',
                    style: TextStyle(fontSize: 10, letterSpacing: 1.3,
                      fontWeight: FontWeight.w700, color: Color(0xFFE0CBA8))),
                  SizedBox(height: 6),
                  NaskhText('الْعِلْمُ نُورٌ', size: 27, color: Colors.white),
                  Text('Создавайте собственные уроки',
                    style: TextStyle(color: Color(0xFFE4EDE7), fontSize: 12)),
                ],
              ),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _teacherMetric('Всего', total, Icons.library_books_outlined)),
          const SizedBox(width: 8),
          Expanded(child: _teacherMetric('Опубликовано', published, Icons.check_circle_outline)),
          const SizedBox(width: 8),
          Expanded(child: _teacherMetric('Черновики', total - published, Icons.edit_note_outlined)),
        ]),
        const SizedBox(height: 23),
        const Text('Быстрые действия',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: green)),
        const SizedBox(height: 11),
        FilledButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => TeacherEditor(state: widget.state))),
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('Создать новый урок',
            style: TextStyle(fontWeight: FontWeight.w800)),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17)),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _teacherAction(context, 'Видео', 'video')),
          const SizedBox(width: 9),
          Expanded(child: _teacherAction(context, 'Задание', 'homework')),
          const SizedBox(width: 9),
          Expanded(child: _teacherAction(context, 'Тест', 'tests')),
        ]),
        const SizedBox(height: 13),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: const Color(0xFFEFE8DB),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(children: [
            Icon(Icons.info_outline_rounded, color: muted, size: 19),
            SizedBox(width: 10),
            Expanded(child: Text(
              'Пока уроки сохраняются только на этом устройстве. Общий доступ появится после подключения сервера.',
              style: TextStyle(fontSize: 11, color: muted),
            )),
          ]),
        ),
        const SizedBox(height: 22),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Мои материалы',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: green)),
          Text('$total уроков', style: const TextStyle(color: muted, fontSize: 11)),
        ]),
        const SizedBox(height: 12),
        if (widget.state.teacherLessons.isEmpty)
          const Panel(child: Column(children: [
            Icon(Icons.auto_stories_outlined, color: muted, size: 30),
            SizedBox(height: 8),
            Text('Пока нет созданных уроков',
              style: TextStyle(fontWeight: FontWeight.w800, color: green)),
            SizedBox(height: 5),
            Text('Добавьте первый материал кнопкой выше.',
              style: TextStyle(color: muted, fontSize: 12)),
          ])),
        ...widget.state.teacherLessons.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Panel(child: Row(children: [
            Icon(item['published'] == true
              ? Icons.check_circle_outline : Icons.edit_note, color: green),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['title'] as String,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(item['published'] == true ? 'Опубликован · локально' : 'Черновик',
                  style: const TextStyle(fontSize: 12, color: muted)),
              ],
            )),
            IconButton(
              tooltip: 'Изменить',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => TeacherEditor(state: widget.state, original: item))),
            ),
            IconButton(
              tooltip: 'Удалить',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final yes = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Удалить урок?'),
                    content: const Text('Урок будет удалён с этого телефона.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Отмена')),
                      TextButton(onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text('Удалить')),
                    ],
                  ),
                );
                if (yes == true) await widget.state.remove(item['id'] as String);
              },
            ),
          ])),
        )),
        const SizedBox(height: 20),
        const Text('Управление школой',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: green)),
        const SizedBox(height: 11),
        const Panel(child: Column(children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.groups_outlined, color: green),
            title: Text('Ученицы и группы'),
            subtitle: Text('Подключим вместе с сервером')),
          Divider(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.assignment_turned_in_outlined, color: green),
            title: Text('Проверка заданий'),
            subtitle: Text('Пока не подключена')),
          Divider(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.payment_outlined, color: green),
            title: Text('Платежи'),
            subtitle: Text('Пока не подключены')),
        ])),
      ],
    );
  }

  Widget _teacherAction(BuildContext context, String title, String art) =>
    Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => TeacherEditor(state: widget.state))),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE8DFD3)),
            borderRadius: BorderRadius.circular(17)),
          child: Column(children: [
            ArtworkIcon(art, size: 63),
            const SizedBox(height: 3),
            Text(title, style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: green)),
          ]),
        ),
      ),
    );

  Widget _teacherMetric(String name, int count, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: const Color(0xFFEAE0D4)),
    ),
    child: Column(children: [
      ArtworkIcon(
        icon == Icons.library_books_outlined ? 'books'
          : icon == Icons.check_circle_outline ? 'tests' : 'homework',
        size: 43),

      const SizedBox(height: 5),
      Text('$count', style: const TextStyle(
        fontWeight: FontWeight.w800, fontSize: 21, color: green)),
      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 10, color: muted)),
    ]),
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
          leading: const ArtworkIcon('books', size: 47),
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
