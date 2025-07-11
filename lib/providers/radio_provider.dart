import 'package:flutter/material.dart';

import '../data/models/radio_station.dart';
import '../data/repositories/radio_repository.dart';

enum TabType { stations, favorites }

class RadioProvider extends ChangeNotifier {
  final RadioRepository _repository = RadioRepositoryImpl();

  List<RadioStation> _stations = [];
  List<String> _favoriteStationIds = [];
  bool _isLoading = false;
  String? _currentPlayingId;
  String? _error;
  TabType _currentTab = TabType.stations;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<RadioStation> get stations => _stations;
  List<RadioStation> get favoriteStations {
    return _stations.where((station) => _favoriteStationIds.contains(station.id)).toList();
  }
  bool get isLoading => _isLoading;
  String? get currentPlayingId => _currentPlayingId;
  String? get error => _error;
  TabType get currentTab => _currentTab;
  String get searchQuery => _searchQuery;
  TextEditingController get searchController => _searchController;

  List<RadioStation> get filteredStations {
    List<RadioStation> sourceList = _currentTab == TabType.stations
        ? _stations
        : favoriteStations;

    if (_searchQuery.isEmpty) {
      return sourceList;
    }

    return sourceList.where((station) {
      return station.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          station.frequency.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          station.description.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  RadioProvider() {
    _initializeApp();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _initializeApp() async {
    await loadStations();
    await _loadFavorites();
  }

  void _onSearchChanged() {
    _searchQuery = _searchController.text;
    notifyListeners();
  }

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
    try {
      _favoriteStationIds = await _repository.loadFavoriteStations();
      notifyListeners();
    } catch (e) {
      print('Ошибка загрузки избранного: $e');
    }
  }

  Future<void> _saveFavorites() async {
    try {
      await _repository.saveFavoriteStations(_favoriteStationIds);
    } catch (e) {
      print('Ошибка сохранения избранного: $e');
    }
  }

  Future<void> loadStations() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _stations = await _repository.getRadioStations();
    } catch (e) {
      _error = 'Ошибка загрузки станций: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> playStation(String stationId) async {
    try {
      if (_currentPlayingId == stationId) {
        await _repository.stopStation();
        _currentPlayingId = null;
      } else {
        await _repository.playStation(stationId);
        _currentPlayingId = stationId;
      }
      notifyListeners();
    } catch (e) {
      _error = 'Ошибка воспроизведения: $e';
      notifyListeners();
    }
  }

  Future<void> stopCurrentStation() async {
    if (_currentPlayingId != null) {
      try {
        await _repository.stopStation();
        _currentPlayingId = null;
        notifyListeners();
      } catch (e) {
        _error = 'Ошибка остановки: $e';
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}