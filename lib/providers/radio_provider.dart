import 'package:flutter/material.dart';

import '../data/models/radio_station.dart';
import '../data/repositories/radio_repository.dart';

enum TabType { stations, favorites }

class RadioProvider extends ChangeNotifier {
  final RadioRepository _repository = RadioRepositoryImpl();

  List<RadioStation> _stations = [];
  List<RadioStation> _favoriteStations = [];
  bool _isLoading = false;
  String? _currentPlayingId;
  String? _error;
  TabType _currentTab = TabType.stations;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<RadioStation> get stations => _stations;
  List<RadioStation> get favoriteStations => _favoriteStations;
  bool get isLoading => _isLoading;
  String? get currentPlayingId => _currentPlayingId;
  String? get error => _error;
  TabType get currentTab => _currentTab;
  String get searchQuery => _searchQuery;
  TextEditingController get searchController => _searchController;

  List<RadioStation> get filteredStations {
    List<RadioStation> sourceList = _currentTab == TabType.stations
        ? _stations
        : _favoriteStations;

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
    loadStations();
    _searchController.addListener(_onSearchChanged);
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
    return _favoriteStations.any((station) => station.id == stationId);
  }

  void toggleFavorite(String stationId) {
    final station = _stations.firstWhere((s) => s.id == stationId);

    if (isFavorite(stationId)) {
      _favoriteStations.removeWhere((s) => s.id == stationId);
    } else {
      _favoriteStations.add(station);
    }
    notifyListeners();
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