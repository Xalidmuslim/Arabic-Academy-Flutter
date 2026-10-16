import 'dart:async';
import 'dart:typed_data';

import 'package:arabic_academy/services/bounded_pdf_page_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('concurrent requests for the same PDF page share one native render',
      () async {
    final completer = Completer<Uint8List>();
    var renders = 0;
    final cache = BoundedPdfPageCache(render: (page) {
      renders++;
      return completer.future;
    });
    final first = cache.page(12);
    final second = cache.page(12);
    expect(identical(first, second), isTrue);
    expect(renders, 1);
    completer.complete(Uint8List.fromList([1, 2]));
    expect(await second, [1, 2]);
    expect(cache.entryCount, 1);
  });

  test('cache retains at most three nearby pages when turning', () async {
    var renders = 0;
    final cache = BoundedPdfPageCache(render: (page) async {
      renders++;
      return Uint8List(200);
    });
    for (final page in [11, 12, 13]) {
      await cache.page(page);
    }
    expect(cache.entryCount, 3);
    await cache.page(12); // A repeated PDF visit must be a hit.
    expect(renders, 3);
    cache.keepNear(13);
    expect(cache.entryCount, 2);
    await cache.page(14);
    expect(cache.entryCount, 3);
    await cache.page(11);
    expect(renders, 5, reason: 'discarded pages can be re-rendered');
    expect(cache.entryCount, 3);
  });

  test('byte ceiling evicts old pages but never destroys visible page',
      () async {
    final cache = BoundedPdfPageCache(
      render: (page) async => Uint8List(700),
      maximumBytes: 1000,
      maximumPages: 3,
    );
    await cache.page(1);
    await cache.page(2);
    // Completion handlers resolve on microtasks after await, if needed.
    await Future<void>.delayed(Duration.zero);
    expect(cache.entryCount, 1);
    expect(cache.retainedBytes, 700);
  });

  test('clearing book ignores stale results and keeps new book data',
      () async {
    final old = Completer<Uint8List>();
    var count = 0;
    final cache = BoundedPdfPageCache(render: (page) {
      count++;
      if (count == 1) return old.future;
      return Future.value(Uint8List.fromList([9]));
    });
    final legacy = cache.page(5);
    cache.clear();
    final current = cache.page(5);
    old.complete(Uint8List.fromList([1, 2, 3]));
    expect(await legacy, [1, 2, 3]);
    expect(await current, [9]);
    await Future<void>.delayed(Duration.zero);
    expect(cache.entryCount, 1);
    expect(cache.retainedBytes, 1);
  });

  test('failed native page render is evicted and can be retried', () async {
    var calls = 0;
    final cache = BoundedPdfPageCache(render: (page) async {
      calls++;
      if (calls == 1) throw StateError('renderer closed');
      return Uint8List.fromList([2, 3]);
    });
    await expectLater(cache.page(7), throwsStateError);
    await Future<void>.delayed(Duration.zero);
    expect(await cache.page(7), [2, 3]);
    expect(calls, 2);
  });
}
