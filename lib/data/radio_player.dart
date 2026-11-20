import 'dart:async';
import 'dart:developer' as developer;

import 'package:audioplayers/audioplayers.dart';

class AudioPlayerService {
  AudioPlayerService({AudioPlayer Function()? playerFactory})
    : _createPlayer = playerFactory ?? AudioPlayer.new {
    // Plugin exceptions include the full stream URL.
    AudioLogger.logLevel = AudioLogLevel.none;
  }

  final AudioPlayer Function() _createPlayer;
  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _stateSubscription;
  StreamSubscription<AudioEvent>? _eventSubscription;
  bool _sourceAssigned = false;
  Future<void>? _closing;
  Future<void> _commands = Future.value();
  int _intent = 0;

  String? _currentStationId;
  final StreamController<String?> _currentStationController =
      StreamController<String?>.broadcast();

  Stream<String?> get currentStationStream => _currentStationController.stream;
  String? get currentStationId => _currentStationId;

  Future<void> initialize() async {
    if (_closing == null) _player ??= _openPlayer();
  }

  AudioPlayer _openPlayer() {
    final player = _createPlayer();
    _stateSubscription = player.onPlayerStateChanged.listen((state) {
      if (identical(_player, player) &&
          (state == PlayerState.stopped || state == PlayerState.completed)) {
        _setCurrentStation(null);
      }
    });
    _eventSubscription = player.eventStream.listen(
      (_) {},
      onError: (Object error) {
        if (!identical(_player, player)) return;
        developer.log(
          'Audio stream failed',
          name: 'radio.playback',
          error: error.runtimeType,
        );
        _setCurrentStation(null);
      },
    );
    return player;
  }

  Future<bool> playStation(String stationId, String streamUrl) {
    final intent = ++_intent;
    return _enqueue(() async {
      if (!_isCurrent(intent)) return false;
      if (_sourceAssigned) {
        _setCurrentStation(null);
        await _releasePlayer();
      }
      if (!_isCurrent(intent)) return false;

      final player = _player ??= _openPlayer();
      _sourceAssigned = true;
      try {
        await player.setSource(UrlSource(streamUrl));
        if (!_isCurrent(intent)) return false;
        await player.resume();
      } catch (_) {
        if (!_isCurrent(intent)) return false;
        rethrow;
      }
      if (!_isCurrent(intent) || player.state != PlayerState.playing) {
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
      await _releasePlayer();
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

  Future<void> _releasePlayer() async {
    final player = _player;
    _player = null;
    _sourceAssigned = false;
    await _stateSubscription?.cancel();
    await _eventSubscription?.cancel();
    _stateSubscription = null;
    _eventSubscription = null;
    await player?.dispose();
  }

  Future<void> dispose() => _closing ??= _dispose();

  Future<void> _dispose() async {
    await _commands;
    try {
      await _releasePlayer();
    } finally {
      await _currentStationController.close();
    }
  }
}
