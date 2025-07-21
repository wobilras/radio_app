import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../data/models/radio_station.dart';
import '../data/repositories/radio_repository.dart';

enum TabType { stations, favorites, search }

class RadioProvider extends ChangeNotifier {
  final RadioRepository _repository = RadioRepositoryImpl();

  List<RadioStation> _stations = [];
  List<RadioStation> _favoriteStations = [];
  List<RadioStation> _searchResults = [];
  bool _isLoading = false;
  String? _currentPlayingId;
  String? _error;
  TabType _currentTab = TabType.stations;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription? _currentStationSubscription;

  List<RadioStation> get stations => _stations;
  List<RadioStation> get favoriteStations => _favoriteStations;
  List<RadioStation> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  String? get currentPlayingId => _currentPlayingId;
  String? get error => _error;
  TabType get currentTab => _currentTab;
  String get searchQuery => _searchQuery;
  TextEditingController get searchController => _searchController;

  List<RadioStation> get filteredStations {
    switch (_currentTab) {
      case TabType.stations:
        if (_searchQuery.isNotEmpty) {
          return _stations.where((station) {
            return station.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                station.country.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                station.tags.toLowerCase().contains(_searchQuery.toLowerCase());
          }).toList();
        }
        return _stations;

      case TabType.favorites:
        if (_searchQuery.isNotEmpty) {
          return _favoriteStations.where((station) {
            return station.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                station.country.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                station.tags.toLowerCase().contains(_searchQuery.toLowerCase());
          }).toList();
        }
        return _favoriteStations;

      case TabType.search:
        return _searchResults;
    }
  }

  RadioProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    if (_repository is RadioRepositoryImpl) {
      await (_repository as RadioRepositoryImpl).initialize();
    }

    _currentStationSubscription = _repository.currentStationStream.listen((stationId) {
      if (_currentPlayingId != stationId) {
        _currentPlayingId = stationId;
        notifyListeners();
      }
    });
    await _loadFavoriteStations();
    await loadStations();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (_searchQuery != query) {
      _searchQuery = query;

      if (_currentTab == TabType.search && query.isNotEmpty) {
        _performSearch(query);
      } else {
        notifyListeners();
      }
    }
  }

  void setCurrentTab(TabType tab) {
    if (_currentTab != tab) {
      _currentTab = tab;

      if (tab == TabType.search && _searchQuery.isNotEmpty) {
        _performSearch(_searchQuery);
      }

      notifyListeners();
    }
  }

  void clearSearch() {
    _searchController.clear();
    _searchQuery = '';
    _searchResults.clear();
    notifyListeners();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      _searchResults.clear();
      notifyListeners();
      return;
    }

    try {
      _setLoading(true);
      _searchResults = await _repository.searchStations(query);
      _setError(null);
    } catch (e) {
      _setError('Ошибка поиска: $e');
      _searchResults.clear();
    } finally {
      _setLoading(false);
    }
  }

  bool isFavorite(String stationId) {
    return _favoriteStations.any((station) => station.stationuuid == stationId);
  }

  Future<void> toggleFavorite(String stationId) async {
    try {
      if (isFavorite(stationId)) {
        _favoriteStations.removeWhere((s) => s.stationuuid == stationId);
      } else {
        RadioStation? station = _stations.firstWhere(
              (s) => s.stationuuid == stationId,
          orElse: () => _searchResults.firstWhere(
                (s) => s.stationuuid == stationId,
            orElse: () => throw Exception('Station not found'),
          ),
        );

        _favoriteStations.add(station);
      }

      await _saveFavoriteStations();
      notifyListeners();
    } catch (e) {
      print('Ошибка при изменении избранного: $e');
    }
  }

  Future<void> loadStations() async {
    try {
      _setLoading(true);
      _setError(null);
      _stations = await _repository.getRadioStations();
      print('Загружено ${_stations.length} станций');
    } catch (e) {
      _setError('Ошибка загрузки станций: $e');
      print('Ошибка загрузки станций: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> playStation(String stationId) async {
    try {
      if (_currentPlayingId == stationId) {
        await _repository.stopStation();
        return;
      }

      RadioStation? station;
      try {
        station = _stations.firstWhere((s) => s.stationuuid == stationId);
      } catch (e) {
        try {
          station = _favoriteStations.firstWhere((s) => s.stationuuid == stationId);
        } catch (e) {
          station = _searchResults.firstWhere((s) => s.stationuuid == stationId);
        }
      }

      if (station != null) {
        await _repository.playStation(station);
        _setError(null);
      } else {
        throw Exception('Станция не найдена');
      }
    } catch (e) {
      _setError('Ошибка воспроизведения: $e');
      print('Ошибка воспроизведения станции: $e');
    }
  }

  Future<void> stopCurrentStation() async {
    try {
      await _repository.stopStation();
      _setError(null);
    } catch (e) {
      _setError('Ошибка остановки: $e');
      print('Ошибка остановки воспроизведения: $e');
    }
  }

  Future<void> _loadFavoriteStations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesJson = prefs.getStringList('favorite_stations') ?? [];

      _favoriteStations = favoritesJson.map((jsonString) {
        final json = jsonDecode(jsonString);
        return RadioStation.fromJson(json);
      }).toList();

      print('Загружено ${_favoriteStations.length} избранных станций');
    } catch (e) {
      print('Ошибка загрузки избранных станций: $e');
      _favoriteStations = [];
    }
  }

  Future<void> _saveFavoriteStations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesJson = _favoriteStations.map((station) {
        return jsonEncode({
          'stationuuid': station.stationuuid,
          'name': station.name,
          'url': station.url,
          'favicon': station.favicon,
          'country': station.country,
          'countrycode': station.countrycode,
          'language': station.language,
          'tags': station.tags,
          'votes': station.votes,
          'clickcount': station.clickcount,
          'codec': station.codec,
          'bitrate': station.bitrate,
        });
      }).toList();

      await prefs.setStringList('favorite_stations', favoritesJson);
      print('Избранные станции сохранены: ${_favoriteStations.length}');
    } catch (e) {
      print('Ошибка сохранения избранных станций: $e');
    }
  }

  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void _setError(String? error) {
    if (_error != error) {
      _error = error;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _currentStationSubscription?.cancel();
    _searchController.dispose();
    if (_repository is RadioRepositoryImpl) {
      (_repository as RadioRepositoryImpl).dispose();
    }
    super.dispose();
  }
}