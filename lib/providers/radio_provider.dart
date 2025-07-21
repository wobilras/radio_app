import 'dart:async';

import 'package:flutter/material.dart';

import '../data/models/radio_station.dart';
import '../data/radio_browser.dart';
import '../data/radio_player.dart';
import '../data/repositories/radio_repository.dart';

enum TabType { stations, favorites }

enum StationLoadingMode { popular, topVoted, search, country, tag, new_ }

class RadioProvider extends ChangeNotifier {
  final RadioRepository _repository = RadioRepositoryImpl();

  List<RadioStation> _stations = [];
  List<String> _favoriteStationIds = [];
  bool _isLoading = false;
  RadioStation? _currentPlayingStation;
  String? _error;
  StationLoadingMode _currentMode = StationLoadingMode.popular;

  TabType _currentTab = TabType.stations;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  int _currentOffset = 0;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;

  StreamSubscription<bool>? _playingStateSubscription;
  StreamSubscription<RadioStation?>? _currentStationSubscription;
  StreamSubscription<String?>? _metadataSubscription;
  StreamSubscription<AppError?>? _errorSubscription;

  List<RadioStation> get stations => _stations;
  List<RadioStation> get favoriteStations {
    return _stations.where((station) => _favoriteStationIds.contains(station.id)).toList();
  }
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreData => _hasMoreData;
  RadioStation? get currentPlayingStation => _currentPlayingStation;
  String? get currentPlayingId => _currentPlayingStation?.id;
  String? get error => _error;
  TabType get currentTab => _currentTab;
  String get searchQuery => _searchQuery;
  TextEditingController get searchController => _searchController;
  StationLoadingMode get currentMode => _currentMode;

  List<RadioStation> get filteredStations {
    List<RadioStation> sourceList = _currentTab == TabType.stations
        ? _stations
        : favoriteStations;

    if (_searchQuery.isEmpty) {
      return sourceList;
    }

    return sourceList.where((station) {
      final query = _searchQuery.toLowerCase();
      return station.name.toLowerCase().contains(query) ||
          station.frequency.toLowerCase().contains(query) ||
          station.description.toLowerCase().contains(query) ||
          (station.country?.toLowerCase().contains(query) ?? false) ||
          (station.tags?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  RadioProvider() {
    _initializeApp();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _initializeApp() async {
    await _loadFavorites();
    await _initializePlayer();
    await loadStations();
  }

  Future<void> _initializePlayer() async {
    final initResult = await RadioPlayerService.initialize();
    if (initResult.isFailure) {
      _error = initResult.error!.message;
      notifyListeners();
      return;
    }

    _playingStateSubscription = RadioPlayerService.playingStateStream.listen(
          (isPlaying) {
        notifyListeners();
      },
    );

    _currentStationSubscription = RadioPlayerService.currentStationStream.listen(
          (station) {
        _currentPlayingStation = station;
        notifyListeners();
      },
    );

    _metadataSubscription = RadioPlayerService.metadataStream.listen(
          (metadata) {
        // Обработка метаданных (название трека и т.д.)
        // Можно показать в UI если нужно
      },
    );

    _errorSubscription = RadioPlayerService.errorStream.listen(
          (error) {
        if (error != null) {
          _error = error.message;
          notifyListeners();
        }
      },
    );
  }

  void _onSearchChanged() {
    _searchQuery = _searchController.text;
    notifyListeners();

    // Debounce для поиска
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(Duration(milliseconds: 500), () {
      if (_searchQuery.isNotEmpty && _searchQuery.length >= 2) {
        searchStations(_searchQuery);
      } else if (_searchQuery.isEmpty) {
        loadStations();
      }
    });
  }

  Timer? _searchDebounceTimer;

  void setCurrentTab(TabType tab) {
    _currentTab = tab;
    notifyListeners();
  }

  void clearSearch() {
    _searchController.clear();
    _searchQuery = '';
    notifyListeners();
  }

  bool isFavorite(String stationId) {
    return _favoriteStationIds.contains(stationId);
  }

  Future<void> toggleFavorite(String stationId) async {
    if (isFavorite(stationId)) {
      _favoriteStationIds.remove(stationId);
    } else {
      _favoriteStationIds.add(stationId);
    }

    await _saveFavorites();
    notifyListeners();
  }

  Future<void> _loadFavorites() async {
    final result = await _repository.loadFavoriteStations();
    if (result.isSuccess) {
      _favoriteStationIds = result.data!;
      notifyListeners();
    } else {
      print('Error loading favorites: ${result.error}');
    }
  }

  Future<void> _saveFavorites() async {
    final result = await _repository.saveFavoriteStations(_favoriteStationIds);
    if (result.isFailure) {
      print('Error saving favorites: ${result.error}');
    }
  }

  Future<void> loadStations({StationLoadingMode mode = StationLoadingMode.popular}) async {
    _isLoading = true;
    _error = null;
    _currentOffset = 0;
    _hasMoreData = true;
    _currentMode = mode;
    notifyListeners();

    final result = await _loadStationsByMode(mode, limit: 50, offset: 0);

    if (result.isSuccess) {
      _stations = result.data!;
      _hasMoreData = result.data!.length >= 50;
    } else {
      _error = result.error!.message;
      _stations = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadMoreStations() async {
    if (_isLoadingMore || !_hasMoreData || _isLoading) return;

    _isLoadingMore = true;
    notifyListeners();

    _currentOffset += 50;
    final result = await _loadStationsByMode(_currentMode, limit: 50, offset: _currentOffset);

    if (result.isSuccess) {
      final newStations = result.data!;
      _stations.addAll(newStations);
      _hasMoreData = newStations.length >= 50;
    } else {
      _error = result.error!.message;
    }

    _isLoadingMore = false;
    notifyListeners();
  }

  Future<Result<List<RadioStation>>> _loadStationsByMode(
      StationLoadingMode mode, {
        required int limit,
        required int offset,
      }) async {
    switch (mode) {
      case StationLoadingMode.popular:
        return await _repository.getPopularStations(limit: limit, offset: offset);
      case StationLoadingMode.topVoted:
        return await _repository.getTopVotedStations(limit: limit, offset: offset);
      case StationLoadingMode.new_:
        return await _repository.getNewStations(limit: limit);
      case StationLoadingMode.search:
      case StationLoadingMode.country:
      case StationLoadingMode.tag:
        return await _repository.getPopularStations(limit: limit, offset: offset);
    }
  }

  // Поиск станций
  Future<void> searchStations(String query) async {
    if (query.trim().isEmpty) {
      await loadStations();
      return;
    }

    _isLoading = true;
    _error = null;
    _currentMode = StationLoadingMode.search;
    _currentOffset = 0;
    notifyListeners();

    final result = await _repository.searchStations(name: query.trim(), limit: 50);

    if (result.isSuccess) {
      _stations = result.data!;
      _hasMoreData = false; // Поиск не поддерживает пагинацию
    } else {
      _error = result.error!.message;
      _stations = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  // Загрузка станций по стране
  Future<void> loadStationsByCountry(String countryCode) async {
    _isLoading = true;
    _error = null;
    _currentMode = StationLoadingMode.country;
    notifyListeners();

    final result = await _repository.getStationsByCountry(countryCode);

    if (result.isSuccess) {
      _stations = result.data!;
      _hasMoreData = false;
    } else {
      _error = result.error!.message;
      _stations = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  // Загрузка станций по тегу
  Future<void> loadStationsByTag(String tag) async {
    _isLoading = true;
    _error = null;
    _currentMode = StationLoadingMode.tag;
    notifyListeners();

    final result = await _repository.getStationsByTag(tag);

    if (result.isSuccess) {
      _stations = result.data!;
      _hasMoreData = false;
    } else {
      _error = result.error!.message;
      _stations = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  // Управление воспроизведением
  Future<void> playStation(String stationId) async {
    try {
      final station = _stations.firstWhere((s) => s.id == stationId);

      if (_currentPlayingStation?.id == stationId && RadioPlayerService.isPlaying) {
        // Если станция уже играет, останавливаем
        final result = await _repository.stopStation();
        if (result.isFailure) {
          _error = result.error!.message;
          notifyListeners();
        }
      } else {
        // Воспроизводим станцию
        final result = await _repository.playStation(station);
        if (result.isFailure) {
          _error = result.error!.message;
          notifyListeners();
        }
      }
    } catch (e) {
      _error = 'Station not found: $e';
      notifyListeners();
    }
  }

  Future<void> stopCurrentStation() async {
    final result = await _repository.stopStation();
    if (result.isFailure) {
      _error = result.error!.message;
      notifyListeners();
    }
  }

  Future<void> pauseCurrentStation() async {
    final result = await _repository.pauseStation();
    if (result.isFailure) {
      _error = result.error!.message;
      notifyListeners();
    }
  }

  Future<void> resumeCurrentStation() async {
    final result = await _repository.resumeStation();
    if (result.isFailure) {
      _error = result.error!.message;
      notifyListeners();
    }
  }

  // Очистка ошибок
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Refresh данных
  Future<void> refresh() async {
    await loadStations(mode: _currentMode);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounceTimer?.cancel();
    _playingStateSubscription?.cancel();
    _currentStationSubscription?.cancel();
    _metadataSubscription?.cancel();
    _errorSubscription?.cancel();
    RadioPlayerService.dispose();
    super.dispose();
  }

  // Отладочная информация
  String getDebugInfo() {
    return '''
    Provider Debug Info:
    - Stations Count: ${_stations.length}
    - Favorites Count: ${_favoriteStationIds.length}
    - Current Tab: $_currentTab
    - Loading: $_isLoading
    - Error: $_error
    - Current Mode: $_currentMode
    - Search Query: "$_searchQuery"
    - Has More Data: $_hasMoreData
    ${RadioPlayerService.getDebugInfo()}
    ''';
  }
}