import 'dart:io';

import 'package:auxia_mobile/core/maps/map_region.dart';
import 'package:auxia_mobile/core/maps/offline_first_tile_provider.dart';
import 'package:auxia_mobile/core/maps/offline_tile_store.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory folder;
  late OfflineFirstTileProvider provider;
  final layer = TileLayer(urlTemplate: 'https://tiles.test/{z}/{x}/{y}.png');

  setUp(() {
    folder = Directory.systemTemp.createTempSync('tiles');
    provider = OfflineFirstTileProvider(
      OfflineTileStore(directory: folder, urlTemplate: layer.urlTemplate!),
    );
  });

  tearDown(() {
    provider.dispose();
    folder.deleteSync(recursive: true);
  });

  test('uses the cancelable variant that flutter_map 8 asks for', () {
    expect(provider.supportsCancelLoading, isTrue);
  });

  test('a downloaded tile is read from the device', () {
    final store = OfflineTileStore(
      directory: folder,
      urlTemplate: layer.urlTemplate!,
    );
    store.fileOf(const TileId(14, 1, 2))
      ..createSync(recursive: true)
      ..writeAsBytesSync([1]);

    final image = provider.getImageWithCancelLoadingSupport(
      const TileCoordinates(1, 2, 14),
      layer,
      Future<void>.value(),
    );

    expect(image, isA<FileImage>());
  });

  test('a missing tile is asked to the network without failing', () {
    final image = provider.getImageWithCancelLoadingSupport(
      const TileCoordinates(1, 2, 14),
      layer,
      Future<void>.value(),
    );

    expect(image, isNot(isA<FileImage>()));
  });
}
