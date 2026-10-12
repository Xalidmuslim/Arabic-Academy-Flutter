import '../services/backend_service.dart';
import 'academy_state.dart';

/// Synchronizes only the authenticated account's free, original self-study
/// workspace. Local results are explicitly unverified study events; school
/// tests are still graded by submit_attempt/complete_lesson on the server.
class LearningSync {
  LearningSync(this.backend);
  final BackendService backend;
  Future<int>? _running;

  Future<int> synchronize(AcademyState state) =>
      _running ??= _run(state).whenComplete(() => _running = null);
  Future<int> _run(AcademyState state) async {
    final owner = backend.userId;
    void requireOwner() {
      if (owner == null ||
          owner != backend.userId ||
          state.namespace != 'academy_account_$owner') {
        throw const IntegrationException(
          'Синхронизация доступна только для текущего личного аккаунта. Демо-данные остаются на устройстве.',
        );
      }
    }

    requireOwner();
    var uploaded = 0;
    for (final event in state.pendingEvents.take(100)) {
      requireOwner();
      final row = await backend.client
          .rpc(
            'record_event',
            params: {
              'p_idempotency_key': event['id'],
              'p_kind': event['event_type'] == 'draft_saved'
                  ? 'draft_saved'
                  : 'study_reviewed',
              'p_payload': {
                'origin': 'local_author_learning',
                'account_id': owner,
                'workspace_version': 1,
                'local_type': event['event_type'],
                'local_payload': event['payload'],
                'occurred_at': event['occurred_at'],
              },
            },
          )
          .timeout(const Duration(seconds: 15));
      requireOwner();
      if (row is! Map ||
          row['user_id'] != owner ||
          row['idempotency_key'] != event['id']) {
        throw const IntegrationException(
          'Сервер не подтвердил владельца и сохранение события.',
        );
      }
      await state.acknowledgeEvents([event['id'] as String]);
      uploaded++;
    }
    for (var page = 0; page < 5; page++) {
      requireOwner();
      final offset = state.syncOffset;
      final rows = await backend.client
          .from('events')
          .select('user_id,idempotency_key,payload,received_at')
          .eq('user_id', owner!)
          .eq('payload->>origin', 'local_author_learning')
          .order('received_at')
          .order('id')
          .range(offset, offset + 199)
          .timeout(const Duration(seconds: 15));
      requireOwner();
      await state.mergeLearningEvents(rows);
      await state.advanceSyncOffset(offset + rows.length);
      if (rows.length < 200) break;
    }
    return uploaded;
  }
}
