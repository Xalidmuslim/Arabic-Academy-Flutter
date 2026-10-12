import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/backend_service.dart';
import '../../services/media_upload_service.dart';
import 'integration_widgets.dart';

class MediaUploadScreen extends StatefulWidget {
  const MediaUploadScreen({
    super.key,
    required this.backend,
    required this.lessonId,
  });
  final BackendService backend;
  final String lessonId;
  @override
  State<MediaUploadScreen> createState() => _MediaUploadScreenState();
}

class _MediaUploadScreenState extends State<MediaUploadScreen>
    with IntegrationActions<MediaUploadScreen> {
  late final MediaUploadService _upload;
  @override
  void initState() {
    super.initState();
    _upload = MediaUploadService(widget.backend, widget.lessonId);
  }

  @override
  void dispose() {
    _upload.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Материалы урока')),
    body: ListenableBuilder(
      listenable: _upload,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const IntegrationNotice(
            'Только для назначенного сервером преподавателя. '
            'PDF, MP3, M4A, WAV, MP4, JPG, PNG, WebP; до 50 МБ. '
            'Хранилище приватное, временную ссылку выдаёт сервер после проверки доступа.',
          ),
          actionStatus,
          OutlinedButton(
            onPressed: working ? null : () => runAction(_upload.pick),
            child: const Text('Выбрать файл'),
          ),
          if (_upload.selected != null)
            Text('${_upload.selected!.name} — ${_upload.selected!.size} байт'),
          if (_upload.stage != null)
            Semantics(
              liveRegion: true,
              child: Text(switch (_upload.stage!) {
                UploadStage.selected => 'Файл выбран',
                UploadStage.uploading => 'Передаём файл…',
                UploadStage.uploaded => 'Файл передан',
                UploadStage.authorizing => 'Проверяем доступ к ссылке…',
                UploadStage.complete => 'Ссылка получена',
                UploadStage.failed => 'Загрузка не завершена',
              }),
            ),
          FilledButton(
            onPressed: working || _upload.selected == null
                ? null
                : () => runAction(_upload.upload),
            child: Text(
              _upload.stage == UploadStage.failed ? 'Повторить' : 'Загрузить',
            ),
          ),
          if (_upload.mediaId != null)
            SelectableText('ID материала: ${_upload.mediaId}'),
          if (_upload.signedUrl != null) ...[
            const Text(
              'Ссылка временная. Для сохранения в урок используйте ID материала.',
            ),
            OutlinedButton(
              onPressed: () => runAction(
                () =>
                    Clipboard.setData(ClipboardData(text: _upload.signedUrl!)),
              ),
              child: const Text('Копировать временную ссылку'),
            ),
          ],
        ],
      ),
    ),
  );
}
