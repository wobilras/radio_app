import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../data/models/radio_station.dart';

class RadioBrowserService {
  static const String _userAgent = 'RadioApp/1.0';
  static const int _timeout = 5;
  List<String> _servers = [
    'https://de1.api.radio-browser.info',
    'https://nl1.api.radio-browser.info',
    'https://at1.api.radio-browser.info',
    'https://fi1.api.radio-browser.info',
    'https://fr1.api.radio-browser.info',
    'https://us1.api.radio-browser.info',
  ];

  late http.Client _httpClient;
  final Random _random = Random();
  bool _serversUpdated = false;

  RadioBrowserService() {
    _httpClient = http.Client();
    _updateServersList();
  }

  Future<void> _updateServersList() async {
    try {
      print('Обновление списка серверов Radio Browser через DNS lookup...');
      final addresses = await InternetAddress.lookup('all.api.radio-browser.info')
          .timeout(Duration(seconds: 3));

      if (addresses.isNotEmpty) {
        List<String> newServers = [];
        List<String> knownDomains = [
          'de1.api.radio-browser.info',
          'de2.api.radio-browser.info',
          'nl1.api.radio-browser.info',
          'nl2.api.radio-browser.info',
          'at1.api.radio-browser.info',
          'at2.api.radio-browser.info',
          'fi1.api.radio-browser.info',
          'fi2.api.radio-browser.info',
          'fr1.api.radio-browser.info',
          'fr2.api.radio-browser.info',
          'us1.api.radio-browser.info',
          'us2.api.radio-browser.info',
        ];

        for (String domain in knownDomains) {
          final serverUrl = 'https://$domain';
          if (!newServers.contains(serverUrl)) {
            newServers.add(serverUrl);
          }
        }
        for (var address in addresses) {
          if (address.type == InternetAddressType.IPv4) {
            try {
              final parts = address.address.split('.');
              if (parts.length == 4 && parts.every((part) => int.tryParse(part) != null)) {
                final serverUrl = 'https://${address.address}';
                if (!newServers.contains(serverUrl)) {
                  newServers.add(serverUrl);
                }
              }
            } catch (e) {
              print('Пропускаем некорректный адрес: ${address.address}');
            }
          }
        }

        if (newServers.length > _servers.length) {
          _servers = newServers;
          _serversUpdated = true;
          print('Обновлен список серверов: ${_servers.length} серверов');
        } else {
          print('DNS lookup не дал новых серверов, используем базовый список');
        }
      } else {
        print('DNS lookup не вернул адресов, используем базовый список');
      }
    } catch (e) {
      print('Ошибка DNS lookup: $e, используем базовый список серверов');
    }
    _servers.shuffle(_random);
    print('Список серверов рандомизирован: ${_servers.length} серверов');
  }

  Future<http.Response> _makeRequest(String endpoint, {Map<String, String>? queryParams, int maxAttempts = 5}) async {
    String queryString = '';
    if (queryParams != null && queryParams.isNotEmpty) {
      queryString = '?' + queryParams.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
    }

    List<String> serversToTry = List.from(_servers);
    int maxRetries = min(serversToTry.length, maxAttempts);

    for (int i = 0; i < maxRetries; i++) {
      String server = serversToTry[i];

      try {
        final url = '$server$endpoint$queryString';
        print('Попытка ${i + 1}/$maxRetries к: $server');

        final response = await _httpClient
            .get(
          Uri.parse(url),
          headers: {
            'User-Agent': _userAgent,
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        )
            .timeout(Duration(seconds: _timeout));

        if (response.statusCode == 200) {
          print('Успешный ответ от сервера: $server');
          if (i > 0) {
            _servers.remove(server);
            _servers.insert(0, server);
          }
          return response;
        } else {
          print('Сервер $server вернул код: ${response.statusCode}');
          continue;
        }
      } on TimeoutException catch (e) {
        print('Таймаут сервера $server: $e');
        continue;
      } on FormatException catch (e) {
        print('Проблема формата URL сервера $server: $e');
        _servers.remove(server);
        continue;
      } on HandshakeException catch (e) {
        print('SSL проблема сервера $server: $e');
        continue;
      } on SocketException catch (e) {
        print('Сетевая ошибка сервера $server: $e');
        continue;
      } catch (e) {
        print('Неизвестная ошибка сервера $server: $e');
        continue;
      }
    }

    throw Exception('Все проверенные серверы Radio Browser недоступны ($maxRetries попыток)');
  }

  /// Получает популярные радиостанции
  Future<List<RadioStation>> getPopularStations({int limit = 50}) async {
    try {
      final response = await _makeRequest(
        '/json/stations/topvote',
        queryParams: {'limit': limit.toString()},
      );

      final List<dynamic> data = json.decode(response.body);
      final stations = data.map((json) => RadioStation.fromJson(json)).toList();
      print('Загружено ${stations.length} популярных станций');
      return stations;
    } catch (e) {
      print('Ошибка получения популярных станций: $e');

      // Если серверы еще не обновлялись, пытаемся обновить их
      if (!_serversUpdated) {
        print('Пытаемся обновить список серверов...');
        await _updateServersList();
        try {
          final response = await _makeRequest(
            '/json/stations/topvote',
            queryParams: {'limit': limit.toString()},
          );
          final List<dynamic> data = json.decode(response.body);
          final stations = data.map((json) => RadioStation.fromJson(json)).toList();
          print('Загружено ${stations.length} популярных станций после обновления серверов');
          return stations;
        } catch (retryError) {
          print('Повторная попытка также не удалась: $retryError');
        }
      }

      return [];
    }
  }

  Future<List<RadioStation>> searchStations({
    String? name,
    String? country,
    String? tag,
    int limit = 50,
  }) async {
    try {
      Map<String, String> params = {'limit': limit.toString()};

      if (name != null && name.isNotEmpty) {
        params['name'] = name;
      }
      if (country != null && country.isNotEmpty) {
        params['country'] = country;
      }
      if (tag != null && tag.isNotEmpty) {
        params['tag'] = tag;
      }

      final response = await _makeRequest('/json/stations/search', queryParams: params);

      final List<dynamic> data = json.decode(response.body);
      final stations = data.map((json) => RadioStation.fromJson(json)).toList();
      print('Найдено ${stations.length} станций по поиску');
      return stations;
    } catch (e) {
      print('Ошибка поиска станций: $e');

      // Если серверы еще не обновлялись, пытаемся обновить их
      if (!_serversUpdated) {
        print('🔄 Пытаемся обновить список серверов для поиска...');
        await _updateServersList();
        try {
          Map<String, String> params = {'limit': limit.toString()};

          if (name != null && name.isNotEmpty) {
            params['name'] = name;
          }
          if (country != null && country.isNotEmpty) {
            params['country'] = country;
          }
          if (tag != null && tag.isNotEmpty) {
            params['tag'] = tag;
          }

          final response = await _makeRequest('/json/stations/search', queryParams: params);
          final List<dynamic> data = json.decode(response.body);
          final stations = data.map((json) => RadioStation.fromJson(json)).toList();
          print('Найдено ${stations.length} станций после обновления серверов');
          return stations;
        } catch (retryError) {
          print('Повторная попытка поиска также не удалась: $retryError');
        }
      }

      return [];
    }
  }

  Future<List<RadioStation>> getStationsByCountry(String countryCode, {int limit = 50}) async {
    try {
      final response = await _makeRequest(
        '/json/stations/bycountrycodeexact/$countryCode',
        queryParams: {'limit': limit.toString()},
      );

      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => RadioStation.fromJson(json)).toList();
    } catch (e) {
      print('Ошибка получения станций по стране: $e');
      return [];
    }
  }

  Future<void> registerStationClick(String stationUuid) async {
    try {
      await _makeRequest('/json/url/$stationUuid', maxAttempts: 1);
      print('Клик по станции зарегистрирован: $stationUuid');
    } catch (e) {
      print('Ошибка регистрации клика: $e');
      // Не критично если клик не зарегистрировался
    }
  }

  Future<void> refreshServers() async {
    print('Принудительное обновление списка серверов...');
    _serversUpdated = false;
    await _updateServersList();
  }

  List<String> get currentServers => List.unmodifiable(_servers);

  void dispose() {
    _httpClient.close();
  }
}