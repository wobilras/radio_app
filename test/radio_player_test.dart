import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radio_app/data/radio_player.dart';

class FakeAudioPlayer extends Fake implements AudioPlayer {
  final states = StreamController<PlayerState>.broadcast();
  final logs = StreamController<String>.broadcast();
  bool disposed = false;
  int stateSubscriptions = 0;
  final played = <String>[];
  final started = Completer<void>();
  Completer<void>? playGate;
  PlayerState _state = PlayerState.stopped;

  @override
  PlayerState get state => _state;

  void emit(PlayerState state) {
    _state = state;
    states.add(state);
  }

  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {
    played.add((source as UrlSource).url);
    if (!started.isCompleted) started.complete();
    await playGate?.future;
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
    await states.close();
    await logs.close();
    disposed = true;
  }
}

void main() {
  test('each service owns its player and subscribes once', () async {
    for (var i = 0; i < 2; i++) {
      final player = FakeAudioPlayer();
      final service = AudioPlayerService(player: player);
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
      final service = AudioPlayerService(player: player);
      await service.initialize();
      final ids = <String?>[];
      service.currentStationStream.listen(ids.add);
      final play = service.playStation('a', 'https://example.test/a');
      await player.started.future;
      final stop = service.stop();
      player.playGate!.complete();
      await Future.wait([play, stop]);
      expect(player.state, PlayerState.stopped);
      expect(ids, isNot(contains('a')));
      expect(service.currentStationId, isNull);
      await service.dispose();
    },
  );

  test('Latest selection wins and completion clears the station', () async {
    final player = FakeAudioPlayer();
    final service = AudioPlayerService(player: player);
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
}
