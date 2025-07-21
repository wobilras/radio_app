import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../data/models/radio_station.dart';

class RadioBrowserService {
  static const String _userAgent = 'RadioApp/1.0';
  static const int _timeout = 10;

  List<String> _servers = [
    'https://de1.api.radio-browser.info',
    'https://nl1.api.radio-browser.info',
    'https://at1.api.radio-browser.info',
    'https://fi1.api.radio-browser.info',
    'https://ru1.api.radio-browser.info',
  ];

  late http.Client _httpClient;
  final Random _random = Random();

  RadioBrowserService() {
    _httpClient = http.Client();
    _updateServersList();
  }

  Future<void> _updateServersList() async {
    try {
      print('Обновление списка серверов Radio Browser через DNS lookup...');

      final addresses = await InternetAddress.lookup('all.api.radio-browser.info');

      if (addresses.isNotEmpty) {
        List<String> newServers = [];

        for (var address in addresses) {
          try {
            final hostnames = await InternetAddress.lookup(address.address, type: InternetAddressType.any);
            for (var hostname in hostnames) {
              final serverUrl = 'https://${hostname.host}';
              if (!newServers.contains(serverUrl)) {
                newServers.add(serverUrl);
              }
            }
          } catch (e) {
            final serverUrl = 'https://${address.address}';
            if (!newServers.contains(serverUrl)) {
              newServers.add(serverUrl);
            }
          }
        }

        if (newServers.isNotEmpty) {
          _servers = newServers;
          print('Найдено серверов: ${_servers.length}');
        } else {
          print('DNS lookup не вернул серверов, используем резервный список');
        }
      } else {
        print('DNS lookup не вернул адресов, используем резервный список');
      }
    } catch (e) {
      print('Ошибка DNS lookup: $e, используем резервный список');
    }

    _servers.shuffle(_random);
    print('Список серверов рандомизирован: ${_servers.length} серверов');
  }

  /// Выполняет HTTP запрос с перебором серверов при неудаче
  Future<http.Response> _makeRequest(String endpoint, {Map<String, String>? queryParams}) async {
    String queryString = '';
    if (queryParams != null && queryParams.isNotEmpty) {
      queryString = '?${queryParams.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&')}';
    }

    for (String server in _servers) {
      try {
        final url = '$server$endpoint$queryString';
        print('Попытка запроса к: $url');

        final response = await _httpClient
            .get(
          Uri.parse(url),
          headers: {
            'User-Agent': _userAgent,
            'Content-Type': 'application/json',
          },
        )
            .timeout(Duration(seconds: _timeout));

        if (response.statusCode == 200) {
          print('Успешный ответ от сервера: $server');
          return response;
        } else {
          print('Сервер $server вернул код: ${response.statusCode}');
          continue;
        }
      } catch (e) {
        print('Ошибка сервера $server: $e');
        continue;
      }
    }

    throw Exception('Все серверы Radio Browser недоступны');
  }

  Future<List<RadioStation>> getPopularStations({int limit = 50}) async {
    try {
      final response = await _makeRequest(
        '/json/stations/topvote',
        queryParams: {'limit': limit.toString()},
      );

      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => RadioStation.fromJson(json)).toList();
    } catch (e) {
      print('Ошибка получения популярных станций: $e');
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
      return data.map((json) => RadioStation.fromJson(json)).toList();
    } catch (e) {
      print('Ошибка поиска станций: $e');
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

  /// Регистрирует клик по станции (важно для статистики согласно документации)
  Future<void> registerStationClick(String stationUuid) async {
    try {
      await _makeRequest('/json/url/$stationUuid');
      print('Клик по станции зарегистрирован: $stationUuid');
    } catch (e) {
      print('Ошибка регистрации клика: $e');
    }
  }

  void dispose() {
    _httpClient.close();
  }
}