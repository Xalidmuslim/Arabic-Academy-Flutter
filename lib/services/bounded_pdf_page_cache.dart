import 'dart:typed_data';

/// Bounded LRU for original-resolution PDF PNG pages.
///
/// The PdfRenderer continues to rasterize off the Android main thread.
/// In-flight requests are shared, but stale results from an invalidated book
/// are never retained. A failed render can be retried.
class BoundedPdfPageCache {
  BoundedPdfPageCache({
    required Future<Uint8List> Function(int page) render,
    this.maximumPages = 3,
    this.maximumBytes = 12 * 1024 * 1024,
  }) : assert(maximumPages > 0),
       assert(maximumBytes > 0),
       _render = render;

  final Future<Uint8List> Function(int page) _render;
  final int maximumPages;
  final int maximumBytes;
  final _entries = <int, Future<Uint8List>>{};
  final _resolvedSizes = <int, int>{};
  int _epoch = 0;

  int get entryCount => _entries.length;
  int get retainedBytes =>
      _resolvedSizes.values.fold<int>(0, (total, size) => total + size);

  Future<Uint8List> page(int index) {
    if (index < 0) throw RangeError.value(index, 'index');
    final hit = _entries.remove(index);
    if (hit != null) {
      // Moving to the tail marks this page as most recently requested.
      _entries[index] = hit;
      return hit;
    }
    final epoch = _epoch;
    final request = _render(index);
    _entries[index] = request;
    _trim();
    request.then<void>((bytes) {
      if (epoch != _epoch ||
          !identical(_entries[index], request)) {
        return;
      }
      _resolvedSizes[index] = bytes.lengthInBytes;
      _trim();
    }, onError: (Object error, StackTrace stack) {
      if (epoch == _epoch && identical(_entries[index], request)) {
        _entries.remove(index);
        _resolvedSizes.remove(index);
      }
    });
    return request;
  }

  void keepNear(int page, {int radius = 1}) {
    for (final index in _entries.keys.toList(growable: false)) {
      if ((index - page).abs() > radius) _remove(index);
    }
  }

  void _remove(int index) {
    _entries.remove(index);
    _resolvedSizes.remove(index);
  }

  void _trim() {
    while (_entries.length > maximumPages ||
        (retainedBytes > maximumBytes && _entries.length > 1)) {
      _remove(_entries.keys.first);
    }
  }

  void clear() {
    _epoch++;
    _entries.clear();
    _resolvedSizes.clear();
  }
}
