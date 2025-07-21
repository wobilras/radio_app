import 'dart:convert';
import 'dart:math';

import 'models/radio_station.dart';
import 'package:http/http.dart' as http;

class RadioBrowserService {
  static const List<String> _servers = [
    //'https://de1.api.radio-browser.info',
    'https://de2.api.radio-browser.info',
  ];

  static const String _userAgent = 'FlutterRadioApp/1.0.0';
  static const Duration _timeout = Duration(seconds: 10);

  static String? _cachedServer;

  static String get _baseUrl {
    return _cachedServer ?? _servers[Random().nextInt(_servers.length)];
  }

  // Получить популярные станции по голосам
  static Future<Result<List<RadioStation>>> getTopVotedStations({
    int limit = 50,
    int offset = 0,
  }) async {
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

  // Получить популярные станции по кликам
  static Future<Result<List<RadioStation>>> getTopClickStations({
    int limit = 50,
    int offset = 0,
  }) async {
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

  // Расширенный поиск станций
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

  // Получить станции по стране
  static Future<Result<List<RadioStation>>> getStationsByCountry(
      String countryCode, {
        int limit = 30,
        int offset = 0,
      }) async {
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

  // Получить станции по тегу/жанру
  static Future<Result<List<RadioStation>>> getStationsByTag(
      String tag, {
        int limit = 30,
        int offset = 0,
      }) async {
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

  // Получить новые станции
  static Future<Result<List<RadioStation>>> getNewStations({
    int limit = 50,
    int offset = 0,
  }) async {
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

  // Увеличить счетчик кликов для станции
  static Future<Result<void>> incrementClickCount(String stationId) async {
    try {
      final url = '$_baseUrl/json/url/$stationId';
      await _makeRequest(url);
      return Result.success(null);
    } catch (e) {
      return Result.failure(AppError.network('Failed to increment click count: $e'));
    }
  }

  // Получить все доступные страны
  static Future<Result<List<Map<String, dynamic>>>> getCountries() async {
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

  // Получить все доступные теги/жанры
  static Future<Result<List<Map<String, dynamic>>>> getTags() async {
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

  // Базовый метод для HTTP запросов
  static Future<Result<dynamic>> _makeRequest(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': _userAgent,
          'Accept': 'application/json',
        },
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        _cachedServer = _extractServerFromUrl(url);
        final data = json.decode(response.body);
        return Result.success(data);
      } else {
        return Result.failure(AppError.network(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        ));
      }
    } catch (e) {
      return Result.failure(AppError.network('Network error: $e'));
    }
  }

  static String _extractServerFromUrl(String url) {
    final uri = Uri.parse(url);
    return '${uri.scheme}://${uri.host}';
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
}

// Класс для обработки результатов
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