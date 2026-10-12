import 'dart:convert';
import '../../../core/academy_state.dart';
import '../../../services/backend_service.dart';

/// A durable, account-scoped outbox. A sent payload/key is immutable until the
/// server acknowledges it or the user explicitly resolves a revision conflict.
class OnlineHomeworkDraft {
  OnlineHomeworkDraft({
    required this.owner,
    required this.assignmentId,
    required int revision,
    Map<String, dynamic>? saved,
  }) : _preserved = saved == null
           ? {}
           : Map<String, dynamic>.from(jsonDecode(jsonEncode(saved)) as Map) {
    if (saved != null &&
        (saved['account_id'] != owner ||
            saved['assignment_id'] != assignmentId ||
            saved['version'] != 1)) {
      throw const IntegrationException(
        'Черновик относится к другому аккаунту или формату. Исходные данные сохранены.',
      );
    }
    expectedRevision = saved?['expected_revision'] as int? ?? revision;
    requestId = saved?['idempotency_key'] as String? ?? AcademyState.newId();
    if (expectedRevision < 0) {
      throw const IntegrationException(
        'Некорректная ревизия сохранённого черновика. Исходные данные сохранены.',
      );
    }
    IntegrationValidation.uuid(requestId);
    textAr = saved?['text_ar'] as String? ?? '';
    text = saved?['text'] as String? ?? '';
    final pending = saved?['pending_body'];
    pendingBody = pending == null
        ? null
        : Map<String, dynamic>.from(pending as Map);
  }
  final String owner, assignmentId;
  final Map<String, dynamic> _preserved;
  late int expectedRevision;
  late String requestId, textAr, text;
  Map<String, dynamic>? pendingBody;
  String get storageKey => 'online_assignment:$assignmentId';
  bool get pending => pendingBody != null;
  bool get hasText => textAr.trim().isNotEmpty || text.trim().isNotEmpty;
  void edit({String? arabic, String? russian}) {
    if (pending) {
      throw const IntegrationException(
        'Сначала подтвердите отправку сохранённого ответа.',
      );
    }
    if (arabic != null) textAr = arabic;
    if (russian != null) text = russian;
    requestId = AcademyState.newId();
  }

  Map<String, dynamic> snapshot() => {
    ..._preserved,
    'version': 1,
    'account_id': owner,
    'assignment_id': assignmentId,
    'expected_revision': expectedRevision,
    'idempotency_key': requestId,
    'text_ar': textAr,
    'text': text,
    'pending_body': pendingBody == null
        ? null
        : jsonDecode(jsonEncode(pendingBody)),
  };
  Future<void> persist(AcademyState state) {
    if (state.namespace != 'academy_account_$owner') {
      throw const IntegrationException(
        'Черновик нельзя сохранить в чужом аккаунте или демо.',
      );
    }
    return state.saveDraft(storageKey, snapshot());
  }

  void queue() {
    if (pending) return;
    if (!hasText) {
      throw const IntegrationException(
        'Добавьте ответ на арабском или русском.',
      );
    }
    final body = {'text_ar': textAr, 'text': text};
    if (utf8.encode(jsonEncode(body)).length > 64000) {
      throw const IntegrationException(
        'Ответ слишком большой (не более 64 КБ).',
      );
    }
    pendingBody = body;
  }

  Map<String, dynamic> submitParams() {
    if (!pending) {
      throw const IntegrationException(
        'Черновик ещё не сохранён для отправки.',
      );
    }
    return {
      'p_assignment_id': assignmentId,
      'p_expected_revision': expectedRevision,
      'p_idempotency_key': requestId,
      'p_body': jsonDecode(jsonEncode(pendingBody)),
    };
  }

  void accept(Map response) {
    if (response['assignment_id'] != assignmentId ||
        response['student_id'] != owner ||
        response['revision'] is! int ||
        (response['revision'] as int) <= expectedRevision) {
      throw const IntegrationException(
        'Сервер не подтвердил новую ревизию ответа. Повторите отправку сохранённого ответа.',
      );
    }
    expectedRevision = response['revision'] as int;
    pendingBody = null;
    requestId = AcademyState.newId();
  }

  bool reconcile(Map<String, dynamic> details) {
    if (!pending) return false;
    final history = details['history'] as List;
    final match = history
        .where((h) => h['idempotency_key'] == requestId)
        .firstOrNull;
    if (match == null) return false;
    // PostgreSQL JSONB disregards object key order; use the two text fields.
    final body = match['body'];
    if (body is! Map ||
        body.length != pendingBody!.length ||
        body['text_ar'] != pendingBody!['text_ar'] ||
        body['text'] != pendingBody!['text']) {
      throw const IntegrationException(
        'Серверный ключ связан с другим ответом. Сохранённый черновик не изменён.',
      );
    }
    final submission = details['submission'];
    if (submission is! Map) {
      throw const IntegrationException(
        'Не удалось подтвердить состояние работы.',
      );
    }
    accept(submission);
    return true;
  }

  void useRevision(int revision) {
    expectedRevision = revision;
    pendingBody = null;
    requestId = AcademyState.newId();
  }
}
