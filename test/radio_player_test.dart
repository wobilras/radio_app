import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radio_app/data/radio_player.dart';

class FakeAudioPlayer extends Fake implements AudioPlayer {
  final states = StreamController<PlayerState>.broadcast();
  final logs = StreamController<String>.broadcast();
  bool disposed = false;

  @override
  Stream<PlayerState> get onPlayerStateChanged => states.stream;

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
      final received = <PlayerState>[];
      service.stateStream.listen(received.add);
      await service.initialize();
      await service.initialize();
      player.states.add(PlayerState.playing);
      await Future<void>.delayed(Duration.zero);
      expect(received, [PlayerState.playing]);
      await service.dispose();
      expect(player.disposed, isTrue);
    }
  });
}
