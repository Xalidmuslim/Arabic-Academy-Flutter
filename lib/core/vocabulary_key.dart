/// Existing index keys stay valid; editor-assigned IDs survive reordering.
String vocabularyKey(String lessonId, int index, Map<dynamic, dynamic> word) {
  final id = word['id'];
  return 'word:$lessonId:${id is String && id.isNotEmpty ? id : index}';
}
