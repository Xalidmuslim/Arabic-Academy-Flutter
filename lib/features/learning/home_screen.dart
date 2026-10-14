import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/academy_state.dart';
import '../../core/app_strings.dart';
import '../../core/study_analytics.dart';
import '../../core/learning_insights.dart';
import '../../core/vocabulary_practice.dart';
import '../../core/learning_sync.dart';
import '../../services/backend_service.dart';
import '../../ui/components.dart';
import '../../ui/design_tokens.dart';
import '../../ui/neumorphic_components.dart';
import '../integrations/live_sessions_screen.dart';
import '../integrations/phone_auth_screen.dart';
import '../integrations/purchases_screen.dart';
import '../teacher/demo_school_store.dart';
import '../teacher/demo_school_screen.dart';
import '../teacher/demo_student_screen.dart';
import '../teacher/remote_school_screen.dart';
import '../teacher/teacher_tools_screen.dart';
import 'course_screen.dart';
import 'lesson_screen.dart';
import 'library_screens.dart';
import 'progress_screen.dart';
import 'settings_screen.dart';
import 'online_homework_screen.dart';
import 'vocabulary_practice_screen.dart';
import 'practice_center_screen.dart';
import 'demo_showcase_screen.dart';
import 'words_hub_screen.dart';
import 'situations_screen.dart';
import 'handwriting_screen.dart';
import 'study_calendar_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.state,
    this.backend,
    this.navigationTab,
    this.teacherNavigationMode,
    this.showEmbeddedNavigation = true,
  });
  final AcademyState state;
  final BackendService? backend;
  final ValueNotifier<int>? navigationTab;
  final ValueNotifier<bool>? teacherNavigationMode;
  final bool showEmbeddedNavigation;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final BackendService _backend = widget.backend ?? BackendService();
  AcademyState? _accountState;
  String? _accountId;
  Future<ServerRole>? _role;
  bool _demoTeacher = false;
  bool _serverTeacher = false;
  bool get _teacherLayout => _backend.isAuthenticated
      ? _serverTeacher : _demoTeacher;
  void _syncTeacherNavigation() {
    final notifier = widget.teacherNavigationMode;
    if (notifier != null && notifier.value != _teacherLayout) {
      notifier.value = _teacherLayout;
    }
  }

  late final DemoSchoolStore _demoSchool;
  late final LearningSync _sync = LearningSync(_backend);
  Timer? _syncTimer;
  int _tab = 0;
  final List<int> _tabHistory = [];
  AcademyState get state => _accountState ?? widget.state;
  @override
  void initState() {
    super.initState();
    _demoSchool = DemoSchoolStore(widget.state.prefs);
    _demoTeacher = widget.state.prefs.getBool('demo_role_teacher') == true;
    _tab = widget.navigationTab?.value ?? 0;
    widget.navigationTab?.addListener(_onNavigationChanged);
    _backend.addListener(_authChanged);
    _authChanged();
  }

  Future<void> _synchronize(AcademyState account) async {
    try {
      await _sync.synchronize(account);
    } catch (_) {
      // Keep the outbox intact. Settings provides an explicit retry and errors.
    }
  }

  Future<void> _initializeAccount(AcademyState account) async {
    try {
      await account.initialize();
      if (mounted && identical(account, _accountState)) {
        setState(() {});
        await _synchronize(account);
      }
    } catch (_) {
      if (mounted) {
        notice(
          context,
          'Не удалось открыть личное хранилище. Сохранённые данные не удалены.',
        );
      }
    }
  }

  void _authChanged() {
    if (!mounted) return;
    if (_accountId != _backend.userId) {
      _syncTimer?.cancel();
      _accountId = _backend.userId;
      _accountState?.dispose();
      _accountState = _accountId == null
          ? null
          : AcademyState(
              widget.state.prefs,
              widget.state.catalog,
              namespace: 'academy_account_$_accountId',
              preferencesSource: widget.state,
            );
      if (_accountState != null) {
        unawaited(_initializeAccount(_accountState!));
        _syncTimer = Timer.periodic(const Duration(minutes: 1), (_) {
          if (_accountState != null) unawaited(_synchronize(_accountState!));
        });
      }
      _serverTeacher = false;
      _role = _accountId == null ? null : _backend.loadRole();
      _demoTeacher = false;
      _syncTeacherNavigation();
      final account = _accountId;
      _role?.then((role) {
        if (!mounted || account != _accountId) return;
        final teacher = role == ServerRole.teacher || role == ServerRole.admin;
        if (_serverTeacher != teacher) {
          setState(() => _serverTeacher = teacher);
        }
        _syncTeacherNavigation();
      }, onError: (Object error, StackTrace stack) {
        // The FutureBuilder exposes the server role error in the main view.
      });
      _tab = 0;
      _tabHistory.clear();
    }
    setState(() {});
  }

  void _onNavigationChanged() {
    if (!mounted) return;
    final next = widget.navigationTab?.value ?? 0;
    _setTab(next);
  }

  void _setTab(int tab, {bool remember = true}) {
    if (tab < 0 || tab > 3 || tab == _tab) return;
    if (remember) _tabHistory.add(_tab);
    setState(() => _tab = tab);
    if (widget.navigationTab != null && widget.navigationTab!.value != tab) {
      widget.navigationTab!.value = tab;
    }
  }

  @override
  void dispose() {
    widget.navigationTab?.removeListener(_onNavigationChanged);
    _syncTimer?.cancel();
    _backend.removeListener(_authChanged);
    _accountState?.dispose();
    _demoSchool.dispose();
    if (widget.backend == null) _backend.dispose();
    super.dispose();
  }

  Future<bool> _pickDemoRole() async {
    final selected = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: DesignTokens.cardSurface,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Выберите кабинет', style: Theme.of(sheet).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text(
                'Демонстрация на одном телефоне. Данные школы не отправляются на сервер.',
                style: TextStyle(fontSize: 12, color: DesignTokens.secondary),
              ),
              const SizedBox(height: 16),
              for (final option in [
                (false, 'Ученица', 'Уроки, задания и проверенные ответы', Icons.menu_book_outlined),
                (true, 'Учительница', 'Группы, ученицы, проверки и эфиры', Icons.school_outlined),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Panel(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      minVerticalPadding: 16,
                      leading: Icon(option.$4, size: 30, color: DesignTokens.deepOlive),
                      title: Text(option.$2,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(option.$3),
                      trailing: _demoTeacher == option.$1
                          ? const Icon(Icons.check_circle, color: DesignTokens.deepOlive)
                          : const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pop(sheet, option.$1),
                    ),
                  ),
                ),
            ],
          ),
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return false;
    if (selected == _demoTeacher) return false;
    if (!await widget.state.prefs.setBool('demo_role_teacher', selected)) {
      if (mounted) notice(context, 'Не удалось сохранить режим демонстрации.');
      return false;
    }
    if (!mounted) return false;
    setState(() {
      _demoTeacher = selected;
      _tabHistory.clear();
      _tab = 0;
    });
    widget.navigationTab?.value = 0;
    _syncTeacherNavigation();
    return true;
  }

  void _open(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  void _lesson(BuildContext context, Map<String, dynamic> lesson) =>
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              LessonScreen(state: state, lesson: lesson, backend: _backend),
        ),
      );

  // A root-tab back gesture goes to Home, not out of the Android process.
  // On Home, ask for explicit confirmation instead of exiting unexpectedly.
  void _handleRootBack(bool didPop, Object? result) {
    if (didPop || !mounted) return;
    if (_tabHistory.isNotEmpty) {
      _setTab(_tabHistory.removeLast(), remember: false);
      return;
    }
    if (_tab != 0) {
      _setTab(0, remember: false);
      return;
    }
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Выйти из приложения?'),
        content: const Text('Прогресс останется сохранённым.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              SystemNavigator.pop();
            },
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: _handleRootBack,
    child: Scaffold(
    appBar: !_teacherLayout && (_tab == 1 || _tab == 2)
        ? null
        : AppBar(
            centerTitle: false,
            title: Text(
              _teacherLayout ? 'Учительница · Байна Ядайк' : 'Байна Ядайк',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            actions: [
              IconButton(
                tooltip: tr(context, 'Уведомления'),
                icon: const Icon(Icons.notifications_none),
                onPressed: () => _open(_teacherLayout
                    ? _backend.isAuthenticated
                        ? TeacherToolsScreen(
                            state: state, school: _demoSchool,
                            backend: _backend, online: true)
                        : Scaffold(
                            appBar: AppBar(title: const Text('Уведомления ученицам')),
                            body: DemoSchoolScreen(
                              school: _demoSchool, learning: state,
                              backend: _backend, initialSection: 'notices',
                              compactEmbedded: true,
                            ),
                          )
                    : _backend.isAuthenticated
                        ? NotificationsScreen(backend: _backend)
                        : DemoStudentSchoolScreen(
                            school: _demoSchool, learning: state,
                            initialTab: 'notices')),
              ),
              IconButton(
                tooltip: tr(context, 'Настройки'),
                icon: const Icon(Icons.settings_outlined),
                onPressed: () =>
                    _open(SettingsScreen(state: state, backend: _backend,
                      onDemoRoleChanged: _pickDemoRole)),
              ),

            ],
          ),
    body: ArtworkBackdrop(
      child: AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          if (_backend.isAuthenticated && _role != null) {
            return FutureBuilder(
              future: _role,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return ListView(
                    padding: const EdgeInsets.all(18),
                    children: [
                      EmptyState(
                        title: 'Не удалось проверить полномочия',
                        message:
                            'Проверьте сеть и повторите вход. Права назначает сервер.',
                        action: OutlinedButton(
                          onPressed: () =>
                              setState(() => _role = _backend.loadRole()),
                          child: const Text('Повторить'),
                        ),
                      ),
                    ],
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if ([ServerRole.teacher, ServerRole.admin]
                    .contains(snapshot.data)) {
                  return _onlineTeacherPage();
                }
                return _page();
              },
            );
          }
          if (_demoTeacher) return _demoTeacherPage();
          return _page();
        },
      ),
    ),
    bottomNavigationBar: !widget.showEmbeddedNavigation
        ? null
        : NavigationBar(
      selectedIndex: _tab,
      onDestinationSelected: _setTab,
      destinations: _teacherLayout
          ? const [
              NavigationDestination(icon: Icon(Icons.dashboard_outlined),
                label: 'Обзор'),
              NavigationDestination(icon: Icon(Icons.groups_2_outlined),
                label: 'Группы'),
              NavigationDestination(icon: Icon(Icons.fact_check_outlined),
                label: 'Работы'),
              NavigationDestination(icon: Icon(Icons.grid_view_rounded),
                label: 'Меню'),
            ]
          : [
              NavigationDestination(
                icon: const ArtworkIcon('home', size: 29),
                label: tr(context, 'Сегодня'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.menu_book_outlined),
                label: tr(context, 'Учебник'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.psychology_outlined),
                label: tr(context, 'Практика'),
              ),
              NavigationDestination(
                icon: const ArtworkIcon('profile', size: 29),
                label: tr(context, 'Моё'),
              ),
            ],
    ),
    ),
  );

  Widget _demoTeacherPage() => switch (_tab) {
    1 => DemoSchoolScreen(
      key: const ValueKey('teacher-groups-tab'),
      school: _demoSchool, learning: state, backend: _backend,
      initialSection: 'groups', compactEmbedded: true,
    ),
    2 => DemoSchoolScreen(
      key: const ValueKey('teacher-works-tab'),
      school: _demoSchool, learning: state, backend: _backend,
      initialSection: 'submissions', compactEmbedded: true,
    ),
    3 => TeacherToolsScreen(
      state: state, school: _demoSchool, backend: _backend,
      onDemoRoleChanged: _pickDemoRole,
    ),
    _ => DemoSchoolScreen(
      key: const ValueKey('teacher-overview-tab'),
      school: _demoSchool, learning: state, backend: _backend,
      compactOverview: true,
    ),
  };

  Widget _onlineTeacherPage() => switch (_tab) {
    1 => RemoteSchoolScreen(
      backend: _backend, embedded: true,
      initialArea: 'groups', compactEmbedded: true,
    ),
    2 => RemoteSchoolScreen(
      backend: _backend, embedded: true,
      initialArea: 'reports', compactEmbedded: true,
    ),
    3 => TeacherToolsScreen(
      state: state, school: _demoSchool,
      backend: _backend, online: true,
    ),
    _ => RemoteSchoolScreen(
      backend: _backend, embedded: true,
      initialArea: 'catalog', compactEmbedded: false,
    ),
  };

  Widget _page() => switch (_tab) {
    1 => UnitScreen(state: state, backend: _backend),
    2 => PracticeCenterScreen(state: state),
    3 => _profile(),
    _ => _dashboard(),
  };

  Widget _dashboard() {
    final lessons = state.allLessons;
    final analytics = StudyAnalytics(state);
    final today = LearningInsights.dailyPlan(state);
    final words = VocabularyPractice.plan(state,
      newLimit: today.newWordLimit);
    final next = lessons.isEmpty
        ? null
        : lessons.firstWhere((x) => x['id'] == state.lastLessonId,
            orElse: () => lessons.firstWhere(
              (x) => !state.completed.contains(x['id']),
              orElse: () => lessons.last,
            ));
    final oneColumn = MediaQuery.sizeOf(context).width < 340 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.45;
    return CustomScrollView(slivers: [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(18, 9, 18, 12),
        sliver: SliverToBoxAdapter(child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Арабский каждый день',
                    style: Theme.of(context).textTheme.titleLarge),
                  const Text('МОЁ ОБУЧЕНИЕ',
                    style: TextStyle(color: DesignTokens.secondary,
                      fontSize: 11, letterSpacing: 0.4)),
                ],
              )),
              IconButton(
                key: const ValueKey('home-search'),
                tooltip: 'Поиск по урокам и словам',
                onPressed: () => _open(SearchScreen(
                  state: state, onOpenLesson: _lesson)),
                icon: const Icon(Icons.search_outlined,
                  color: DesignTokens.deepOlive),
              ),
            ]),
            const SizedBox(height: 6),
            NeumorphicCourseHero(
              progress: analytics.progress,
              completed: analytics.completedLessons,
              total: analytics.totalLessons,
              onContinue: () {
                if (next != null) _lesson(context, next);
              },
            ),
            if (next != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Следующий урок: ${next['title'] ?? ''}',
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: DesignTokens.secondary,
                    fontSize: 12)),
              ),
            const SizedBox(height: 15),
            Text('Сегодня', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Panel(
              padding: EdgeInsets.zero,
              child: ListTile(
                key: const ValueKey('daily-vocabulary-entry'),
                leading: const Icon(Icons.style_outlined, size: 32,
                  color: DesignTokens.deepOlive),
                title: Text(words.words.isEmpty
                    ? 'На сегодня всё повторено'
                    : 'Повторить ${words.words.length} слов',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('К повторению: ${words.due} · '
                  'Новых доступно: ${words.newWords}',
                  style: const TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(VocabularyPracticeScreen(state: state)),
              ),
            ),
            const SizedBox(height: 8),
            Panel(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.tips_and_updates_outlined,
                  color: DesignTokens.deepOlive, size: 30),
                title: const Text('Что изучить дальше',
                  style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(today.weakSkill == null
                    ? 'Продолжить урок и закрепить слова'
                    : 'Особое внимание: ${LearningInsights.skillLabels[today.weakSkill] ?? "повторение"}',
                  maxLines: 2),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _setTab(2),
              ),
            ),
          ],
        )),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
        sliver: SliverGrid.count(
          crossAxisCount: oneColumn ? 1 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: oneColumn ? 2.0 : 1.1,
          children: [
            NeumorphicFeatureTile(
              title: 'Слова в образах',
              subtitle: 'Изучаю · Проверяю · Повторяю',
              image: 'assets/artwork/vocabulary.webp',
              onTap: () => _open(WordsHubScreen(state: state)),
            ),
            NeumorphicFeatureTile(
              title: 'Диалоги',
              subtitle: 'Слушаю и отвечаю',
              image: 'assets/artwork/lessons.webp',
              onTap: () => _open(SituationsScreen(state: state)),
            ),
            NeumorphicFeatureTile(
              title: 'Арабское письмо',
              subtitle: 'Буквы, формы и обводка',
              image: 'assets/artwork/grammar.webp',
              onTap: () => _open(HandwritingScreen(state: state)),
            ),
            NeumorphicFeatureTile(
              key: const ValueKey('home-practice-entry'),
              title: 'Проверить себя',
              subtitle: 'Упражнения и мои ошибки',
              image: 'assets/artwork/exercises.webp',
              onTap: () => _setTab(2),
            ),
          ],
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 4),
        sliver: SliverToBoxAdapter(child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionTitle('Мой учебный путь'),
            Panel(child: Row(children: [
              for (final phase in <
                  (String, IconData, VoidCallback)>[
                ('Изучаю', Icons.menu_book_outlined,
                    () => _setTab(1)),
                ('Практикую', Icons.edit_note_outlined,
                    () => _setTab(2)),
                ('Проверяю', Icons.fact_check_outlined,
                    () => _setTab(2)),
                ('Повторяю', Icons.repeat_outlined,
                    () => _open(WordsHubScreen(state: state))),
              ])
                Expanded(child: InkWell(
                  onTap: phase.$3,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(children: [
                      Icon(phase.$2, color: DesignTokens.deepOlive, size: 23),
                      const SizedBox(height: 5),
                      Text(phase.$1, maxLines: 1,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 10)),
                    ]),
                  ),
                )),
            ])),
            const SizedBox(height: 12),
            Panel(padding: EdgeInsets.zero, child: ListTile(
              key: const ValueKey('home-study-calendar'),
              leading: const Icon(Icons.calendar_month_outlined,
                color: DesignTokens.deepOlive),
              title: const Text('Моё расписание'),
              subtitle: const Text('План занятий и напоминания'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(StudyCalendarScreen(state: state)),
            )),
            if (!_backend.isAuthenticated) ...[
              const SizedBox(height: 9),
              Panel(padding: EdgeInsets.zero, child: ListTile(
                leading: const Icon(Icons.assignment_outlined,
                  color: DesignTokens.deepOlive),
                title: const Text('Домашняя работа'),
                subtitle: Text(
                  '${_demoSchool.homeworkFor(_demoSchool.currentStudentId).length} заданий · демо'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(DemoStudentSchoolScreen(
                  school: _demoSchool, learning: state)),
              )),
            ],
          ],
        )),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 155)),
    ]);
  }

  Widget _profile() {
    final learningLinks = <(String, IconData, Widget)>[
      ('Мой прогресс', Icons.insights_outlined,
        LearnerProgressScreen(state: state)),
      ('Слова и повторение', Icons.style_outlined,
        WordsHubScreen(state: state)),
      ('Закладки', Icons.bookmark_outline,
        BookmarksScreen(state: state, onOpenLesson: _lesson)),
      ('Домашние задания', Icons.assignment_outlined,
        _backend.isAuthenticated
          ? OnlineHomeworkScreen(backend: _backend, state: state)
          : DemoStudentSchoolScreen(school: _demoSchool, learning: state)),
      ('Расписание', Icons.calendar_month_outlined,
        StudyCalendarScreen(state: state)),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 150),
      children: [
        Panel(child: Row(children: [
          const ArtworkIcon('profile', size: 52),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_backend.isAuthenticated
                  ? 'Личный аккаунт' : 'Ученица · локальное обучение',
                style: Theme.of(context).textTheme.titleMedium),
              const NaskhText('العربية بين يديك', size: 24),
            ],
          )),
        ])),
        const SectionTitle('Моё обучение'),
        Panel(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (var i = 0; i < learningLinks.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                dense: true,
                leading: Icon(learningLinks[i].$2,
                  color: DesignTokens.deepOlive),
                title: Text(learningLinks[i].$1),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(learningLinks[i].$3),
              ),
            ],
          ]),
        ),
        const SectionTitle('Параметры'),
        Panel(padding: EdgeInsets.zero, child: Column(children: [
          ListTile(
            dense: true,
            leading: const Icon(Icons.settings_outlined,
              color: DesignTokens.deepOlive),
            title: const Text('Настройки'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _open(SettingsScreen(
              state: state, backend: _backend,
              onDemoRoleChanged: _pickDemoRole)),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            dense: true,
            leading: const Icon(Icons.person_outline,
              color: DesignTokens.deepOlive),
            title: const Text('Аккаунт'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _open(PhoneAuthScreen(backend: _backend)),
          ),
        ])),
        const SizedBox(height: 10),
        ExpansionTile(
          title: const Text('Дополнительные возможности'),
          children: [
            ListTile(
              leading: const Icon(Icons.video_camera_front_outlined),
              title: const Text('Учебные встречи'),
              onTap: () => _open(_backend.isAuthenticated
                ? LiveSessionsScreen(backend: _backend)
                : DemoStudentSchoolScreen(
                    school: _demoSchool, learning: state,
                    initialTab: 'sessions')),
            ),
            ListTile(
              leading: const Icon(Icons.workspace_premium_outlined),
              title: Text(_backend.isAuthenticated
                  ? 'Покупки и подписки' : 'Демонстрация всех функций'),
              subtitle: !_backend.isAuthenticated
                  ? const Text('Презентация для заказчика · локальный демо')
                  : null,
              onTap: () => _open(_backend.isAuthenticated
                ? PurchasesScreen(backend: _backend)
                : DemoShowcaseScreen(learning: state,
                    school: _demoSchool, backend: _backend)),
            ),
          ],
        ),
      ],
    );
  }

}
