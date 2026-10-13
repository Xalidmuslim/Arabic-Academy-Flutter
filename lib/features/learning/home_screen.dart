import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/academy_state.dart';
import '../../core/app_strings.dart';
import '../../core/study_analytics.dart';
import '../../core/learning_sync.dart';
import '../../services/backend_service.dart';
import '../../ui/components.dart';
import '../../ui/design_tokens.dart';
import '../../ui/neumorphic_components.dart';
import '../../ui/premium_art.dart';
import '../integrations/live_sessions_screen.dart';
import '../integrations/oral_practice_screen.dart';
import '../integrations/phone_auth_screen.dart';
import '../integrations/purchases_screen.dart';
import '../teacher/teacher_dashboard.dart';
import '../teacher/remote_school_screen.dart';
import 'course_screen.dart';
import 'lesson_screen.dart';
import 'library_screens.dart';
import 'progress_screen.dart';
import 'settings_screen.dart';
import 'online_homework_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.state,
    this.backend,
    this.navigationTab,
    this.showEmbeddedNavigation = true,
  });
  final AcademyState state;
  final BackendService? backend;
  final ValueNotifier<int>? navigationTab;
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
  late final LearningSync _sync = LearningSync(_backend);
  Timer? _syncTimer;
  int _tab = 0;
  AcademyState get state => _accountState ?? widget.state;
  @override
  void initState() {
    super.initState();
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
      _role = _accountId == null ? null : _backend.loadRole();
      _demoTeacher = false;
      _tab = 0;
    }
    setState(() {});
  }

  void _onNavigationChanged() {
    if (!mounted) return;
    final next = widget.navigationTab?.value ?? 0;
    if (_tab != next) setState(() => _tab = next);
  }

  void _setTab(int tab) {
    if (_tab != tab) setState(() => _tab = tab);
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
    if (widget.backend == null) _backend.dispose();
    super.dispose();
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
    if (_tab != 0) {
      _setTab(0);
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
    appBar: _tab == 1 || _tab == 2
        ? null
        : AppBar(
            centerTitle: false,
            title: const Text(
              'Байна Ядайк',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            actions: [
              IconButton(
                tooltip: tr(context, 'Уведомления'),
                icon: const Icon(Icons.notifications_none),
                onPressed: () => _open(NotificationsScreen(backend: _backend)),
              ),
              IconButton(
                tooltip: tr(context, 'Настройки'),
                icon: const Icon(Icons.settings_outlined),
                onPressed: () =>
                    _open(SettingsScreen(state: state, backend: _backend)),
              ),
              if (!_backend.isAuthenticated)
                PopupMenuButton<bool>(
                  tooltip: 'Переключить демо-роль',
                  icon: const Icon(Icons.swap_horiz_rounded),
                  onSelected: (teacher) => setState(() {
                    _demoTeacher = teacher;
                    _tab = 0;
                  }),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: false,
                      child: Text(tr(context, 'Демо: ученица')),
                    ),
                    PopupMenuItem(
                      value: true,
                      child: Text(tr(context, 'Демо: учительница')),
                    ),
                  ],
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
                if (_tab == 0 &&
                    [
                      ServerRole.teacher,
                      ServerRole.admin,
                    ].contains(snapshot.data)) {
                  return RemoteSchoolScreen(backend: _backend, embedded: true);
                }
                return _page();
              },
            );
          }
          if (_demoTeacher && _tab == 0) {
            return TeacherDashboard(state: state, backend: _backend);
          }
          return _page();
        },
      ),
    ),
    bottomNavigationBar: !widget.showEmbeddedNavigation
        ? null
        : NavigationBar(
      selectedIndex: _tab,
      onDestinationSelected: _setTab,
      destinations: [
        NavigationDestination(
          icon: const ArtworkIcon('home', size: 29),
          label: tr(context, 'Главная'),
        ),
        NavigationDestination(
          icon: const Icon(Icons.menu_book_outlined),
          label: tr(context, 'Уроки'),
        ),
        NavigationDestination(
          icon: const ArtworkIcon('search', size: 29),
          label: tr(context, 'Поиск'),
        ),
        NavigationDestination(
          icon: const ArtworkIcon('profile', size: 29),
          label: tr(context, 'Профиль'),
        ),
      ],
    ),
    ),
  );

  Widget _page() => switch (_tab) {
    1 => UnitScreen(state: state, backend: _backend),
    2 => SearchScreen(state: state, onOpenLesson: _lesson),
    3 => _profile(),
    _ => _dashboard(),
  };

  Widget _dashboard() {
    final lessons = state.allLessons;
    final analytics = StudyAnalytics(state);
    final next = lessons.isEmpty
        ? null
        : lessons.firstWhere(
            (x) => x['id'] == state.lastLessonId,
            orElse: () => lessons.firstWhere(
              (x) => !state.completed.contains(x['id']),
              orElse: () => lessons.last,
            ),
          );
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final columns = MediaQuery.sizeOf(context).width < 340 || scale > 1.6
        ? 1
        : 2;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(context, 'Арабский каждый день'),
                  style: const TextStyle(fontSize: 12, color: muted),
                ),
                const SizedBox(height: 5),
                Text(
                  tr(context, 'Арабский язык в твоих руках'),
                  style: const TextStyle(fontSize: 13, color: green),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Stack(
                    children: [
                      Image.asset(
                        PremiumArt.hero,
                        height: scale > 1.6 ? 180 : 126,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        alignment: Alignment.centerRight,
                        cacheWidth: 900,
                        excludeFromSemantics: true,
                      ),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            color: Color(0x42FFF4E6),
                          ),
                        ),
                      ),
                      PositionedDirectional(
                        top: 15,
                        start: 16,
                        bottom: 12,
                        end: 90,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'العربية بين يديك',
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                fontFamily: 'NotoNaskhArabic',
                                fontSize: scale > 1.6 ? 18 : 25,
                                height: 1.55,
                                color: green,
                              ),
                            ),
                            if (scale <= 1.6)
                              Text(
                                tr(context, 'Локальное обучение'),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: muted,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          sliver: SliverGrid.count(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: columns == 1 ? 1.55 : 0.96,
            children: [
              NeumorphicFeatureTile(
                title: tr(context, 'Уроки'),
                subtitle: 'Диалоги и учебные тексты',
                image: 'assets/artwork/lessons.webp',
                onTap: () => _open(UnitScreen(state: state, backend: _backend)),
              ),
              NeumorphicFeatureTile(
                title: tr(context, 'Грамматика'),
                subtitle: 'Правила и практика',
                image: 'assets/artwork/grammar.webp',
                onTap: () => _open(GrammarScreen(state: state)),
              ),
              NeumorphicFeatureTile(
                title: tr(context, 'Словарь'),
                subtitle: 'Слова и повторение',
                image: 'assets/artwork/vocabulary.webp',
                onTap: () => _open(DictionaryScreen(state: state)),
              ),
              NeumorphicFeatureTile(
                title: tr(context, 'Мой прогресс'),
                subtitle: 'Результаты обучения',
                image: 'assets/artwork/progress.webp',
                onTap: () => _open(LearnerProgressScreen(state: state)),
              ),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(18),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NeumorphicCourseHero(
                  progress: analytics.progress,
                  completed: analytics.completedLessons,
                  total: analytics.totalLessons,
                  onContinue: () {
                    if (next != null) _lesson(context, next);
                  },
                ),
                SectionTitle(tr(context, 'Моё обучение')),
                if (lessons.isEmpty)
                  const EmptyState(
                    title: 'Уроки ещё не добавлены',
                    message:
                        'Создайте и опубликуйте материал в локальном кабинете учительницы.',
                  ),
                ...lessons
                    .take(2)
                    .map(
                      (lesson) => Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: Panel(
                          padding: EdgeInsets.zero,
                          child: ListTile(
                            title: Text(lesson['title'] as String? ?? ''),
                            subtitle: Text(
                              state.completed.contains(lesson['id'])
                                  ? 'Завершён'
                                  : 'Продолжить изучение',
                            ),
                            leading: const Icon(
                              Icons.auto_stories_outlined,
                              color: DesignTokens.olive,
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _lesson(context, lesson),
                          ),
                        ),
                      ),
                    ),
                const SizedBox(height: 8),
                Panel(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading: const ArtworkIcon('schedule', size: 43),
                    title: Text(tr(context, 'Расписание')),
                    subtitle: const Text('Онлайн-уроки вашей школы'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _open(LiveSessionsScreen(backend: _backend)),
                  ),
                ),
                const SizedBox(height: 12),
                Panel(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading: const ArtworkIcon('microphone', size: 45),
                    title: Text(tr(context, 'Устная практика')),
                    subtitle: const Text('Запись и прослушивание ответа'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _open(OralPracticeScreen(backend: _backend)),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Overlay navigation paints above the scroll viewport; last actions
        // must remain fully visible when scrolled to the end.
        const SliverToBoxAdapter(child: SizedBox(height: 112)),
      ],
    );
  }

  Widget _profile() => ListView(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 128),
    children: [
      Panel(
        child: Row(
          children: [
            const ArtworkIcon('profile', size: 60),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _backend.isAuthenticated
                        ? 'Личный аккаунт'
                        : 'Ученица · локальное обучение',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Text(
                    'العربية بين يديك',
                    style: TextStyle(
                      fontFamily: 'NotoNaskhArabic',
                      fontSize: 22,
                      height: 1.8,
                      color: green,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      for (final row in <(String, IconData, Widget)>[
        ('Аккаунт', Icons.person_outline, PhoneAuthScreen(backend: _backend)),
        (
          'Настройки',
          Icons.settings_outlined,
          SettingsScreen(state: state, backend: _backend),
        ),
        (
          'Закладки',
          Icons.bookmark_outline,
          BookmarksScreen(state: state, onOpenLesson: _lesson),
        ),
        (
          'Домашние задания',
          Icons.assignment_outlined,
          _backend.isAuthenticated
              ? OnlineHomeworkScreen(backend: _backend, state: state)
              : LocalHomeworkScreen(state: state),
        ),
        (
          'Офлайн-материалы',
          Icons.download_outlined,
          UnitScreen(state: state, backend: _backend),
        ),
        (
          'Покупки и подписки',
          Icons.workspace_premium_outlined,
          PurchasesScreen(backend: _backend),
        ),
        (
          'Прямые эфиры',
          Icons.videocam_outlined,
          LiveSessionsScreen(backend: _backend),
        ),
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Panel(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(row.$2, color: DesignTokens.olive),
              title: Text(tr(context, row.$1)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(row.$3),
            ),
          ),
        ),
      const SizedBox(height: 8),
      const Text(
        'Бесплатные тексты, словарь, грамматика и черновики доступны без сети. Онлайн-уроки и личные данные школы требуют входа.',
        style: TextStyle(fontSize: 12, color: muted),
      ),
    ],
  );
}
