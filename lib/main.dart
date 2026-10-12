import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'ui/premium_art.dart';
import 'ui/neumorphic_components.dart';
import 'ui/reference_components.dart';
import 'ui/welcome_screen.dart';

const green = Color(0xFF123F35);
const cream = NeumorphicPalette.background;
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
    home: state.prefs.getBool('welcome_seen') == true
      ? HomeScreen(state: state)
      : Builder(builder: (welcomeContext) => ReferenceWelcomeScreen(
          onStart: () async {
            await state.prefs.setBool('welcome_seen', true);
            if (welcomeContext.mounted) {
              Navigator.of(welcomeContext).pushReplacement(MaterialPageRoute(
                builder: (_) => HomeScreen(state: state)));
            }
          },
        )),

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
      color: NeumorphicPalette.surface, borderRadius: BorderRadius.circular(20),
      border: Border.all(color: NeumorphicPalette.outline),
      boxShadow: const [
        BoxShadow(color: Color(0xBFFFFFFF), blurRadius: 10, offset: Offset(-4, -4)),
        BoxShadow(color: Color(0x358D7C65), blurRadius: 14, offset: Offset(5, 6)),
      ],
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
  int selectedTab = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: NeumorphicPalette.background,
      foregroundColor: NeumorphicPalette.ink,
      toolbarHeight: 67,
      titleSpacing: 18,
      title: Row(children: [
        Container(
          width: 41, height: 41,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: NeumorphicPalette.surface,
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
              style: TextStyle(fontSize: 15, color: NeumorphicPalette.ink, fontWeight: FontWeight.w800,
                letterSpacing: 0.35)),
            Text(teacher ? 'Кабинет учительницы' : 'Пространство обучения',
              style: const TextStyle(fontSize: 11, color: NeumorphicPalette.secondary))),
          ],
        )),
      ]),
      actions: [
        PopupMenuButton<bool>(
          tooltip: 'Переключить демо-роль',
          icon: const Icon(Icons.swap_horiz_rounded),
          onSelected: (v) => setState(() { teacher = v; selectedTab = 0; }),
          itemBuilder: (_) => const [
            PopupMenuItem(value: false, child: Text('Демо: ученица')),
            PopupMenuItem(value: true, child: Text('Демо: учительница')),
          ],
        ),
        const SizedBox(width: 7),
      ],
    ),
    body: AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) => teacher
        ? (selectedTab == 0 ? _teacherView(context) : _auxiliaryPage(context))
        : (selectedTab == 0 ? _learnerView(context) : _auxiliaryPage(context)),
    ),
    bottomNavigationBar: NavigationBar(
      height: 71,
      backgroundColor: NeumorphicPalette.surface,
      indicatorColor: const Color(0xFFDDDCC7),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      selectedIndex: selectedTab,
      onDestinationSelected: (v) => setState(() => selectedTab = v),
      destinations: teacher ? const [
        NavigationDestination(icon: ArtworkIcon('books', size: 31), label: 'Главная'),
        NavigationDestination(icon: ArtworkIcon('video', size: 31), label: 'Курсы'),
        NavigationDestination(icon: ArtworkIcon('students', size: 31), label: 'Ученицы'),
        NavigationDestination(icon: ArtworkIcon('tests', size: 31), label: 'Задания'),
        NavigationDestination(icon: ArtworkIcon('settings', size: 31), label: 'Ещё'),
      ] : const [
        NavigationDestination(icon: ArtworkIcon('books', size: 31), label: 'Главная'),
        NavigationDestination(icon: ArtworkIcon('video', size: 31), label: 'Курсы'),
        NavigationDestination(icon: ArtworkIcon('homework', size: 31), label: 'Задания'),
        NavigationDestination(icon: ArtworkIcon('microphone', size: 31), label: 'Разговор'),
        NavigationDestination(icon: ArtworkIcon('settings', size: 31), label: 'Профиль'),
      ],
    ),
  );

  Widget _auxiliaryPage(BuildContext context) {
    final studentTitles = ['','Курсы','Задания','Разговор','Профиль'];
    final teacherTitles = ['','Мои курсы','Ученицы','Домашние задания','Ещё'];
    final title = teacher ? teacherTitles[selectedTab] : studentTitles[selectedTab];
    return ListView(padding: const EdgeInsets.all(18), children: [
      Text(title, style: const TextStyle(fontSize: 23,
        fontWeight: FontWeight.w800,color: green)),
      const SizedBox(height: 15),
      if (!teacher && selectedTab == 1) ...[
        Panel(child: ListTile(
          leading: const ArtworkIcon('books',size:57),
          title: const Text('Базовый уровень 1'),
          subtitle: const Text('Бесплатный ознакомительный раздел'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => UnitScreen(state: widget.state))),
        )),
        const SizedBox(height: 12),
        ...widget.state.units.skip(1).map((u) => Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Panel(child: ListTile(
            title: Text((u as Map)['title_ru'] as String),
            trailing: const Icon(Icons.lock_outline,color: muted),
            onTap: () => _notice(context, 'Платный доступ пока не подключён.'),
          )),
        )),
      ] else if (!teacher && selectedTab == 2) ...[
        const Text('Задания первого уровня', style: TextStyle(color: muted)),
        const SizedBox(height: 12),
        ...widget.state.lessons.map((lesson) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Panel(child: ListTile(
            leading: const ArtworkIcon('homework', size: 53),
            title: Text((lesson as Map)['title'] as String),
            subtitle: const Text('Открыть проверку знаний'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => LessonScreen(state: widget.state,
                lesson: lesson.cast<String,dynamic>(), initialTab: 3))),
          )),
        )),
      ] else if (teacher && selectedTab == 1) ...[
        FilledButton.icon(
          onPressed: () => Navigator.push(context,MaterialPageRoute(
            builder: (_) => TeacherEditor(state: widget.state))),
          icon: const Icon(Icons.add),
          label: const Text('Добавить урок'),
        ),
        const SizedBox(height: 13),
        ...widget.state.teacherLessons.map((x) => Panel(
          child: ListTile(
            title: Text(x['title'] as String),
            subtitle: Text(x['published'] == true ? 'Опубликован локально' : 'Черновик'),
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => TeacherEditor(state: widget.state, original: x))),
          ),
        )),
      ] else
        Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline,color: green),
          const SizedBox(height: 10),
          Text(teacher
            ? 'Раздел будет доступен после подключения серверных аккаунтов и групп.'
            : selectedTab == 3
              ? 'Онлайн-разговоры и оценка произношения появятся после подключения сервера и аудиосервиса.'
              : 'Сейчас это демонстрационная версия. Регистрация и синхронизация аккаунтов пока не подключены.'),
          const SizedBox(height: 8),
          const Text('Данные этой версии сохраняются только на устройстве.',
            style: TextStyle(color: muted,fontSize: 12)),
        ])),
    ]);
  }

  Widget _learnerView(BuildContext context) {
    final totalLessons = widget.state.lessons.length;
    final completedCount = widget.state.completed.length.clamp(0, totalLessons);
    final progress = totalLessons == 0 ? 0.0 : completedCount / totalLessons;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 25),
      children: [
        Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Арабский каждый день',
                style: TextStyle(fontSize: 12, color: muted)),
              Text('Байна Ядайк', style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(color: green, fontWeight: FontWeight.w800, fontSize: 26)),
              const Text('Арабский язык в твоих руках',
                style: TextStyle(fontSize: 11, color: NeumorphicPalette.secondary)),
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
        ReferenceCourseHero(
          progress: progress, completed: completedCount, total: totalLessons,
          onContinue: () {
            final lessons = widget.state.lessons.cast<Map<String,dynamic>>();
            if (lessons.isEmpty) { _notice(context, 'Уроки пока не добавлены.'); return; }
            final next = lessons.firstWhere(
              (x) => !widget.state.completed.contains(x['id']),
              orElse: () => lessons.last,
            );
            _openLesson(context, next);
          },
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 11,
          mainAxisSpacing: 11,
          childAspectRatio: 0.94,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            ReferenceFeatureTile(
              title: 'Уроки', subtitle: 'Диалоги и тексты',
              image: 'assets/images/feature_lessons.webp',
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => UnitScreen(state: widget.state))),
            ),
            ReferenceFeatureTile(
              title: 'Задания', subtitle: 'Практика и упражнения',
              image: 'assets/images/feature_homework.webp',
              onTap: () => setState(() => selectedTab = 2),
            ),
            ReferenceFeatureTile(
              title: 'Произношение', subtitle: 'Разговорная практика',
              image: 'assets/images/feature_pronunciation.webp',
              onTap: () => setState(() => selectedTab = 3),
            ),
            ReferenceFeatureTile(
              title: 'Словарь', subtitle: 'Арабские слова',
              image: 'assets/images/feature_vocabulary.webp',
              onTap: () {
                final lessons = widget.state.lessons.cast<Map<String,dynamic>>();
                if (lessons.isEmpty) return;
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => LessonScreen(
                    state: widget.state, lesson: lessons.first, initialTab: 1)));
              },
            ),
          ],
        ),
        const SizedBox(height: 22),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,children:[
          const Text('Моё обучение',style: TextStyle(
            fontSize: 18,fontWeight: FontWeight.w800,color: green)),
          Text('$completedCount из $totalLessons',
            style: const TextStyle(fontSize: 11,color: muted)),
        ]),
        const SizedBox(height: 9),
        ...widget.state.lessons.take(3).map((raw) {
          final lesson = raw as Map<String,dynamic>;
          final done = widget.state.completed.contains(lesson['id']);
          return Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Material(
              color: const Color(0xFFFFFCF7),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _openLesson(context, lesson),
                child: Padding(
                  padding: const EdgeInsets.all(9),
                  child: Row(children:[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset('assets/images/feature_classroom.webp',
                        width: 54,height: 47,fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 11),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,children:[
                      Text(lesson['title'] as String,
                        maxLines: 1,overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5,fontWeight: FontWeight.w700)),
                      Text(done ? 'Завершён' : 'Для изучения',
                        style: TextStyle(fontSize: 11,
                          color: done ? const Color(0xFF178257) : muted)),
                    ])),
                    Icon(done ? Icons.check_circle : Icons.play_circle_fill,
                      color: const Color(0xFF116647),size: 23),
                  ]),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 20),
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
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 28),
      children: [
        const Text('Кабинет преподавателя',
          style: TextStyle(fontSize: 22,fontWeight: FontWeight.w800,color: green)),
        const SizedBox(height: 13),
        const ReferencePhotoHeader(
          title: 'Добро пожаловать!',
          subtitle: 'Создавайте уроки и помогайте ученицам изучать арабский язык.',
        ),
        const SizedBox(height: 13),
        Row(children: [
          Expanded(child: _teacherMetric('Ученицы', null, Icons.groups_outlined)),
          const SizedBox(width: 8),
          Expanded(child: _teacherMetric('На проверке', null, Icons.fact_check_outlined)),
          const SizedBox(width: 8),
          Expanded(child: _teacherMetric('Группы', null, Icons.people_alt_outlined)),
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
        const SizedBox(height: 21),
        const Text('Управление школой',style:TextStyle(
          fontSize:19,fontWeight:FontWeight.w800,color:green)),
        const SizedBox(height: 9),
        Panel(child:Column(children:[
          _teacherMenuRow('Мои курсы','Редактирование и публикация',
            Icons.menu_book_outlined,()=>setState(()=>selectedTab=1)),
          const Divider(height:12),
          _teacherMenuRow('Ученицы','Список, прогресс и сообщения',
            Icons.groups_outlined,()=>setState(()=>selectedTab=2)),
          const Divider(height:12),
          _teacherMenuRow('Домашние задания','Проверка выполненных работ',
            Icons.assignment_turned_in_outlined,()=>setState(()=>selectedTab=3)),
          const Divider(height:12),
          _teacherMenuRow('Расписание','Онлайн-занятия и встречи',
            Icons.calendar_month_outlined,
            ()=>_notice(context,'Расписание появится после подключения сервера.')),
          const Divider(height:12),
          _teacherMenuRow('Статистика','Активность и результаты',
            Icons.bar_chart_rounded,
            ()=>_notice(context,'Общая статистика появится после подключения сервера.')),
          const Divider(height:12),
          _teacherMenuRow('Настройки','Язык, уведомления и оформление',
            Icons.settings_outlined,()=>setState(()=>selectedTab=4)),
        ])),
        const SizedBox(height: 22),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Мои материалы',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: green)),
          Text('$total уроков · $published опубликовано', style: const TextStyle(color: muted, fontSize: 11)),
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
      ],
    );
  }

  Widget _teacherMenuRow(String title, String description,
    IconData icon, VoidCallback onTap) => ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 3,vertical: 0),
      dense: true,
      leading: ArtworkIcon(
        icon == Icons.menu_book_outlined ? 'books'
        : icon == Icons.groups_outlined ? 'students'
        : icon == Icons.assignment_turned_in_outlined ? 'homework'
        : icon == Icons.calendar_month_outlined ? 'schedule'
        : icon == Icons.bar_chart_rounded ? 'analytics' : 'settings',
        size: 48),
      title: Text(title,style: const TextStyle(
        color: green,fontWeight: FontWeight.w800,fontSize: 13)),
      subtitle: Text(description,style: const TextStyle(fontSize: 11,color: muted)),
      trailing: const Icon(Icons.chevron_right_rounded,color: muted,size: 20),
      onTap: onTap,
    );

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

  Widget _teacherMetric(String name, int? count, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: const Color(0xFFEAE0D4)),
    ),
    child: Column(children: [
      ArtworkIcon(
        icon == Icons.groups_outlined ? 'students'
          : icon == Icons.fact_check_outlined ? 'tests' : 'analytics',
        size: 43),

      const SizedBox(height: 5),
      Text(count == null ? '—' : '$count', style: const TextStyle(
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
  const LessonScreen({super.key, required this.state, required this.lesson,
    this.initialTab = 0});
  final AcademyState state;
  final Map<String, dynamic> lesson;
  final int initialTab;
  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  int? selected;
  bool checked = false;
  late int activeTab;

  @override
  void initState() {
    super.initState();
    activeTab = widget.initialTab.clamp(0, 3);
  }

  Widget _heading(String name) => Padding(
    padding: const EdgeInsets.only(bottom: 11),
    child: Text(name,style:const TextStyle(fontSize:19,
      color:green,fontWeight:FontWeight.w800)),
  );

  @override
  Widget build(BuildContext context) {
    final data = widget.lesson;
    final answers = data['options'] as List;
    const names = ['Урок','Слова','Грамматика','Задания'];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: refGreen,foregroundColor:Colors.white,
        title: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(data['title'] as String,
            maxLines:1,overflow:TextOverflow.ellipsis,
            style:const TextStyle(fontSize:16,fontWeight:FontWeight.w800)),
          const Text('Базовый уровень 1',style:TextStyle(fontSize:11)),
        ]),
      ),
      body: Column(children:[
        Container(
          color:const Color(0xFFFFFAF2),
          padding:const EdgeInsets.fromLTRB(11,9,11,10),
          child: Row(children: List.generate(names.length, (i) =>
            Expanded(child: Padding(
              padding:const EdgeInsets.symmetric(horizontal:2),
              child: InkWell(
                borderRadius:BorderRadius.circular(10),
                onTap:()=>setState(()=>activeTab=i),
                child: Container(
                  padding:const EdgeInsets.symmetric(vertical:10),
                  decoration:BoxDecoration(
                    color: activeTab==i ? const Color(0xFFE6EEE6) : Colors.transparent,
                    borderRadius:BorderRadius.circular(10),
                    border:Border(bottom:BorderSide(
                      width:activeTab==i ? 2.5 : 0,
                      color:activeTab==i ? const Color(0xFFC79B57) : Colors.transparent)),
                  ),
                  alignment:Alignment.center,
                  child:Text(names[i],maxLines:1,
                    style:TextStyle(fontSize:12,fontWeight:activeTab==i
                      ? FontWeight.w800 : FontWeight.w500,color:green)),
                ),
              ),
            )),
          )),
        ),
        Expanded(child: ListView(
          padding:const EdgeInsets.fromLTRB(16,16,16,26),
          children: [
            if (activeTab==0) ...[
              Container(
                height:190,clipBehavior:Clip.antiAlias,
                decoration:BoxDecoration(
                  borderRadius:BorderRadius.circular(20),
                  color:const Color(0xFFEAE5D8)),
                child:Stack(fit:StackFit.expand,children:[
                  Image.asset('assets/images/feature_classroom.webp',fit:BoxFit.cover),
                  const DecoratedBox(decoration:BoxDecoration(
                    gradient:LinearGradient(
                      begin:Alignment.topCenter,end:Alignment.bottomCenter,
                      colors:[Colors.transparent,Color(0xB3093A30)]))),
                  const Align(alignment:Alignment.bottomCenter,
                    child:Padding(padding:EdgeInsets.all(13),
                      child:Text('Видеоурок пока не загружен',
                        style:TextStyle(color:Colors.white,fontWeight:FontWeight.w700)))),
                ]),
              ),
              const SizedBox(height:19),
              NaskhText(data['title_ar'] as String,size:30),
              Text(data['goal'] as String,style:const TextStyle(color:muted)),
              const SizedBox(height:17),
              _heading('Диалог'),
              ...((data['dialogue'] as List).map((raw) {
                final line = raw as Map<String,dynamic>;
                return Padding(padding:const EdgeInsets.only(bottom:9),
                  child:Panel(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,
                    children:[
                      NaskhText(line['ar'] as String,size:25),
                      const SizedBox(height:5),
                      Text(line['ru'] as String,
                        style:const TextStyle(fontSize:13,color:muted)),
                    ])));
              })),
              const SizedBox(height:15),
              Row(children:[
                Expanded(child:OutlinedButton.icon(
                  onPressed:()=>Navigator.pop(context),
                  icon:const Icon(Icons.arrow_back,size:18),
                  label:const Text('Назад'))),
                const SizedBox(width:12),
                Expanded(child:FilledButton.icon(
                  onPressed:()=>setState(()=>activeTab=1),
                  icon:const Icon(Icons.arrow_forward,size:18),
                  label:const Text('Далее'))),
              ]),
            ] else if (activeTab==1) ...[
              _heading('Новые слова'),
              const Text('Арабский текст с огласовками — шрифт насх.',
                style:TextStyle(color:muted,fontSize:12)),
              const SizedBox(height:13),
              ...((data['vocabulary'] as List).map((raw) {
                final word=raw as Map<String,dynamic>;
                return Padding(padding:const EdgeInsets.only(bottom:9),
                  child:Panel(child:Row(children:[
                    Expanded(child:Text(word['ru'] as String,
                      style:const TextStyle(fontSize:14))),
                    Expanded(child:NaskhText(word['ar'] as String,size:27)),
                  ])));
              })),
              FilledButton(onPressed:()=>setState(()=>activeTab=2),
                child:const Text('Перейти к грамматике')),
            ] else if (activeTab==2) ...[
              _heading('Объяснение грамматики'),
              Panel(child:Text(data['grammar'] as String,
                style:const TextStyle(fontSize:15,height:1.65))),
              const SizedBox(height:20),
              FilledButton(onPressed:()=>setState(()=>activeTab=3),
                child:const Text('Перейти к заданиям')),
            ] else ...[
              _heading('Упражнение 1'),
              const Text('Выберите правильный ответ',
                style:TextStyle(fontSize:13,color:muted)),
              const SizedBox(height:14),
              Panel(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,
                children:[
                  Text(data['question'] as String,
                    style:const TextStyle(fontWeight:FontWeight.w800,fontSize:16)),
                  const SizedBox(height:15),
                  RadioGroup<int>(
                    groupValue:selected,
                    onChanged:(v)=>setState((){selected=v;checked=false;}),
                    child:Column(children:[
                      ...answers.asMap().entries.map((x)=>RadioListTile<int>(
                        value:x.key,
                        title:Text(x.value.toString()),
                        contentPadding:EdgeInsets.zero,
                      )),
                    ]),
                  ),
                  if (checked) Container(
                    margin:const EdgeInsets.only(bottom:12),
                    padding:const EdgeInsets.all(13),
                    decoration:BoxDecoration(
                      color:selected==data['correct']
                        ? const Color(0xFFE3F4E8) : const Color(0xFFFFEDE6),
                      borderRadius:BorderRadius.circular(13)),
                    child:Row(children:[
                      Icon(selected==data['correct']
                        ? Icons.check_circle : Icons.info_outline,
                        color:selected==data['correct']
                          ? const Color(0xFF138553) : const Color(0xFF9B5D3E)),
                      const SizedBox(width:8),
                      Expanded(child:Text(selected==data['correct']
                        ? 'Правильно!':'Попробуйте другой ответ.',
                        style:const TextStyle(fontWeight:FontWeight.w700))),
                    ]),
                  ),
                  FilledButton(
                    onPressed:selected==null ? null : ()=>setState(()=>checked=true),
                    child:const Text('Проверить ответ')),
                ])),
              const SizedBox(height:15),
              _heading('Домашнее задание'),
              Panel(child:Text(data['homework'] as String)),
              const SizedBox(height:15),
              Panel(child:Column(children:[
                Row(children:[
                  const ArtworkIcon('microphone',size:66),
                  const SizedBox(width:10),
                  Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
                    children:[
                      const Text('Устная практика',style:TextStyle(
                        fontWeight:FontWeight.w800,fontSize:16)),
                      const Text('Запись голоса пока не подключена',
                        style:TextStyle(color:muted,fontSize:12)),
                    ])),
                ]),
                const SizedBox(height:8),
                OutlinedButton.icon(onPressed:null,
                  icon:const Icon(Icons.mic_none),
                  label:const Text('Записать ответ')),
              ])),
              const SizedBox(height:15),
              FilledButton.icon(
                onPressed:checked && selected==data['correct'] ? () async {
                  await widget.state.finish(data['id'] as String);
                  if (context.mounted) {
                    _notice(context,'Урок отмечен как изученный на этом телефоне.');
                  }
                } : null,
                icon:const Icon(Icons.check_circle_outline),
                label:const Text('Завершить урок')),
            ],
            const SizedBox(height:15),
            const Text('Учебные тексты требуют редакторской проверки перед публикацией.',
              style:TextStyle(color:muted,fontSize:11)),
          ],
        )),
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
      const Row(children: [
        ArtworkIcon('homework', size: 64),
        SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Конструктор уроков',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: green)),
            Text('Текст, задание и видеоматериал',
              style: TextStyle(fontSize: 12, color: muted)),
          ],
        )),
      ]),
      const SizedBox(height: 12),
      const Panel(child: Text('Демо: уроки сохраняются только на этом устройстве. Для загрузки видео с телефона и публикации другим ученицам требуется сервер.')),
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
