import 'dart:async';
import 'dart:developer' as developer;

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
  Future<void>? _catalogLoad;
  bool _isSearching = false;
  String? _currentPlayingId;
  RadioStation? _currentStation;
  bool _paused = false;
  bool _playbackBusy = false;
  String? _pendingPlaybackId;
  int _playbackRequest = 0;
  String? _catalogError;
  String? _searchError;
  String? _favoritesError;
  ({String message, Future<void> Function() retry})? _playbackFailure;
  TabType _currentTab = TabType.stations;
  String _searchQuery = '';
  int _searchRequest = 0;
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription? _currentStationSubscription;
  Timer? _searchDebounceTimer;

  List<RadioStation> get stations => List.unmodifiable(_stations);
  List<RadioStation> get favoriteStations =>
      List.unmodifiable(_favoriteStations);
  List<RadioStation> get searchResults => List.unmodifiable(_searchResults);
  bool get isLoading =>
      _currentTab == TabType.stations && _searchQuery.isEmpty && _isLoading;
  bool get isSearching => _isSearching;
  String? get currentPlayingId => _paused ? null : _currentPlayingId;
  RadioStation? get currentStation => _currentStation;
  bool get isPaused => _paused;
  bool get playbackBusy => _playbackBusy || _pendingPlaybackId != null;
  String? get catalogError => _currentTab == TabType.favorites
      ? null
      : (_searchQuery.isEmpty ? _catalogError : _searchError);
  String? get favoritesError => _favoritesError;
  ({String message, Future<void> Function() retry})? get playbackFailure =>
      _playbackFailure;
  bool get hasFallbackStations =>
      _currentTab == TabType.stations &&
      _searchQuery.isEmpty &&
      _stations.isNotEmpty &&
      _stations.every((station) => station.stationuuid.startsWith('fallback-'));
  TabType get currentTab => _currentTab;
  String get searchQuery => _searchQuery;
  TextEditingController get searchController => _searchController;

  List<RadioStation> get filteredStations {
    if (_currentTab == TabType.favorites) return favoriteStations;
    return _searchQuery.isEmpty ? stations : searchResults;
  }

  RadioProvider({required this._repository, required this._storage}) {
    _searchController.addListener(_onSearchChanged);
    _currentPlayingId = _repository.currentStationId;
    _currentStationSubscription = _repository.currentStationStream.listen((
      stationId,
    ) {
      if (_disposed || _currentPlayingId == stationId) return;
      _currentPlayingId = stationId;
      if (stationId == null && _pendingPlaybackId == null) {
        _currentStation = null;
        _paused = false;
      }
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
      _catalogError = 'Не удалось запустить радио.';
      _publish();
    }
  }

  void _publish() {
    if (!_disposed) notifyListeners();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (_searchQuery == query) return;

    _searchDebounceTimer?.cancel();
    final request = ++_searchRequest;
    _searchQuery = query;
    _searchError = null;
    _searchResults = [];
    _isSearching = query.isNotEmpty;
    _publish();
    if (query.isNotEmpty) {
      _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
        unawaited(_performSearch(query, request));
      });
    }
  }

  void setCurrentTab(TabType tab) {
    if (_currentTab != tab) {
      _currentTab = tab;
      if (tab == TabType.favorites && _searchController.text.isNotEmpty) {
        clearSearch();
      } else {
        _publish();
      }
    }
  }

  void clearSearch() => _searchController.clear();

  Future<void> reloadActive() async {
    if (_currentTab == TabType.favorites) {
      await _loadFavoriteStations();
      return;
    }
    final query = _searchQuery;
    if (query.isEmpty) return loadStations();

    _searchDebounceTimer?.cancel();
    final request = ++_searchRequest;
    _searchError = null;
    _setSearching(true);
    await _performSearch(query, request);
  }

  Future<void> _performSearch(String query, int request) async {
    try {
      final results = await _repository.searchStations(query);
      if (!_disposed && request == _searchRequest) {
        _searchResults = results;
        _searchError = null;
        if (results.isNotEmpty) {
          await _queueFavoriteChange(() async {
            _favoriteStations = await _storage.resolveFavorites(results);
          });
        }
      }
    } catch (error) {
      if (!_disposed && request == _searchRequest) {
        developer.log(
          'Station search failed',
          name: 'radio.catalog',
          error: error.runtimeType,
        );
        _searchError = error is FormatException
            ? 'Каталог вернул повреждённые данные.'
            : 'Не удалось выполнить поиск станций.';
      }
    } finally {
      if (request == _searchRequest) _setSearching(false);
    }
  }

  bool isFavorite(String stationId) {
    return _favoriteStations.any((station) => station.stationuuid == stationId);
  }

  Future<void> toggleFavorite(RadioStation station) {
    return _queueFavoriteChange(() async {
      final favorites = await _storage.toggleFavorite(station);
      if (!_disposed) _favoriteStations = favorites;
    });
  }

  Future<void> _queueFavoriteChange(Future<void> Function() change) {
    return _favoriteChanges = _favoriteChanges.then((_) async {
      if (_disposed) return;
      try {
        await change();
        _favoritesError = null;
        _publish();
      } catch (_) {
        _favoritesError = 'Не удалось сохранить избранное.';
        _publish();
      }
    });
  }

  Future<void> loadStations() =>
      _catalogLoad ??= _loadCatalog().whenComplete(() {
        _catalogLoad = null;
      });

  Future<void> _loadCatalog() async {
    _catalogError = null;
    _setLoading(true);
    try {
      final stations = await _repository.getRadioStations();
      if (_disposed) return;
      _stations = stations;
      if (stations.isNotEmpty) {
        await _queueFavoriteChange(() async {
          _favoriteStations = await _storage.resolveFavorites(stations);
        });
      }
    } catch (error) {
      developer.log(
        'Catalog load failed',
        name: 'radio.catalog',
        error: error.runtimeType,
      );
      _catalogError = error is FormatException
          ? 'Каталог вернул повреждённые данные.'
          : 'Не удалось загрузить каталог.';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refreshServers() async {
    await _repository.refreshServers();
    if (!_disposed) await reloadActive();
  }

  Future<void> playStation(RadioStation station) {
    if (_paused && _currentStation?.stationuuid == station.stationuuid) {
      return togglePlayback();
    }
    if ((_pendingPlaybackId ?? _currentPlayingId) == station.stationuuid) {
      return stopCurrentStation();
    }
    if (_currentStation?.stationuuid != station.stationuuid) {
      _playbackFailure = null;
    }
    return _startPlayback(station);
  }

  Future<void> _startPlayback(RadioStation station) {
    _currentStation = station;
    _paused = false;
    _publish();
    return _runPlayback(
      station.stationuuid,
      () => _repository.playStation(station),
      'Не удалось воспроизвести станцию.',
      () => _startPlayback(station),
    );
  }

  Future<void> togglePlayback() async {
    final station = _currentStation;
    if (station == null || _playbackBusy || _pendingPlaybackId != null) return;
    final request = ++_playbackRequest;
    final wasPaused = _paused;
    _playbackBusy = true;
    _publish();
    try {
      if (wasPaused) {
        await _repository.resumeStation(station.stationuuid);
      } else {
        await _repository.pauseStation(station.stationuuid);
      }
      if (request == _playbackRequest && _currentStation == station) {
        _paused = !wasPaused;
        _playbackFailure = null;
      }
    } catch (_) {
      if (request == _playbackRequest) {
        _playbackFailure = (
          message: 'Не удалось изменить воспроизведение.',
          retry: togglePlayback,
        );
      }
    } finally {
      if (request == _playbackRequest) _playbackBusy = false;
      _publish();
    }
  }

  Future<void> stopCurrentStation() {
    return _runPlayback(
      null,
      _repository.stopStation,
      'Не удалось остановить воспроизведение.',
      stopCurrentStation,
    );
  }

  Future<void> _runPlayback(
    String? pendingId,
    Future<void> Function() action,
    String message,
    Future<void> Function() retry,
  ) async {
    final request = ++_playbackRequest;
    _playbackBusy = false;
    _pendingPlaybackId = pendingId;
    try {
      await action();
      if (request == _playbackRequest) {
        _playbackFailure = null;
        if (pendingId == null) {
          _currentStation = null;
          _paused = false;
        }
      }
    } catch (error) {
      if (request == _playbackRequest) {
        developer.log(
          'Playback command failed for ${pendingId ?? 'stop'}',
          name: 'radio.playback',
          error: error.runtimeType,
        );
        _playbackFailure = (message: message, retry: retry);
      }
    } finally {
      if (request == _playbackRequest) {
        _pendingPlaybackId = null;
        _publish();
      }
    }
  }

  Future<void> _loadFavoriteStations() {
    return _queueFavoriteChange(() async {
      final favorites = await _storage.loadFavoriteStations();
      if (!_disposed) _favoriteStations = favorites;
    });
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
