import '../models/radio_station.dart';
import '../radio_browser.dart';
import '../radio_player.dart';

abstract class RadioRepository {
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
  final RadioBrowserService _browserService = RadioBrowserService();
  final AudioPlayerService _audioService = AudioPlayerService();

  @override
  Stream<String?> get currentStationStream => _audioService.currentStationStream;

  @override
  String? get currentStationId => _audioService.currentStationId;

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
      await _browserService.registerStationClick(station.stationuuid);
      await _audioService.playStation(
        station.stationuuid,
        station.name,
        station.url,
      );

      print('Станция ${station.name} начала воспроизводиться');
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

  void dispose() {
    _audioService.dispose();
    _browserService.dispose();
  }
}