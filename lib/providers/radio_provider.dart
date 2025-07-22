import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../data/models/radio_station.dart';
import '../data/repositories/radio_repository.dart';

enum TabType { stations, favorites }

class RadioProvider extends ChangeNotifier {
  final RadioRepository _repository = RadioRepositoryImpl();

  List<RadioStation> _stations = [];
  List<RadioStation> _favoriteStations = [];
  List<RadioStation> _searchResults = [];
  bool _isLoading = false;
  bool _isSearching = false;
  String? _currentPlayingId;
  String? _error;
  TabType _currentTab = TabType.stations;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription? _currentStationSubscription;
  Timer? _searchDebounceTimer;

  List<RadioStation> get stations => _stations;
  List<RadioStation> get favoriteStations => _favoriteStations;
  List<RadioStation> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;
  String? get currentPlayingId => _currentPlayingId;
  String? get error => _error;
  TabType get currentTab => _currentTab;
  String get searchQuery => _searchQuery;
  TextEditingController get searchController => _searchController;

  List<RadioStation> get filteredStations {
    if (_searchQuery.isNotEmpty && _searchResults.isNotEmpty) {
      return _searchResults;
    }
    if (_searchQuery.isNotEmpty && _searchResults.isEmpty && !_isSearching) {
      return [];
    }
    switch (_currentTab) {
      case TabType.stations:
        return _stations;
      case TabType.favorites:
        return _favoriteStations;
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

    _searchDebounceTimer?.cancel();

    if (_searchQuery != query) {
      _searchQuery = query;

      if (query.isEmpty) {
        _searchResults.clear();
        _setSearching(false);
        notifyListeners();
      } else {
        _searchDebounceTimer = Timer(Duration(milliseconds: 500), () {
          _performSearch(query);
        });
        _setSearching(true);
      }
    }
  }

  void setCurrentTab(TabType tab) {
    if (_currentTab != tab) {
      _currentTab = tab;
      notifyListeners();
    }
  }

  void clearSearch() {
    _searchDebounceTimer?.cancel();
    _searchController.clear();
    _searchQuery = '';
    _searchResults.clear();
    _setSearching(false);
    notifyListeners();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      _searchResults.clear();
      _setSearching(false);
      return;
    }

    try {
      print('Выполняется поиск: $query');
      _setSearching(true);

      final results = await _repository.searchStations(query);
      if (_searchQuery == query) {
        _searchResults = results;
        _setError(null);
        print('Найдено ${results.length} станций по запросу: $query');
      }
    } catch (e) {
      if (_searchQuery == query) {
        _setError('Ошибка поиска: $e');
        _searchResults.clear();
        print('Ошибка поиска: $e');
      }
    } finally {
      if (_searchQuery == query) {
        _setSearching(false);
      }
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
        RadioStation? station;
        if (_searchQuery.isNotEmpty && _searchResults.isNotEmpty) {
          try {
            station = _searchResults.firstWhere((s) => s.stationuuid == stationId);
          } catch (e) {
            // Станция не найдена в результатах поиска
          }
        }

        if (station == null) {
          try {
            station = _stations.firstWhere((s) => s.stationuuid == stationId);
          } catch (e) {
            // Станция не найдена в основных станциях
          }
        }

        if (station == null) {
          throw Exception('Станция не найдена');
        }

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

      print(' Начинаем загрузку станций...');
      _stations = await _repository.getRadioStations();

      if (_stations.isEmpty) {
        _setError('Не удалось загрузить станции. Проверьте интернет-соединение.');
        print(' Список станций пуст');
      } else {
        print('Загружено ${_stations.length} станций');
      }
    } catch (e) {
      final errorMessage = 'Ошибка загрузки станций: $e';
      _setError(errorMessage);
      print('$errorMessage');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refreshServers() async {
    try {
      print('Обновление серверов...');
      if (_repository is RadioRepositoryImpl) {
        final repo = _repository as RadioRepositoryImpl;
        await repo.refreshServers();
        print('Серверы обновлены');
      }
    } catch (e) {
      print('Ошибка обновления серверов: $e');
    }
  }

  Future<void> playStation(String stationId) async {
    try {
      if (_currentPlayingId == stationId) {
        await _repository.stopStation();
        return;
      }
      RadioStation? station;
      if (_searchQuery.isNotEmpty && _searchResults.isNotEmpty) {
        try {
          station = _searchResults.firstWhere((s) => s.stationuuid == stationId);
        } catch (e) {
          // Станция не найдена в результатах поиска
        }
      }

      if (station == null) {
        try {
          station = _stations.firstWhere((s) => s.stationuuid == stationId);
        } catch (e) {
          // Станция не найдена в основных станциях
        }
      }

      if (station == null) {
        try {
          station = _favoriteStations.firstWhere((s) => s.stationuuid == stationId);
        } catch (e) {
          // Станция не найдена в избранных
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

  void _setSearching(bool searching) {
    if (_isSearching != searching) {
      _isSearching = searching;
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
    _searchDebounceTimer?.cancel();
    _currentStationSubscription?.cancel();
    _searchController.dispose();
    if (_repository is RadioRepositoryImpl) {
      (_repository as RadioRepositoryImpl).dispose();
    }
    super.dispose();
  }
}