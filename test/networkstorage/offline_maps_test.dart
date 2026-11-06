import 'dart:io';
import 'dart:typed_data';

import 'package:auxia_mobile/core/maps/map_region.dart';
import 'package:auxia_mobile/core/maps/offline_tile_store.dart';
import 'package:auxia_mobile/networkstorage/application/offline_maps_service.dart';
import 'package:auxia_mobile/shared/domain/geo_point.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers every tile with 100 bytes and counts the requests.
class _TileAdapter implements HttpClientAdapter {
  final List<String> urls = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    urls.add(options.uri.toString());
    return ResponseBody.fromBytes(List.filled(100, 7), 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Directory folder;
  late _TileAdapter adapter;
  late OfflineTileStore store;
  final lima = MapRegion.around(
    id: 'lima',
    name: 'Mi ubicación',
    center: const GeoPoint(-12.0464, -77.0428),
  );

  setUp(() {
    folder = Directory.systemTemp.createTempSync('auxia_tiles_');
    adapter = _TileAdapter();
    store = OfflineTileStore(
      directory: folder,
      urlTemplate: 'https://{s}.tiles.test/{z}/{x}/{y}{r}.png',
      dio: Dio(BaseOptions(responseType: ResponseType.bytes))
        ..httpClientAdapter = adapter,
    );
  });

  tearDown(() => folder.deleteSync(recursive: true));

  test('a region of about 3 km needs few tiles from zoom 12 to 16', () {
    final tiles = lima.tiles();

    expect(tiles.map((t) => t.z).toSet(), {12, 13, 14, 15, 16});
    expect(tiles.length, inInclusiveRange(10, 80));
    expect(tiles, contains(const TileId(12, 1171, 2186)));
  });

  test('builds the tile url without retina suffix', () {
    expect(
      store.urlOf(const TileId(12, 1171, 2186)),
      'https://b.tiles.test/12/1171/2186.png',
    );
  });

  test('downloads the region once and serves it from disk', () async {
    var last = (0, 0);

    await store.download(
      lima,
      onProgress: (done, total) => last = (done, total),
      shouldStop: () => false,
    );

    final total = lima.tiles().length;
    expect(last, (total, total));
    expect(store.storedCount(lima), total);
    expect(store.storedBytes(lima), total * 100);
    expect(store.totalBytes(), total * 100);

    await store.download(lima, onProgress: (_, _) {}, shouldStop: () => false);
    expect(adapter.urls, hasLength(total), reason: 'nothing downloaded twice');
  });

  test('a paused download keeps what it saved and resumes', () async {
    var calls = 0;

    await store.download(
      lima,
      onProgress: (_, _) => calls++,
      shouldStop: () => calls > 5,
    );

    final saved = store.storedCount(lima);
    expect(saved, inExclusiveRange(0, lima.tiles().length));

    await store.download(lima, onProgress: (_, _) {}, shouldStop: () => false);
    expect(store.storedCount(lima), lima.tiles().length);
  });

  test('deleting keeps the tiles another region still uses', () async {
    final neighbour = MapRegion.around(
      id: 'near',
      name: 'Sector',
      center: const GeoPoint(-12.05, -77.04),
    );
    await store.download(lima, onProgress: (_, _) {}, shouldStop: () => false);
    await store.download(
      neighbour,
      onProgress: (_, _) {},
      shouldStop: () => false,
    );

    await store.delete(lima, keep: [neighbour]);

    expect(store.storedCount(neighbour), neighbour.tiles().length);
    expect(store.storedCount(lima), lessThan(lima.tiles().length));
  });

  group('OfflineMapsService', () {
    test('refuses a region that does not fit the budget', () async {
      final maps = OfflineMapsService(store, budgetBytes: 1024);

      expect(await maps.download(lima), DownloadOutcome.noSpace);
      expect(adapter.urls, isEmpty);
    });

    test('downloads, reports progress and frees the space', () async {
      final maps = OfflineMapsService(store);
      final states = <RegionState>[];
      final subscription = maps.changes.listen(
        (_) => states.add(maps.stateOf(lima)),
      );

      expect(maps.stateOf(lima).started, isFalse);
      expect(await maps.download(lima), DownloadOutcome.completed);
      await Future<void>.delayed(Duration.zero);

      expect(states.any((s) => s.downloading), isTrue);
      expect(maps.stateOf(lima).available, isTrue);
      expect(maps.stateOf(lima).percent, 100);
      expect(maps.usedBytes(), greaterThan(0));

      await maps.delete(lima, [lima]);
      expect(maps.stateOf(lima).started, isFalse);
      await subscription.cancel();
    });
  });
}
