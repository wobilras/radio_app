import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'models/radio_station.dart';
import 'package:http/http.dart' as http;

class RadioBrowserService {
  static List<String> _servers = [
    'https://de1.api.radio-browser.info',
    'https://nl1.api.radio-browser.info',
    'https://ru1.api.radio-browser.info',
  ];

  static const String _userAgent = 'FlutterRadioApp/1.0.0';
  static const Duration _timeout = Duration(seconds: 5);
  static DateTime? _lastServerUpdate;
  static const Duration _serverUpdateInterval = Duration(hours: 1);
  static int _currentServerIndex = 0;

  static String? _cachedServer;

  static String get _baseUrl {
    return _cachedServer ?? _servers[_currentServerIndex];
  }

  static Future<void> updateServersList() async {
    if (_lastServerUpdate != null &&
        DateTime.now().difference(_lastServerUpdate!) < _serverUpdateInterval) {
      return;
    }

    try {
      print('Updating Radio Browser servers list via DNS lookup...');

      final List<InternetAddress> addresses =
      await InternetAddress.lookup('all.api.radio-browser.info')
          .timeout(Duration(seconds: 5));

      List<String> newServers = [];

      for (final address in addresses) {
        try {
          final List<InternetAddress> reverseAddresses =
          await InternetAddress.lookup(address.address)
              .timeout(Duration(seconds: 3));

          if (reverseAddresses.isNotEmpty) {
            final hostname = reverseAddresses.first.host;

            if (hostname.contains('api.radio-browser.info')) {
              final serverUrl = 'https://$hostname';
              if (!newServers.contains(serverUrl)) {
                newServers.add(serverUrl);
              }
            }
          }
        } catch (e) {
          print('Reverse lookup failed for ${address.address}: $e');
          final serverUrl = 'https://${address.address}';
          if (!newServers.contains(serverUrl)) {
            newServers.add(serverUrl);
          }
        }
      }

      if (newServers.isNotEmpty) {
        print('Found ${newServers.length} servers via DNS');

        final combinedServers = <String>[];
        combinedServers.addAll(newServers);

        for (final fallbackServer in _servers) {
          if (!combinedServers.contains(fallbackServer)) {
            combinedServers.add(fallbackServer);
          }
        }

        _servers = combinedServers;
        _cachedServer = null; // Сбрасываем кэш
        _currentServerIndex = 0; // Начинаем с первого сервера
        _lastServerUpdate = DateTime.now();

        print('Updated servers list (${_servers.length} total):');
        for (int i = 0; i < _servers.length; i++) {
          print('  $i: ${_servers[i]}');
        }
      } else {
        print('No servers found via DNS, keeping fallback list');
      }

    } catch (e) {
      print('DNS lookup failed: $e');
      print('Using fallback servers list (${_servers.length} servers)');
    }
  }

  static Future<Result<List<RadioStation>>> getTopVotedStations({
    int limit = 50,
    int offset = 0,
  }) async {
    await updateServersList();

    try {
      final url = '$_baseUrl/json/stations/topvote/$limit/$offset';
      final response = await _makeRequest(url);

      if (response.isSuccess) {
        final List<dynamic> data = response.data;
        final stations = data
            .map((json) => RadioStation.fromRadioBrowserJson(json))
            .where((station) => station.isValidStream)
            .toList();
        return Result.success(stations);
      } else {
        return Result.failure(response.error!);
      }
    } catch (e) {
      return Result.failure(AppError.network('Failed to load top stations: $e'));
    }
  }

  static Future<Result<List<RadioStation>>> getTopClickStations({
    int limit = 50,
    int offset = 0,
  }) async {
    await updateServersList();

    try {
      final url = '$_baseUrl/json/stations/topclick/$limit/$offset';
      final response = await _makeRequest(url);

      if (response.isSuccess) {
        final List<dynamic> data = response.data;
        final stations = data
            .map((json) => RadioStation.fromRadioBrowserJson(json))
            .where((station) => station.isValidStream)
            .toList();
        return Result.success(stations);
      } else {
        return Result.failure(response.error!);
      }
    } catch (e) {
      return Result.failure(AppError.network('Failed to load popular stations: $e'));
    }
  }

  static Future<Result<List<RadioStation>>> searchStations({
    String? name,
    String? country,
    String? countryCode,
    String? language,
    String? tag,
    String? codec,
    int? minBitrate,
    int? maxBitrate,
    bool? hasGeoInfo,
    bool? isHttps,
    int limit = 30,
    int offset = 0,
  }) async {
    await updateServersList();

    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
      };

      if (name != null && name.isNotEmpty) queryParams['name'] = name;
      if (country != null && country.isNotEmpty) queryParams['country'] = country;
      if (countryCode != null && countryCode.isNotEmpty) queryParams['countrycode'] = countryCode;
      if (language != null && language.isNotEmpty) queryParams['language'] = language;
      if (tag != null && tag.isNotEmpty) queryParams['tag'] = tag;
      if (codec != null && codec.isNotEmpty) queryParams['codec'] = codec;
      if (minBitrate != null) queryParams['bitrateMin'] = minBitrate.toString();
      if (maxBitrate != null) queryParams['bitrateMax'] = maxBitrate.toString();
      if (hasGeoInfo == true) queryParams['has_geo_info'] = 'true';
      if (isHttps == true) queryParams['is_https'] = 'true';

      final uri = Uri.parse('$_baseUrl/json/stations/search').replace(
        queryParameters: queryParams,
      );

      final response = await _makeRequest(uri.toString());

      if (response.isSuccess) {
        final List<dynamic> data = response.data;
        final stations = data
            .map((json) => RadioStation.fromRadioBrowserJson(json))
            .where((station) => station.isValidStream)
            .toList();
        return Result.success(stations);
      } else {
        return Result.failure(response.error!);
      }
    } catch (e) {
      return Result.failure(AppError.network('Search failed: $e'));
    }
  }

  static Future<Result<List<RadioStation>>> getStationsByCountry(
      String countryCode, {
        int limit = 30,
        int offset = 0,
      }) async {
    await updateServersList();

    try {
      final url = '$_baseUrl/json/stations/bycountrycodeexact/$countryCode?limit=$limit&offset=$offset';
      final response = await _makeRequest(url);

      if (response.isSuccess) {
        final List<dynamic> data = response.data;
        final stations = data
            .map((json) => RadioStation.fromRadioBrowserJson(json))
            .where((station) => station.isValidStream)
            .toList();
        return Result.success(stations);
      } else {
        return Result.failure(response.error!);
      }
    } catch (e) {
      return Result.failure(AppError.network('Failed to load stations by country: $e'));
    }
  }

  static Future<Result<List<RadioStation>>> getStationsByTag(
      String tag, {
        int limit = 30,
        int offset = 0,
      }) async {
    await updateServersList();

    try {
      final url = '$_baseUrl/json/stations/bytagexact/$tag?limit=$limit&offset=$offset';
      final response = await _makeRequest(url);

      if (response.isSuccess) {
        final List<dynamic> data = response.data;
        final stations = data
            .map((json) => RadioStation.fromRadioBrowserJson(json))
            .where((station) => station.isValidStream)
            .toList();
        return Result.success(stations);
      } else {
        return Result.failure(response.error!);
      }
    } catch (e) {
      return Result.failure(AppError.network('Failed to load stations by tag: $e'));
    }
  }

  static Future<Result<List<RadioStation>>> getNewStations({
    int limit = 50,
    int offset = 0,
  }) async {
    await updateServersList();

    try {
      final url = '$_baseUrl/json/stations/lastchange/$limit/$offset';
      final response = await _makeRequest(url);

      if (response.isSuccess) {
        final List<dynamic> data = response.data;
        final stations = data
            .map((json) => RadioStation.fromRadioBrowserJson(json))
            .where((station) => station.isValidStream)
            .toList();
        return Result.success(stations);
      } else {
        return Result.failure(response.error!);
      }
    } catch (e) {
      return Result.failure(AppError.network('Failed to load new stations: $e'));
    }
  }

  static Future<Result<void>> incrementClickCount(String stationId) async {
    try {
      final url = '$_baseUrl/json/url/$stationId';
      await _makeRequest(url);
      return Result.success(null);
    } catch (e) {
      return Result.failure(AppError.network('Failed to increment click count: $e'));
    }
  }

  static Future<Result<List<Map<String, dynamic>>>> getCountries() async {
    await updateServersList();

    try {
      final url = '$_baseUrl/json/countries';
      final response = await _makeRequest(url);

      if (response.isSuccess) {
        final List<dynamic> data = response.data;
        return Result.success(List<Map<String, dynamic>>.from(data));
      } else {
        return Result.failure(response.error!);
      }
    } catch (e) {
      return Result.failure(AppError.network('Failed to load countries: $e'));
    }
  }

  static Future<Result<List<Map<String, dynamic>>>> getTags() async {
    await updateServersList();

    try {
      final url = '$_baseUrl/json/tags';
      final response = await _makeRequest(url);

      if (response.isSuccess) {
        final List<dynamic> data = response.data;
        return Result.success(List<Map<String, dynamic>>.from(data));
      } else {
        return Result.failure(response.error!);
      }
    } catch (e) {
      return Result.failure(AppError.network('Failed to load tags: $e'));
    }
  }

  static Future<Result<dynamic>> _makeRequest(String url) async {
    AppError? lastError;

    for (int i = 0; i < _servers.length; i++) {
      try {
        final currentServer = _servers[i];
        final Uri originalUri = Uri.parse(url);
        final Uri newUri = Uri.parse(currentServer).replace(
          path: originalUri.path,
          query: originalUri.query,
        );

        final response = await http.get(
          newUri,
          headers: {
            'User-Agent': _userAgent,
            'Accept': 'application/json',
          },
        ).timeout(_timeout);

        if (response.statusCode == 200) {
          _cachedServer = currentServer;
          final data = json.decode(response.body);
          return Result.success(data);
        } else {
          lastError = AppError.network(
            'HTTP ${response.statusCode}: ${response.reasonPhrase}',
          );
        }
      } catch (e) {
        lastError = AppError.network('Server $i error: $e');
        print('Server ${_servers[i]} failed: $e');
      }
    }

    return Result.failure(lastError ?? AppError.network('All servers failed'));
  }

  static Future<Result<bool>> validateStreamUrl(String url) async {
    try {
      final response = await http.head(
        Uri.parse(url),
        headers: {'User-Agent': _userAgent},
      ).timeout(Duration(seconds: 5));

      final isValid = response.statusCode == 200;
      return Result.success(isValid);
    } catch (e) {
      return Result.success(false);
    }
  }

  static Map<String, dynamic> getServerInfo() {
    return {
      'servers': _servers,
      'cachedServer': _cachedServer,
      'lastUpdate': _lastServerUpdate?.toIso8601String(),
      'nextUpdate': _lastServerUpdate?.add(_serverUpdateInterval).toIso8601String(),
    };
  }

  static Future<void> forceUpdateServers() async {
    _lastServerUpdate = null;
    await updateServersList();
  }
}

sealed class Result<T> {
  factory Result.success(T data) = Success<T>;
  factory Result.failure(AppError error) = Failure<T>;

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T? get data => isSuccess ? (this as Success<T>).data : null;
  AppError? get error => isFailure ? (this as Failure<T>).error : null;
}

class Success<T> implements Result<T> {
  final T data;
  Success(this.data);

  @override
  bool get isSuccess => true;

  @override
  bool get isFailure => false;

  @override
  AppError? get error => null;
}

class Failure<T> implements Result<T> {
  final AppError error;
  Failure(this.error);

  @override
  bool get isSuccess => false;

  @override
  bool get isFailure => true;

  @override
  T? get data => null;
}

class AppError {
  final String message;
  final ErrorType type;

  AppError(this.message, this.type);

  factory AppError.network(String message) => AppError(message, ErrorType.network);
  factory AppError.validation(String message) => AppError(message, ErrorType.validation);
  factory AppError.player(String message) => AppError(message, ErrorType.player);
  factory AppError.storage(String message) => AppError(message, ErrorType.storage);

  @override
  String toString() => message;
}

enum ErrorType {
  network,
  validation,
  player,
  storage,
}