import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models/radio_station.dart';

class StorageService {
  static const _favoritesKey = 'favorite_stations';

  Future<List<RadioStation>> loadFavoriteStations() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_favoritesKey) ?? [])
        .map((value) => RadioStation.fromJson(jsonDecode(value)))
        .toList();
  }

  Future<void> saveFavoriteStations(List<RadioStation> stations) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = stations.map((station) => jsonEncode(station.toJson()));
    await prefs.setStringList(_favoritesKey, entries.toList());
  }
}
