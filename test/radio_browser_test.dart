import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:radio_app/data/radio_browser.dart';

void main() {
  final mirrors = [
    Uri.https('first.example.test'),
    Uri.https('second.example.test'),
  ];

  test(
    'fails over on server failure and keeps the successful mirror',
    () async {
      final requests = <Uri>[];
      final browser = RadioBrowserService(
        mirrors: mirrors,
        client: MockClient((request) async {
          requests.add(request.url);
          return request.url.host == mirrors.first.host
              ? http.Response('', 503)
              : http.Response('[]', 200);
        }),
      );
      addTearDown(browser.dispose);
      await browser.searchStations(name: 'jazz & blues');
      await browser.getPopularStations();
      expect(requests.map((uri) => uri.host), [
        mirrors.first.host,
        mirrors.last.host,
        mirrors.last.host,
      ]);
      expect(requests.first.queryParameters['name'], 'jazz & blues');
    },
  );

  test(
    'does not retry an invalid request and bounds temporary failures',
    () async {
      var calls = 0;
      var status = 400;
      final browser = RadioBrowserService(
        mirrors: mirrors,
        client: MockClient((_) async {
          calls++;
          return http.Response('', status);
        }),
      );
      addTearDown(browser.dispose);
      await expectLater(
        browser.getPopularStations(),
        throwsA(isA<http.ClientException>()),
      );
      expect(calls, 1);
      status = 503;
      await expectLater(
        browser.getPopularStations(),
        throwsA(isA<http.ClientException>()),
      );
      expect(calls, 3);
    },
  );

  test('per-operation timeout advances past an unresponsive mirror', () async {
    var calls = 0;
    final browser = RadioBrowserService(
      mirrors: mirrors,
      attemptTimeout: const Duration(milliseconds: 10),
      client: MockClient((_) async {
        if (++calls == 1) return Completer<http.Response>().future;
        return http.Response('[]', 200);
      }),
    );
    addTearDown(browser.dispose);
    expect(await browser.getPopularStations(), isEmpty);
    expect(calls, 2);
  });
}
