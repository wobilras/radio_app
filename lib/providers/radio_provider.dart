import 'dart:async';

import 'package:flutter/material.dart';

import '../data/models/radio_station.dart';
import '../data/repositories/radio_repository.dart';
import '../data/storage.dart';

enum TabType { stations, favorites }

class RadioProvider extends ChangeNotifier {
  final RadioRepository _repository;
  final StorageService _storage;

  List<RadioStation> _stations = [];
  List<RadioStation> _favoriteStations = [];
  Future<void> _favoriteChanges = Future.value();
  List<RadioStation> _searchResults = [];
  bool _disposed = false;
  bool _isLoading = false;
  bool _isSearching = false;
  String? _currentPlayingId;
  String? _pendingPlaybackId;
  int _playbackRequest = 0;
  String? _error;
  TabType _currentTab = TabType.stations;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription? _currentStationSubscription;
  Timer? _searchDebounceTimer;

  List<RadioStation> get stations => List.unmodifiable(_stations);
  List<RadioStation> get favoriteStations =>
      List.unmodifiable(_favoriteStations);
  List<RadioStation> get searchResults => List.unmodifiable(_searchResults);
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;
  String? get currentPlayingId => _currentPlayingId;
  String? get error => _error;
  TabType get currentTab => _currentTab;
  String get searchQuery => _searchQuery;
  TextEditingController get searchController => _searchController;

  List<RadioStation> get filteredStations {
    if (_searchQuery.isNotEmpty && _searchResults.isNotEmpty) {
      return searchResults;
    }
    if (_searchQuery.isNotEmpty && _searchResults.isEmpty && !_isSearching) {
      return [];
    }
    switch (_currentTab) {
      case TabType.stations:
        return stations;
      case TabType.favorites:
        return favoriteStations;
    }
  }

  RadioProvider({
    required RadioRepository repository,
    required StorageService storage,
  }) : _repository = repository,
       _storage = storage {
    _searchController.addListener(_onSearchChanged);
    _currentPlayingId = _repository.currentStationId;
    _currentStationSubscription = _repository.currentStationStream.listen((
      stationId,
    ) {
      if (_disposed || _currentPlayingId == stationId) return;
      _currentPlayingId = stationId;
      _publish();
    });
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      await _repository.initialize();
      if (_disposed) return;
      await _loadFavoriteStations();
      if (_disposed) return;
      await loadStations();
    } catch (_) {
      _setError('Не удалось запустить радио.');
    }
  }

  void _publish() {
    if (!_disposed) notifyListeners();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();

    _searchDebounceTimer?.cancel();

    if (_searchQuery != query) {
      _searchQuery = query;

      if (query.isEmpty) {
        _searchResults.clear();
        _setSearching(false);
        _publish();
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
      _publish();
    }
  }

  void clearSearch() {
    _searchDebounceTimer?.cancel();
    _searchController.clear();
    _searchQuery = '';
    _searchResults.clear();
    _setSearching(false);
    _publish();
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
      if (!_disposed && _searchQuery == query) {
        _searchResults = results;
        _setError(null);
        print('Найдено ${results.length} станций по запросу: $query');
      }
    } catch (e) {
      if (!_disposed && _searchQuery == query) {
        _setError('Ошибка поиска: $e');
        _searchResults.clear();
        print('Ошибка поиска: $e');
      }
    } finally {
      if (!_disposed && _searchQuery == query) {
        _setSearching(false);
      }
    }
  }

  bool isFavorite(String stationId) {
    return _favoriteStations.any((station) => station.stationuuid == stationId);
  }

  Future<void> toggleFavorite(RadioStation station) {
    return _queueFavoriteChange(() async {
      final id = station.stationuuid;
      final updated = [..._favoriteStations];
      if (isFavorite(id)) {
        updated.removeWhere((item) => item.stationuuid == id);
      } else {
        updated.add(station);
      }
      await _storage.saveFavoriteStations(updated);
      _favoriteStations = updated;
    });
  }

  Future<void> _queueFavoriteChange(Future<void> Function() change) {
    return _favoriteChanges = _favoriteChanges.then((_) async {
      if (_disposed) return;
      try {
        await change();
        _publish();
      } catch (_) {
        _setError('Не удалось сохранить избранное.');
      }
    });
  }

  Future<void> loadStations() async {
    try {
      _setLoading(true);
      _setError(null);

      print(' Начинаем загрузку станций...');
      final stations = await _repository.getRadioStations();
      if (_disposed) return;
      _stations = stations;
      if (_stations.isNotEmpty) {
        await _queueFavoriteChange(() async {
          _favoriteStations = await _storage.resolveFavorites(_stations);
        });
      }

      if (_stations.isEmpty) {
        _setError(
          'Не удалось загрузить станции. Проверьте интернет-соединение.',
        );
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
      await _repository.refreshServers();
    } catch (e) {
      print('Ошибка обновления серверов: $e');
    }
  }

  Future<void> playStation(RadioStation station) async {
    if ((_pendingPlaybackId ?? _currentPlayingId) == station.stationuuid) {
      await stopCurrentStation();
      return;
    }
    final request = ++_playbackRequest;
    _pendingPlaybackId = station.stationuuid;
    try {
      await _repository.playStation(station);
      if (request == _playbackRequest) _setError(null);
    } catch (_) {
      if (request == _playbackRequest) {
        _setError('Не удалось воспроизвести станцию.');
      }
    } finally {
      if (request == _playbackRequest) _pendingPlaybackId = null;
    }
  }

  Future<void> stopCurrentStation() async {
    final request = ++_playbackRequest;
    _pendingPlaybackId = null;
    try {
      await _repository.stopStation();
      if (request == _playbackRequest) _setError(null);
    } catch (_) {
      if (request == _playbackRequest) {
        _setError('Не удалось остановить воспроизведение.');
      }
    }
  }

  Future<void> _loadFavoriteStations() async {
    try {
      _favoriteStations = await _storage.loadFavoriteStations();
      print('Загружено ${_favoriteStations.length} избранных станций');
    } catch (e) {
      print('Ошибка загрузки избранных станций: $e');
      _favoriteStations = [];
    }
  }

  void _setLoading(bool loading) {
    if (!_disposed && _isLoading != loading) {
      _isLoading = loading;
      _publish();
    }
  }

  void _setSearching(bool searching) {
    if (!_disposed && _isSearching != searching) {
      _isSearching = searching;
      _publish();
    }
  }

  void _setError(String? error) {
    if (!_disposed && _error != error) {
      _error = error;
      _publish();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _searchDebounceTimer?.cancel();
    _currentStationSubscription?.cancel();
    _searchController.dispose();
    _repository.dispose();
    super.dispose();
  }
}
