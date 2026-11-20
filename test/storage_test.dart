import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:radio_app/data/models/radio_station.dart';
import 'package:radio_app/data/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final station = RadioStation(
    stationuuid: 'station-id',
    name: 'Radio',
    url: 'https://example.test/radio',
  );

  test(
    'migrates legacy IDs and preserves unresolved IDs across edits',
    () async {
      SharedPreferences.setMockInitialValues({
        'favorite_stations': '["station-id","3"]',
      });
      final storage = StorageService();
      expect(await storage.loadFavoriteStations(), isEmpty);
      expect(
        (await storage.resolveFavorites([station])).single.stationuuid,
        'station-id',
      );
      await storage.toggleFavorite(station);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.get('favorite_stations'), '["station-id","3"]');
      expect(prefs.getStringList('favorite_stations_v2'), [jsonEncode('3')]);
      expect(await StorageService().loadFavoriteStations(), isEmpty);
    },
  );

  test('keeps valid favorite cards beside a corrupt legacy entry', () async {
    final valid = jsonEncode(station.toJson());
    SharedPreferences.setMockInitialValues({
      'favorite_stations': [valid, '{'],
    });
    final storage = StorageService();
    expect(
      (await storage.loadFavoriteStations()).single.stationuuid,
      'station-id',
    );
    expect(
      (await StorageService().loadFavoriteStations()).single.stationuuid,
      'station-id',
    );
  });
}
