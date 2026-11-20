import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

class AudioPlayerService {
  AudioPlayerService({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  StreamSubscription<PlayerState>? _stateSubscription;
  StreamSubscription<String>? _logSubscription;
  Future<void>? _closing;
  Future<void> _commands = Future.value();
  int _intent = 0;

  String? _currentStationId;

  final StreamController<String?> _currentStationController =
      StreamController<String?>.broadcast();

  Stream<String?> get currentStationStream => _currentStationController.stream;

  String? get currentStationId => _currentStationId;

  Future<void> initialize() async {
    if (_stateSubscription != null || _closing != null) return;

    _stateSubscription = _player.onPlayerStateChanged.listen((
      PlayerState state,
    ) {
      print('Состояние плеера изменено: $state');
      if ((state == PlayerState.stopped || state == PlayerState.completed) &&
          state == _player.state) {
        _setCurrentStation(null);
      }
    });

    _logSubscription = _player.onLog.listen((String message) {
      print('AudioPlayer Log: $message');
    });

    print('Audio Player Service инициализирован успешно');
  }

  Future<bool> playStation(String stationId, String streamUrl) {
    final intent = ++_intent;
    return _enqueue(() async {
      if (!_isCurrent(intent)) return false;
      await _player.stop();
      _setCurrentStation(null);
      if (!_isCurrent(intent)) return false;
      try {
        await _player.play(UrlSource(streamUrl));
      } catch (_) {
        if (!_isCurrent(intent)) return false;
        rethrow;
      }
      if (!_isCurrent(intent) || _player.state != PlayerState.playing) {
        return false;
      }
      _setCurrentStation(stationId);
      return true;
    });
  }

  Future<void> stop() {
    final intent = ++_intent;
    return _enqueue(() async {
      if (!_isCurrent(intent)) return;
      await _player.stop();
      _setCurrentStation(null);
    });
  }

  bool _isCurrent(int intent) => _closing == null && _intent == intent;

  Future<T> _enqueue<T>(Future<T> Function() command) {
    final result = _commands.then((_) => command());
    _commands = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  void _setCurrentStation(String? id) {
    if (_currentStationId == id) return;
    _currentStationId = id;
    _currentStationController.add(id);
  }

  Future<void> dispose() => _closing ??= _dispose();

  Future<void> _dispose() async {
    await _commands;
    await _stateSubscription?.cancel();
    await _logSubscription?.cancel();
    try {
      await _player.dispose();
    } finally {
      await _currentStationController.close();
    }
  }
}
