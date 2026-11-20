import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models/radio_station.dart';

class StorageService {
  static const _legacyKey = 'favorite_stations';
  static const _favoritesKey = 'favorite_stations_v2';

  Future<List<RadioStation>> loadFavoriteStations() async {
    final prefs = await SharedPreferences.getInstance();
    return (await _read(prefs)).values.whereType<RadioStation>().toList();
  }

  Future<List<RadioStation>> resolveFavorites(
      Iterable<RadioStation> candidates) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = await _read(prefs);
    var changed = false;
    for (final station in candidates) {
      final id = station.stationuuid;
      if (favorites.containsKey(id) && favorites[id] == null) {
        favorites[id] = station;
        changed = true;
      }
    }
    if (changed) await _write(prefs, favorites);
    return favorites.values.whereType<RadioStation>().toList();
  }

  Future<void> saveFavoriteStations(List<RadioStation> stations) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = await _read(prefs);
    await _write(prefs, {
      for (final entry in stored.entries)
        if (entry.value == null) entry.key: null,
      for (final station in stations) station.stationuuid: station,
    });
  }

  Future<Map<String, RadioStation?>> _read(SharedPreferences prefs) async {
    final current = prefs.getStringList(_favoritesKey);
    final legacy = current == null ? prefs.get(_legacyKey) : null;
    final decoded = legacy is String ? _decode(legacy) : null;
    final entries = current ?? (legacy is List<String> ? legacy : []);
    final favorites = <String, RadioStation?>{
      if (decoded is List)
        for (final id in decoded.whereType<String>())
          if (id.isNotEmpty) id: null,
    };
    for (final entry in entries) {
      final value = _decode(entry);
      if (value is String && value.isNotEmpty) {
        favorites.putIfAbsent(value, () => null);
      } else if (value is Map<String, dynamic>) {
        try {
          final station = RadioStation.fromJson(value);
          if (station.stationuuid.isNotEmpty) {
            favorites[station.stationuuid] = station;
          }
        } on TypeError {
          // Other entries are still recoverable.
        }
      }
    }
    if (legacy != null) await _write(prefs, favorites, verify: true);
    return favorites;
  }

  Object? _decode(String value) {
    try {
      return jsonDecode(value);
    } on FormatException {
      return null;
    }
  }

  Future<void> _write(
    SharedPreferences prefs,
    Map<String, RadioStation?> favorites, {
    bool verify = false,
  }) async {
    final entries = [
      for (final entry in favorites.entries)
        jsonEncode(entry.value?.toJson() ?? entry.key),
    ];
    try {
      if (!await prefs.setStringList(_favoritesKey, entries)) {
        throw StateError('Could not save favorites');
      }
      if (verify) {
        await prefs.reload();
        final saved = prefs.getStringList(_favoritesKey);
        if (saved == null ||
            saved.length != entries.length ||
            !Iterable<int>.generate(entries.length)
                .every((i) => saved[i] == entries[i])) {
          throw StateError('Could not verify migrated favorites');
        }
      }
    } catch (_) {
      await prefs.reload();
      rethrow;
    }
  }
}
