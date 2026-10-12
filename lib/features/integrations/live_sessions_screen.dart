import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import '../../services/backend_service.dart';
import '../../services/media_upload_service.dart' show integrationErrorText;
import 'integration_widgets.dart';

class LiveSessionsScreen extends StatefulWidget {
  const LiveSessionsScreen({super.key, required this.backend});
  final BackendService backend;
  @override
  State<LiveSessionsScreen> createState() => _LiveSessionsScreenState();
}

class _LiveSessionsScreenState extends State<LiveSessionsScreen>
    with IntegrationActions<LiveSessionsScreen> {
  Future<List<Map<String, dynamic>>>? _sessions;
  Future<ServerRole>? _role;

  @override
  void initState() {
    super.initState();
    widget.backend.addListener(_authChanged);
    _reload();
  }

  void _reload() {
    _sessions = widget.backend.liveSessions();
    _role = widget.backend.loadRole();
  }

  void _authChanged() {
    if (mounted) setState(_reload);
  }

  Future<void> _create() async {
    await widget.backend.requireTeacher();
    final groups = await widget.backend.groups();
    if (groups.isEmpty) {
      throw const IntegrationException(
        'Нет доступных групп. Назначьте группу на сервере.',
      );
    }
    if (!mounted) return;
    final title = TextEditingController();
    String groupId = groups.first['id'] as String;
    DateTime? startsAt;
    int minutes = 60;
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Запланировать занятие'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  onChanged: (_) => update(() {}),
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: 'Название'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: groupId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Группа'),
                  items: groups
                      .map(
                        (group) => DropdownMenuItem(
                          value: group['id'] as String,
                          child: Text(
                            group['title'].toString(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) update(() => groupId = value);
                  },
                ),
                OutlinedButton(
                  onPressed: () async {
                    final now = DateTime.now();
                    final day = await showDatePicker(
                      context: dialogContext,
                      initialDate: now.add(const Duration(days: 1)),
                      firstDate: now,
                      lastDate: now.add(const Duration(days: 365)),
                    );
                    if (day == null || !dialogContext.mounted) return;
                    final time = await showTimePicker(
                      context: dialogContext,
                      initialTime: const TimeOfDay(hour: 18, minute: 0),
                    );
                    if (time != null && dialogContext.mounted) {
                      update(
                        () => startsAt = DateTime(
                          day.year,
                          day.month,
                          day.day,
                          time.hour,
                          time.minute,
                        ),
                      );
                    }
                  },
                  child: Text(
                    startsAt == null
                        ? 'Выбрать дату и время'
                        : _date(startsAt!),
                  ),
                ),
                DropdownButtonFormField<int>(
                  initialValue: minutes,
                  decoration: const InputDecoration(labelText: 'Длительность'),
                  items: [30, 60, 90, 120]
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text('$value минут'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) update(() => minutes = value);
                  },
                ),
                const Text('Время устройства. Запись занятия выключена.'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: startsAt == null || title.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, {
                      'title': title.text,
                      'group_id': groupId,
                      'starts_at': startsAt,
                      'minutes': minutes,
                    }),
              child: const Text('Создать'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    if (draft == null) return;
    final start = draft['starts_at'] as DateTime;
    await widget.backend.createLiveSession(
      title: draft['title'] as String,
      groupId: draft['group_id'] as String,
      startsAt: start,
      endsAt: start.add(Duration(minutes: draft['minutes'] as int)),
    );
    if (mounted) setState(_reload);
  }

  Future<void> _join(Map<String, dynamic> session) async {
    bool consent = false;
    if (session['recording_enabled'] == true) {
      consent =
          await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Занятие будет записываться'),
              content: const Text(
                'Для участия нужно разрешить серверную запись вашего голоса и видео. '
                'Запись может быть доступна участникам по правилам курса.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Не входить'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Разрешить и войти'),
                ),
              ],
            ),
          ) ??
          false;
      if (!consent) return;
    }
    final result = await widget.backend.liveRoomToken(
      session['id'] as String,
      recordingConsent: consent,
    );
    final url = result['url'];
    final token = result['token'];
    final uri = url is String ? Uri.tryParse(url) : null;
    if (url is! String ||
        token is! String ||
        token.isEmpty ||
        uri == null ||
        !const {'https', 'wss'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const IntegrationException(
        'Сервер не выдал безопасный токен комнаты.',
      );
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _LiveRoomScreen(
          url: url,
          token: token,
          title: session['title'].toString(),
          canPublish: result['can_publish'] == true,
        ),
      ),
    );
  }

  String _date(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.'
        '${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    widget.backend.removeListener(_authChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Живые занятия')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const IntegrationNotice(
          'Здесь только доступные вашему аккаунту занятия. '
          'Для входа сервер проверяет группу, доступ к курсу и время занятия. '
          'Микрофон и камера при входе выключены.',
        ),
        actionStatus,
        OutlinedButton(
          onPressed: working ? null : () => setState(_reload),
          child: const Text('Обновить расписание'),
        ),
        FutureBuilder<ServerRole>(
          future: _role,
          builder: (context, snapshot) {
            final teacher =
                snapshot.data == ServerRole.teacher ||
                snapshot.data == ServerRole.admin;
            return teacher
                ? FilledButton(
                    onPressed: working ? null : () => runAction(_create),
                    child: const Text('Запланировать занятие'),
                  )
                : const SizedBox.shrink();
          },
        ),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _sessions,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return IntegrationNotice(integrationErrorText(snapshot.error!));
            }
            if (!snapshot.hasData) return const LinearProgressIndicator();
            if (snapshot.data!.isEmpty) {
              return const IntegrationNotice(
                'Запланированных доступных занятий пока нет.',
              );
            }
            return Column(
              children: snapshot.data!.map((session) {
                final start = DateTime.tryParse(
                  session['starts_at'].toString(),
                );
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session['title'].toString(),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (start != null) Text(_date(start)),
                        if (session['recording_enabled'] == true)
                          const Text(
                            'Занятие с записью — потребуется согласие',
                          ),
                        FilledButton(
                          onPressed: working
                              ? null
                              : () => runAction(() => _join(session)),
                          child: const Text('Войти'),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    ),
  );
}

class _LiveRoomScreen extends StatefulWidget {
  const _LiveRoomScreen({
    required this.url,
    required this.token,
    required this.title,
    required this.canPublish,
  });
  final String url;
  final String token;
  final String title;
  final bool canPublish;
  @override
  State<_LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _LiveRoomScreenState extends State<_LiveRoomScreen>
    with WidgetsBindingObserver, IntegrationActions<_LiveRoomScreen> {
  final _room = lk.Room();
  late final lk.EventsListener<lk.RoomEvent> _events;
  final _chat = TextEditingController();
  final List<String> _messages = [];
  final Set<String> _hands = {};
  bool _raised = false;
  bool _joining = false;
  bool _foreground = true;
  Future<void>? _connection;
  Future<void> _captureTasks = Future.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _room.addListener(_changed);
    _events = _room.createListener();
    _events.on<lk.DataReceivedEvent>(_receive);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) runAction(_connect);
    });
  }

  void _changed() {
    if (mounted) {
      setState(() {
        _hands.removeWhere((id) => !_room.remoteParticipants.containsKey(id));
      });
    }
  }

  Future<void> _connect() async {
    _joining = true;
    try {
      await (_connection = _room.connect(widget.url, widget.token));
    } finally {
      _joining = false;
    }
  }

  void _receive(lk.DataReceivedEvent event) {
    if (event.topic != 'academy.chat' || event.data.length > 4096 || !mounted) {
      return;
    }
    try {
      final data = jsonDecode(utf8.decode(event.data)) as Map<String, dynamic>;
      final sender = event.participant?.identity ?? 'Сервер';
      if (data['type'] == 'chat' && data['text'] is String) {
        final text = (data['text'] as String).trim();
        if (text.isNotEmpty && text.runes.length <= 500) {
          setState(() => _addMessage('$sender: $text'));
        }
      } else if (data['type'] == 'hand' && data['raised'] is bool) {
        setState(() {
          if (data['raised'] == true) {
            _hands.add(sender);
          } else {
            _hands.remove(sender);
          }
        });
      }
    } catch (_) {
      /* Ignore malformed peer messages; they never alter privileges. */
    }
  }

  void _addMessage(String message) {
    _messages.add(message);
    if (_messages.length > 100) _messages.removeAt(0);
  }

  Future<void> _sendChat() async {
    final text = _chat.text.trim();
    if (text.isEmpty || text.runes.length > 500) {
      throw const IntegrationException(
        'Сообщение должно содержать 1–500 символов.',
      );
    }
    final local = _room.localParticipant;
    if (local == null ||
        _room.connectionState != lk.ConnectionState.connected) {
      throw const IntegrationException('Комната не подключена.');
    }
    await local.publishData(
      utf8.encode(jsonEncode({'type': 'chat', 'text': text})),
      reliable: true,
      topic: 'academy.chat',
    );
    if (mounted) {
      setState(() {
        _addMessage('Вы: $text');
        _chat.clear();
      });
    }
  }

  Future<void> _raiseHand() async {
    final local = _room.localParticipant;
    if (local == null) {
      throw const IntegrationException('Комната не подключена.');
    }
    final next = !_raised;
    await local.publishData(
      utf8.encode(jsonEncode({'type': 'hand', 'raised': next})),
      reliable: true,
      topic: 'academy.chat',
    );
    if (mounted) setState(() => _raised = next);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (state != AppLifecycleState.resumed) {
      // Stop capture when backgrounded. Joining never requests either device.
      unawaited(_queueCapture(_stopCapture).catchError((Object _) {}));
    }
  }

  Future<void> _queueCapture(Future<void> Function() action) {
    final next = _captureTasks.then((_) => action());
    _captureTasks = next.catchError((Object _) {});
    return next;
  }

  Future<void> _toggleCapture({required bool camera}) => _queueCapture(
    () async {
      final local = _room.localParticipant;
      if (local == null || !mounted || !_foreground) return;
      if (camera) {
        await local.setCameraEnabled(!local.isCameraEnabled());
      } else {
        await local.setMicrophoneEnabled(!local.isMicrophoneEnabled());
      }
      // Covers returning from a native permission prompt after background/exit.
      if (!mounted || !_foreground) await _stopCapture();
    },
  );

  Future<void> _stopCapture() async {
    await _room.localParticipant?.setMicrophoneEnabled(false);
    await _room.localParticipant?.setCameraEnabled(false);
  }

  Future<void> _leave() async {
    await _queueCapture(_stopCapture);
    await _room.disconnect();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _releaseRoom() async {
    await _connection?.catchError((Object _) {});
    await _captureTasks;
    try {
      await _stopCapture();
      await _room.disconnect();
    } finally {
      await _room.dispose();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _room.removeListener(_changed);
    unawaited(_events.dispose());
    unawaited(_releaseRoom().catchError((Object _) {}));
    _chat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connected = _room.connectionState == lk.ConnectionState.connected;
    final local = _room.localParticipant;
    final participants = <lk.Participant>[
      if (local != null) local,
      ..._room.remoteParticipants.values,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          actionStatus,
          Semantics(
            liveRegion: true,
            child: Text(
              connected
                  ? 'Комната подключена'
                  : _joining
                  ? 'Подключаемся…'
                  : 'Соединение отсутствует. Вернитесь в расписание для нового токена.',
            ),
          ),
          for (final participant in participants)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Text(
                      participant.name.isEmpty
                          ? participant.identity
                          : participant.name,
                    ),
                    for (final publication
                        in participant.videoTrackPublications)
                      if (publication.track is lk.VideoTrack &&
                          !publication.muted)
                        SizedBox(
                          height: 200,
                          child: lk.VideoTrackRenderer(
                            publication.track as lk.VideoTrack,
                          ),
                        ),
                    if (participant.isSpeaking) const Text('Говорит'),
                  ],
                ),
              ),
            ),
          if (widget.canPublish)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: !connected || working
                      ? null
                      : () => runAction(() => _toggleCapture(camera: false)),
                  child: Text(
                    local?.isMicrophoneEnabled() == true
                        ? 'Выключить микрофон'
                        : 'Включить микрофон',
                  ),
                ),
                FilledButton.tonal(
                  onPressed: !connected || working
                      ? null
                      : () => runAction(() => _toggleCapture(camera: true)),
                  child: Text(
                    local?.isCameraEnabled() == true
                        ? 'Выключить камеру'
                        : 'Включить камеру',
                  ),
                ),
              ],
            )
          else
            const Text(
              'Сервер разрешил только просмотр. Микрофон и камера недоступны.',
            ),
          OutlinedButton(
            onPressed: !connected || working
                ? null
                : () => runAction(_raiseHand),
            child: Text(_raised ? 'Опустить руку' : 'Поднять руку'),
          ),
          if (_hands.isNotEmpty) Text('Подняли руку: ${_hands.join(', ')}'),
          const Divider(),
          const Text('Чат комнаты (не сохраняется после выхода)'),
          for (final message in _messages)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(message),
            ),
          TextField(
            controller: _chat,
            enabled: connected && !working,
            maxLength: 500,
            decoration: const InputDecoration(labelText: 'Сообщение'),
          ),
          FilledButton(
            onPressed: !connected || working
                ? null
                : () => runAction(_sendChat),
            child: const Text('Отправить'),
          ),
          OutlinedButton(
            onPressed: working ? null : () => runAction(_leave),
            child: const Text('Выйти из комнаты'),
          ),
        ],
      ),
    );
  }
}
