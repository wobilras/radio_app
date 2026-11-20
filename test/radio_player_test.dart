import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radio_app/data/radio_player.dart';

class FakeAudioPlayer extends Fake implements AudioPlayer {
  final states = StreamController<PlayerState>.broadcast();
  final logs = StreamController<String>.broadcast();
  final events = StreamController<AudioEvent>.broadcast();
  int resumes = 0;
  bool disposed = false;
  int stateSubscriptions = 0;
  final played = <String>[];
  final started = Completer<void>();
  Completer<void>? playGate;
  PlayerState _state = PlayerState.stopped;

  @override
  PlayerState get state => _state;

  @override
  Source? get source => played.isEmpty ? null : UrlSource(played.last);

  void emit(PlayerState state) {
    _state = state;
    states.add(state);
  }

  @override
  Future<void> setSource(Source source) async {
    played.add((source as UrlSource).url);
    if (!started.isCompleted) started.complete();
    await playGate?.future;
  }

  @override
  Stream<AudioEvent> get eventStream => events.stream;

  @override
  Future<void> resume() async {
    resumes++;
    emit(PlayerState.playing);
  }

  @override
  Future<void> stop() async => emit(PlayerState.stopped);

  @override
  Stream<PlayerState> get onPlayerStateChanged {
    stateSubscriptions++;
    return states.stream;
  }

  @override
  Stream<String> get onLog => logs.stream;

  @override
  Future<void> dispose() async {
    expect(states.hasListener, isFalse);
    expect(logs.hasListener, isFalse);
    expect(events.hasListener, isFalse);
    _state = PlayerState.stopped;
    await events.close();
    await states.close();
    await logs.close();
    disposed = true;
  }
}

void main() {
  test('each service owns its player and subscribes once', () async {
    for (var i = 0; i < 2; i++) {
      final player = FakeAudioPlayer();
      final service = AudioPlayerService(playerFactory: () => player);
      await service.initialize();
      await service.initialize();
      expect(player.stateSubscriptions, 1);
      await service.dispose();
      expect(player.disposed, isTrue);
    }
  });

  test(
    'Stop supersedes a pending play without publishing the station',
    () async {
      final player = FakeAudioPlayer()..playGate = Completer<void>();
      final service = AudioPlayerService(playerFactory: () => player);
      await service.initialize();
      final ids = <String?>[];
      service.currentStationStream.listen(ids.add);
      final play = service.playStation('a', 'https://example.test/a');
      await player.started.future;
      final stop = service.stop();
      player.playGate!.complete();
      await Future.wait([play, stop]);
      expect(player.state, PlayerState.stopped);
      expect(player.resumes, 0);
      expect(ids, isNot(contains('a')));
      expect(service.currentStationId, isNull);
      await service.dispose();
    },
  );

  test('Latest selection wins and completion clears the station', () async {
    final player = FakeAudioPlayer();
    final service = AudioPlayerService(playerFactory: () => player);
    await service.initialize();
    await Future.wait([
      service.playStation('a', 'https://example.test/a'),
      service.playStation('b', 'https://example.test/b'),
    ]);
    expect(player.played, ['https://example.test/b']);
    expect(service.currentStationId, 'b');
    player.emit(PlayerState.completed);
    await Future<void>.delayed(Duration.zero);
    expect(service.currentStationId, isNull);
    await service.dispose();
  });

  test('playback diagnostics do not forward plugin URLs', () async {
    const url = 'https://example.test/stream?token=fake-test-only';
    final printed = <String>[];
    final player = FakeAudioPlayer();
    await runZoned(
      () async {
        final service = AudioPlayerService(playerFactory: () => player);
        await service.initialize();
        await service.playStation('a', url);
        player.logs.add('Plugin source: $url');
        AudioLogger.error(AudioPlayerException(player));
        await Future<void>.delayed(Duration.zero);
        await service.dispose();
      },
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, text) => printed.add(text),
      ),
    );
    expect(printed.join(), isNot(contains('fake-test-only')));
  });

  test(
    'Only the active player can update state after switching stations',
    () async {
      final first = FakeAudioPlayer();
      final second = FakeAudioPlayer();
      final players = [first, second].iterator;
      final service = AudioPlayerService(
        playerFactory: () {
          players.moveNext();
          return players.current;
        },
      );
      expect(await service.playStation('a', 'https://example.test/a'), isTrue);
      expect(await service.playStation('b', 'https://example.test/b'), isTrue);
      expect(first.disposed, isTrue);
      expect(service.currentStationId, 'b');
      second.events.addError(StateError('native error'));
      await Future<void>.delayed(Duration.zero);
      expect(service.currentStationId, isNull);
      await service.dispose();
    },
  );
}
