import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class Storage {
  static const String _favoritesKey = 'favorite_stations';

  static Future<void> saveFavoriteStations(List<String> favoriteIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_favoritesKey, json.encode(favoriteIds));
  }

  static Future<List<String>> loadFavoriteStations() async {
    final prefs = await SharedPreferences.getInstance();
    final String? favoritesJson = prefs.getString(_favoritesKey);

    if (favoritesJson == null) {
      return [];
    }

    try {
      final List<dynamic> favoritesList = json.decode(favoritesJson);
      return favoritesList.cast<String>();
    } catch (e) {
      print('Ошибка при загрузке избранного: $e');
      return [];
    }
  }

  static Future<void> clearFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_favoritesKey);
  }
}