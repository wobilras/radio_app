import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'models/radio_station.dart';

class RadioBrowserService {
  RadioBrowserService({
    http.Client? client,
    List<Uri>? mirrors,
    this.attemptTimeout = const Duration(seconds: 3),
  }) : _client = client ?? http.Client(),
       _mirrors = List.of(mirrors ?? _defaultMirrors);

  static final _defaultMirrors = [
    Uri.https('de1.api.radio-browser.info'),
    Uri.https('nl1.api.radio-browser.info'),
    Uri.https('at1.api.radio-browser.info'),
  ];

  final http.Client _client;
  final List<Uri> _mirrors;
  final Duration attemptTimeout;

  Future<http.Response> _request(
    List<String> path, {
    Map<String, String>? query,
    int maxAttempts = 3,
  }) async {
    Object? lastFailure;
    for (final mirror in _mirrors.take(maxAttempts).toList()) {
      final uri = mirror.replace(pathSegments: path, queryParameters: query);
      final http.Response response;
      try {
        response = await _client
            .get(
              uri,
              headers: {
                'Accept': 'application/json',
                if (!kIsWeb) 'User-Agent': 'RadioApp/1.0',
              },
            )
            .timeout(attemptTimeout);
      } on TimeoutException catch (error) {
        lastFailure = error;
        continue;
      } on http.ClientException catch (error) {
        lastFailure = error;
        continue;
      }
      final status = response.statusCode;
      if (status == 200) {
        _mirrors.remove(mirror);
        _mirrors.insert(0, mirror);
        return response;
      }
      final failure = http.ClientException(
        'Radio Browser returned HTTP $status',
      );
      if (status < 500 && status != 408 && status != 429) throw failure;
      lastFailure = failure;
    }
    throw http.ClientException(
      'Radio Browser mirrors unavailable: $lastFailure',
    );
  }

  Future<List<RadioStation>> _stations(
    List<String> path,
    Map<String, String> query,
  ) async {
    final response = await _request(path, query: query);
    final records = jsonDecode(utf8.decode(response.bodyBytes)) as List;
    return records.map((record) => RadioStation.fromJson(record)).toList();
  }

  Future<List<RadioStation>> getPopularStations({int limit = 50}) =>
      _stations(['json', 'stations', 'topvote'], {'limit': '$limit'});

  Future<List<RadioStation>> searchStations({
    String? name,
    String? country,
    String? tag,
    int limit = 50,
  }) => _stations(
    ['json', 'stations', 'search'],
    {
      'limit': '$limit',
      if (name != null && name.isNotEmpty) 'name': name,
      if (country != null && country.isNotEmpty) 'country': country,
      if (tag != null && tag.isNotEmpty) 'tag': tag,
    },
  );

  Future<List<RadioStation>> getStationsByCountry(
    String countryCode, {
    int limit = 50,
  }) => _stations(
    ['json', 'stations', 'bycountrycodeexact', countryCode],
    {'limit': '$limit'},
  );

  Future<void> registerStationClick(String stationUuid) async {
    try {
      await _request(['json', 'url', stationUuid], maxAttempts: 1);
    } on http.ClientException {
      // Playback succeeds independently of catalog analytics.
    }
  }

  Future<void> refreshServers() async {
    if (_mirrors.length > 1) _mirrors.add(_mirrors.removeAt(0));
  }

  void dispose() => _client.close();
}
