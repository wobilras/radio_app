import 'dart:async';

import '../models/radio_station.dart';
import '../radio_browser.dart';
import '../radio_player.dart';

abstract class RadioRepository {
  Future<void> initialize();
  void dispose();
  Future<List<RadioStation>> getRadioStations();
  Future<List<RadioStation>> searchStations(String query);
  Future<List<RadioStation>> getStationsByCountry(String countryCode);
  Future<void> playStation(RadioStation station);
  Future<void> stopStation();
  Future<void> refreshServers();
  Stream<String?> get currentStationStream;
  String? get currentStationId;
}

class RadioRepositoryImpl implements RadioRepository {
  RadioRepositoryImpl({
    RadioBrowserService? browserService,
    AudioPlayerService? audioService,
  }) : _browserService = browserService ?? RadioBrowserService(),
       _audioService = audioService ?? AudioPlayerService();

  final RadioBrowserService _browserService;
  final AudioPlayerService _audioService;

  @override
  Stream<String?> get currentStationStream => _audioService.currentStationStream;

  @override
  String? get currentStationId => _audioService.currentStationId;

  @override
  Future<void> initialize() async {
    await _audioService.initialize();
  }

  @override
  Future<List<RadioStation>> getRadioStations() async {
    try {
      print('Загрузка популярных радиостанций...');
      final stations = await _browserService.getPopularStations(limit: 100);
      final validStations = stations.where((station) {
        return station.url.isNotEmpty &&
            station.name.isNotEmpty &&
            (station.url.startsWith('http://') || station.url.startsWith('https://'));
      }).toList();

      if (validStations.isNotEmpty) {
        print('Загружено ${validStations.length} станций');
        return validStations;
      } else {
        print('Нет валидных станций, пробуем обновить серверы...');
        await _browserService.refreshServers();
        final retryStations = await _browserService.getPopularStations(limit: 100);
        final retryValidStations = retryStations.where((station) {
          return station.url.isNotEmpty &&
              station.name.isNotEmpty &&
              (station.url.startsWith('http://') || station.url.startsWith('https://'));
        }).toList();

        if (retryValidStations.isNotEmpty) {
          print('После обновления серверов загружено ${retryValidStations.length} станций');
          return retryValidStations;
        } else {
          print('Используем резервные данные');
          return _getFallbackStations();
        }
      }
    } catch (e) {
      print('Ошибка загрузки станций: $e');
      return _getFallbackStations();
    }
  }

  @override
  Future<List<RadioStation>> searchStations(String query) async {
    try {
      print('Поиск станций: $query');

      if (query.trim().isEmpty) {
        return await getRadioStations();
      }

      final stations = await _browserService.searchStations(
        name: query,
        limit: 50,
      );

      final validStations = stations.where((station) {
        return station.url.isNotEmpty &&
            station.name.isNotEmpty &&
            (station.url.startsWith('http://') || station.url.startsWith('https://'));
      }).toList();

      print('Найдено ${validStations.length} станций по запросу: "$query"');
      return validStations;
    } catch (e) {
      print('Ошибка поиска станций: $e');
      return [];
    }
  }

  @override
  Future<List<RadioStation>> getStationsByCountry(String countryCode) async {
    try {
      print('Загрузка станций для страны: $countryCode');

      final stations = await _browserService.getStationsByCountry(countryCode, limit: 50);

      final validStations = stations.where((station) {
        return station.url.isNotEmpty &&
            station.name.isNotEmpty &&
            (station.url.startsWith('http://') || station.url.startsWith('https://'));
      }).toList();

      print('Загружено ${validStations.length} станций для страны $countryCode');
      return validStations;
    } catch (e) {
      print('Ошибка загрузки станций по стране: $e');
      return [];
    }
  }

  @override
  Future<void> playStation(RadioStation station) async {
    try {
      final started = await _audioService.playStation(
        station.stationuuid,
        station.name,
        station.url,
      );

      if (started && !station.stationuuid.startsWith('fallback-')) {
        unawaited(_browserService.registerStationClick(station.stationuuid));
      }
    } catch (e) {
      print('Ошибка воспроизведения станции: $e');
      rethrow;
    }
  }

  @override
  Future<void> stopStation() async {
    try {
      await _audioService.stop();
      print('Воспроизведение остановлено');
    } catch (e) {
      print('Ошибка остановки воспроизведения: $e');
      rethrow;
    }
  }

  @override
  Future<void> refreshServers() async {
    await _browserService.refreshServers();
  }

  /// Резервные данные на случай проблем с API
  List<RadioStation> _getFallbackStations() {
    return [
      RadioStation(
        stationuuid: 'fallback-1',
        name: 'Радио Маяк',
        url: 'https://icecast-radiomayak.cdnvideo.ru/radiomayak',
        favicon: 'https://via.placeholder.com/150/FF6B6B/FFFFFF?text=МАЯК',
        country: 'Russia',
        countrycode: 'RU',
        language: 'russian',
        tags: 'news,music',
        votes: 100,
        bitrate: 128,
        codec: 'MP3',
      ),
      RadioStation(
        stationuuid: 'fallback-2',
        name: 'Европа Плюс',
        url: 'https://ep256.hostingradio.ru:8052/europaplus256.mp3',
        favicon: 'https://via.placeholder.com/150/4ECDC4/FFFFFF?text=ЕВРОПА+',
        country: 'Russia',
        countrycode: 'RU',
        language: 'russian',
        tags: 'pop,hits',
        votes: 95,
        bitrate: 256,
        codec: 'MP3',
      ),
      RadioStation(
        stationuuid: 'fallback-3',
        name: 'BBC World Service',
        url: 'https://stream.live.vc.bbcmedia.co.uk/bbc_world_service',
        favicon: 'https://via.placeholder.com/150/45B7D1/FFFFFF?text=BBC',
        country: 'United Kingdom',
        countrycode: 'GB',
        language: 'english',
        tags: 'news,world',
        votes: 150,
        bitrate: 128,
        codec: 'AAC',
      ),
    ];
  }

  @override
  void dispose() {
    unawaited(_audioService.dispose().catchError((Object error) {
      print('Ошибка освобождения плеера: $error');
    }));
    _browserService.dispose();
  }
}