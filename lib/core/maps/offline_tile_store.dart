import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import 'map_region.dart';

/// Downloads map tiles of a region to the private folder of the app and
/// serves them without signal.
class OfflineTileStore {
  OfflineTileStore({
    required this.directory,
    required this.urlTemplate,
    Dio? dio,
    this.averageTileBytes = 25 * 1024,
  }) : _dio = dio ?? Dio(BaseOptions(responseType: ResponseType.bytes));

  /// Root folder of the tiles (`<documents>/tiles`).
  final Directory directory;
  final String urlTemplate;
  final Dio _dio;

  /// Estimate used before a region is downloaded.
  final int averageTileBytes;

  static const List<String> _subdomains = ['a', 'b', 'c', 'd'];

  File fileOf(TileId tile) =>
      File(p.join(directory.path, '${tile.z}', '${tile.x}', '${tile.y}.png'));

  bool has(TileId tile) => fileOf(tile).existsSync();

  /// Tiles of the region already on the device.
  int storedCount(MapRegion region) => region.tiles().where(has).length;

  /// Bytes of the region already on the device.
  int storedBytes(MapRegion region) {
    var total = 0;
    for (final tile in region.tiles()) {
      final file = fileOf(tile);
      if (file.existsSync()) total += file.lengthSync();
    }
    return total;
  }

  /// Bytes of every downloaded tile.
  int totalBytes() {
    if (!directory.existsSync()) return 0;
    var total = 0;
    for (final entity in directory.listSync(recursive: true)) {
      if (entity is File) total += entity.lengthSync();
    }
    return total;
  }

  int estimatedBytes(MapRegion region) =>
      region.tiles().length * averageTileBytes;

  /// Downloads the missing tiles. [shouldStop] lets the user pause; the
  /// tiles already saved are kept, so the next download resumes.
  Future<void> download(
    MapRegion region, {
    required void Function(int done, int total) onProgress,
    required bool Function() shouldStop,
  }) async {
    final tiles = region.tiles();
    var done = tiles.where(has).length;
    onProgress(done, tiles.length);
    for (final tile in tiles) {
      if (shouldStop()) return;
      if (has(tile)) continue;
      final response = await _dio.get<List<int>>(urlOf(tile));
      final file = fileOf(tile);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(response.data!, flush: true);
      done++;
      onProgress(done, tiles.length);
    }
  }

  /// Removes the tiles of the region that no other kept region needs.
  Future<void> delete(
    MapRegion region, {
    List<MapRegion> keep = const [],
  }) async {
    final needed = {for (final other in keep) ...other.tiles()};
    for (final tile in region.tiles()) {
      if (needed.contains(tile)) continue;
      final file = fileOf(tile);
      if (file.existsSync()) await file.delete();
    }
  }

  String urlOf(TileId tile) => urlTemplate
      .replaceAll('{s}', _subdomains[(tile.x + tile.y) % _subdomains.length])
      .replaceAll('{z}', '${tile.z}')
      .replaceAll('{x}', '${tile.x}')
      .replaceAll('{y}', '${tile.y}')
      .replaceAll('{r}', '');
}
