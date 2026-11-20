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
  String? _currentStationName;

  final StreamController<PlayerState> _stateController =
      StreamController<PlayerState>.broadcast();
  final StreamController<String?> _currentStationController =
      StreamController<String?>.broadcast();

  Stream<PlayerState> get stateStream => _stateController.stream;
  Stream<String?> get currentStationStream => _currentStationController.stream;

  String? get currentStationId => _currentStationId;
  String? get currentStationName => _currentStationName;

  bool get isPlaying => _player.state == PlayerState.playing;

  Future<void> initialize() async {
    if (_stateSubscription != null || _closing != null) return;

    _stateSubscription = _player.onPlayerStateChanged.listen((
      PlayerState state,
    ) {
      print('Состояние плеера изменено: $state');
      _stateController.add(state);
      if ((state == PlayerState.stopped || state == PlayerState.completed) &&
          state == _player.state) {
        _setCurrentStation(null, null);
      }
    });

    _logSubscription = _player.onLog.listen((String message) {
      print('AudioPlayer Log: $message');
    });

    print('Audio Player Service инициализирован успешно');
  }

  Future<bool> playStation(
    String stationId,
    String stationName,
    String streamUrl,
  ) {
    final intent = ++_intent;
    return _enqueue(() async {
      if (!_isCurrent(intent)) return false;
      await _player.stop();
      _setCurrentStation(null, null);
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
      _setCurrentStation(stationId, stationName);
      return true;
    });
  }

  Future<void> stop() {
    final intent = ++_intent;
    return _enqueue(() async {
      if (!_isCurrent(intent)) return;
      await _player.stop();
      _setCurrentStation(null, null);
    });
  }

  bool _isCurrent(int intent) => _closing == null && _intent == intent;

  Future<T> _enqueue<T>(Future<T> Function() command) {
    final result = _commands.then((_) => command());
    _commands = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  void _setCurrentStation(String? id, String? name) {
    if (_currentStationId == id) return;
    _currentStationId = id;
    _currentStationName = name;
    _currentStationController.add(id);
  }

  Future<void> pause() async {
    try {
      await _player.pause();
      print('Воспроизведение приостановлено');
    } catch (e) {
      print('Ошибка приостановки воспроизведения: $e');
      rethrow;
    }
  }

  Future<void> resume() async {
    try {
      await _player.resume();
      print('Воспроизведение возобновлено');
    } catch (e) {
      print('Ошибка возобновления воспроизведения: $e');
      rethrow;
    }
  }

  Future<void> setVolume(double volume) async {
    try {
      await _player.setVolume(volume.clamp(0.0, 1.0));
      print('Громкость установлена: ${(volume * 100).round()}%');
    } catch (e) {
      print('Ошибка установки громкости: $e');
      rethrow;
    }
  }

  Future<void> dispose() => _closing ??= _dispose();

  Future<void> _dispose() async {
    await _commands;
    await _stateSubscription?.cancel();
    await _logSubscription?.cancel();
    try {
      await _player.dispose();
    } finally {
      await _stateController.close();
      await _currentStationController.close();
    }
  }
}
