import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:radio_app/data/models/radio_station.dart';
import 'package:radio_app/data/radio_browser.dart';
import 'package:radio_app/data/radio_player.dart';
import 'package:radio_app/data/repositories/radio_repository.dart';

class PendingClickBrowser extends Fake implements RadioBrowserService {
  final completion = Completer<void>();
  final clicked = <String>[];

  @override
  Future<void> registerStationClick(String id) {
    clicked.add(id);
    return completion.future;
  }
}

class RecordingAudio extends Fake implements AudioPlayerService {
  final played = <String>[];

  @override
  Future<bool> playStation(String id, String name, String url) async {
    played.add(id);
    return true;
  }
}

void main() {
  test(
    'playback does not wait for click registration and skips fallback IDs',
    () async {
      final browser = PendingClickBrowser();
      final audio = RecordingAudio();
      final repository = RadioRepositoryImpl(
        browserService: browser,
        audioService: audio,
      );

      final station = RadioStation(
        stationuuid: 'catalog',
        name: 'Radio',
        url: 'https://example.test/radio',
      );
      await repository.playStation(station);
      expect(audio.played, ['catalog']);
      expect(browser.clicked, ['catalog']);

      await repository.playStation(station.copyWith(stationuuid: 'fallback-1'));
      expect(audio.played, ['catalog', 'fallback-1']);
      expect(browser.clicked, ['catalog']);
      browser.completion.complete();
    },
    timeout: const Timeout(Duration(seconds: 3)),
  );
}
